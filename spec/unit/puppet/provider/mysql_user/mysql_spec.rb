require 'spec_helper'

provider_class = Puppet::Type.type(:mysql_user).provider(:mysql)

describe Puppet::Type.type(:mysql_user).provider(:mysql) do
  let(:root_home) { '/root' }
  let(:defaults_file) { '--defaults-file=/root/.my.cnf' }
  let(:newhash) { '*6C8989366EAF75BB670AD8EA7A7FC1176A95CEF5' }

  let(:raw_users) do
    <<-SQL_OUTPUT
root@127.0.0.1
root@::1
@localhost
debian-sys-maint@localhost
root@localhost
usvn_user@localhost
@vagrant-ubuntu-raring-64
    SQL_OUTPUT
  end

  let(:parsed_users) { %w(root@127.0.0.1 root@::1 debian-sys-maint@localhost root@localhost usvn_user@localhost) }

  let(:resource) { Puppet::Type.type(:mysql_user).new(
      { :ensure               => :present,
        :password_hash        => '*6C8989366EAF75BB670AD8EA7A7FC1176A95CEF4',
        :name                 => 'joe@localhost',
        :max_user_connections => '10',
        :provider             => described_class.name
      }
  )}
  let(:provider) { resource.provider }

  before :each do
    # Set up the stubs for an instances call.
    Puppet::Util.stubs(:which).with('mysql').returns('/usr/bin/mysql')
    provider.class.stubs(:defaults_file).returns('--defaults-file=/root/.my.cnf')
    provider.class.stubs(:mysql).with([defaults_file, '-NBe', "SELECT CONCAT(User, '@',Host) AS User FROM mysql.user"]).returns('joe@localhost')
    provider.class.stubs(:mysql).with([defaults_file, '-NBe', "SELECT MAX_USER_CONNECTIONS, MAX_CONNECTIONS, MAX_QUESTIONS, MAX_UPDATES, PASSWORD FROM mysql.user WHERE CONCAT(user, '@', host) = 'joe@localhost'"]).returns('10 0 0 0 *6C8989366EAF75BB670AD8EA7A7FC1176A95CEF4')
  end

  let(:instance) { provider.class.instances.first }

  describe 'self.instances' do
    it 'returns an array of users' do
      described_class.stubs(:mysql).with([defaults_file, '-NBe', "SELECT CONCAT(User, '@',Host) AS User FROM mysql.user"]).returns(raw_users)
      parsed_users.each do |user|
        described_class.stubs(:mysql).with([defaults_file, '-NBe', "SELECT MAX_USER_CONNECTIONS, MAX_CONNECTIONS, MAX_QUESTIONS, MAX_UPDATES, PASSWORD FROM mysql.user WHERE CONCAT(user, '@', host) = '#{user}'"]).returns('10 0 0 0 ')
      end

      usernames = described_class.instances.collect {|x| x.name }
      parsed_users.should match_array(usernames)
    end
  end

  describe 'create' do
    it 'makes a user' do
      provider.expects(:mysql).with([defaults_file, '-e', "GRANT USAGE ON *.* TO 'joe'@'localhost' IDENTIFIED BY PASSWORD '*6C8989366EAF75BB670AD8EA7A7FC1176A95CEF4' WITH MAX_USER_CONNECTIONS 10 MAX_CONNECTIONS_PER_HOUR 0 MAX_QUERIES_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0"])
      provider.expects(:exists?).returns(true)
      provider.create.should be_true
    end
  end

  describe 'destroy' do
    it 'removes a user if present' do
      provider.expects(:mysql).with([defaults_file, '-e', "DROP USER 'joe'@'localhost'"])
      provider.expects(:exists?).returns(false)
      provider.destroy.should be_true
    end
  end

  describe 'password_hash' do
    it 'returns a hash' do
      instance.password_hash.should == '*6C8989366EAF75BB670AD8EA7A7FC1176A95CEF4'
    end
  end

  describe 'password_hash=' do
    it 'changes the hash' do
      provider.expects(:mysql).with([defaults_file, '-e', "SET PASSWORD FOR 'joe'@'localhost' = '*6C8989366EAF75BB670AD8EA7A7FC1176A95CEF5'"]).returns('0')

      provider.expects(:password_hash).returns('*6C8989366EAF75BB670AD8EA7A7FC1176A95CEF5')
      provider.password_hash=('*6C8989366EAF75BB670AD8EA7A7FC1176A95CEF5')
    end
  end

  describe 'max_user_connections' do
    it 'returns max user connections' do
      instance.max_user_connections.should == '10'
    end
  end

  describe 'max_user_connections=' do
    it 'changes max user connections' do
      provider.expects(:mysql).with([defaults_file, '-e', "GRANT USAGE ON *.* to 'joe'@'localhost' WITH MAX_USER_CONNECTIONS 42"]).returns('0')
      provider.expects(:max_user_connections).returns('42')
      provider.max_user_connections=('42')
    end
  end

  describe 'exists?' do
    it 'checks if user exists' do
      provider.exists?.should be_true
    end
  end

  describe 'flush' do
    it 'removes cached privileges' do
      provider.expects(:mysql).with([defaults_file, '-NBe', 'FLUSH PRIVILEGES'])
      provider.flush
    end
  end

  describe 'self.defaults_file' do
    it 'sets --defaults-file' do
      File.stubs(:file?).with('#{root_home}/.my.cnf').returns(true)
      provider.defaults_file.should == '--defaults-file=/root/.my.cnf'
    end
  end

end
