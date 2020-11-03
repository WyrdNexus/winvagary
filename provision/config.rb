require "./provision/dotenv"

class Config
  @@configfile = "#{File.expand_path('.', Dir.pwd)}/config.yml"

  def self.get_key(name, hash, key)
    if not hash.has_key?(key)
      puts "Config value not found in #{name}: #{key}"
    end

    hash[key]
  end

  def initialize(vagrant)
    if not File.exists? @@configfile
      puts "Configuration file not found at #{@@configfile}"
      exit 1
    end

    # collect config details from config.yml and project .env
    @provisionOverride = false
    @localconfig = self.read_config()                  # config file here: ./config.yml
    @projects_dir = @localconfig["projects_dir"]       # Root of all projects: /dev/Projects/Downstream - ex: /dev/Projects/Downstream/[hpe, hitachi, google, etc]
    @project = @localconfig["project"]                 # projectname and boss-host: hpe, hitachi, etc. 
    @envconfig = self.read_env()                       # Load vars from project .env file

    @nginxFile = "nginx_" + @envconfig["app_name"] + "_dev.conf"

    # main exec
    self.init(vagrant)
  end

  def read_env()
    @envFile = "#{@projects_dir}/#{@project}/.env"
    if not File.exists? @envFile
      puts "Project .env file not found at #{@envFile}"
      exit 1
    end

    required = [
      "app_name",
      "app_deploy_dir",
      "app_server_name",
      "app_ip",
      "db_root_password",
      "db_database",
      "db_username",
      "db_password",
    ]

    Dotenv::load(@envFile, required)
  end

  def read_config()
    localconfig = YAML::load(File.read(@@configfile))
    required = [
      "project",
      "projects_dir"
    ]

    missing_config = required - localconfig.keys
    if missing_config.count > 0
      puts "Config file missing keys: "
      missing_config.each do |p|
        puts "  #{p}"
      end
      exit 1
    end

    localconfig
  end

  def local(key)
    self.class.get_key('localconfig', @localconfig, key)
  end

  def env(key)
    self.class.get_key('envconfig', @envconfig, key)
  end

  def doProvision()
    @provisionOverride = true
  end

  def isProvisioning()
    @provisionOverride || ARGV.include?("up") || (ARGV.include?("reload") && ARGV.include?("--provision"))
  end

  def path(target)
    case target
      when "boss"
        @boss_dir
      when "app"
        self.env('app_deploy_dir')
      when "project"
        "#{@projects_dir}/#{@project}"
      else
        puts "Invalid Config path target: #{target}"
      end
  end

  def app_path()
    self.path('app')
  end

  def app_server_name()
    self.env('app_server_name')
  end

  def app_ip()
    self.env('app_ip')
  end

  def db_root_password()
    pw=self.env("db_root_password")
    defined?(pw) ? pw : "d0wnstream"
  end

  def init(vagrant)
    self.showDetails()

    self.os(vagrant)
      
    if self.isProvisioning()
      self.provision(vagrant.vm)
      self.mount(vagrant.vm)
      self.mysql(vagrant.vm)
      self.nginx(vagrant.vm)
      self.composer(vagrant.vm)
      self.laravel(vagrant.vm)
    end
  end

  def showDetails()
    puts "Project        #{self.local('project')}"
    puts "Environment    #{self.local('app_env')}"
    puts "ServerName     #{self.app_server_name()}"
    puts "IP             #{self.app_ip()}"
    puts "App Path       #{self.app_path()}"
  end

  def os(vagrant)
    # OS CONFIG
    #vagrant.vm.box = "ubuntu/bionic64" # https://github.com/hashicorp/vagrant/issues/10578#issuecomment-459081990
    vagrant.vm.box = "bento/ubuntu-18.04"
    vagrant.vm.hostname = self.app_server_name()

    vagrant.vm.network :private_network, ip: self.app_ip()
    vagrant.ssh.forward_agent = true

    vagrant.vm.provider 'virtualbox' do |vb|
      vb.customize ["setextradata", :id, "VBoxInternal2/SharedFoldersEnableSymlinksCreate/vagrant", "1"]
      vb.memory = '2048'
      #vb.gui = true
    end
  end

  def mount(vm)
    local_dir = File.expand_path self.path('project')
    deploy_dir = self.path('app')

    puts "Mounting Shared Drive: #{local_dir} TO #{deploy_dir}"

    opts = {
      owner: "vagrant",
      group: "www-data",
      mount_options: %w"dmode=775 fmode=775"
    }

    vm.synced_folder local_dir, deploy_dir, opts
  end

  def provision(vm)
    vm.provision(:shell, inline: "apt -y update > /dev/null && apt -y install dos2unix")

    vm.provision(:shell, inline: "echo \"   ----\n   Provisioning: Copy Files to VM\n   ----\"")
    self.local('files').each do |file|
      vm.provision(:file, source: file['from'], destination: file['to'])
      dest = file['to'].sub('~','/home/vagrant')
      vm.provision(:shell, inline: "dos2unix #{dest} &> /dev/null")
    end

    vm.provision(:shell, inline:  "echo \"   ----\n   Provisioning: Applying Shell Teaks\n   ----\"")
    self.local('provision').each do |cmd|
      vm.provision(:shell, inline: cmd)
    end
  end

  def mysql(vm)
    dbname= self.env("db_database")
    user=   "'#{self.env("db_username")}'@'localhost'"
    pass=   self.env("db_password")

    mysqlInstall = <<~MYSQL
      #!/bin/bash
      debconf-set-selections <<< "mysql-server mysql-server/root_password password #{self.db_root_password()}"
      debconf-set-selections <<< "mysql-server mysql-server/root_password_again password #{self.db_root_password()}"
      apt-get -y -q install mysql-server mysql-client
    MYSQL

    mysqlCreateDb = <<~MYSQL
      CREATE DATABASE IF NOT EXISTS #{dbname};
      CREATE USER IF NOT EXISTS #{user} IDENTIFIED BY '#{pass}';
      GRANT ALL PRIVILEGES ON #{dbname}.* TO #{user};
      FLUSH PRIVILEGES;
    MYSQL

    vm.provision :shell, inline:  "echo \"   ----\n   Install MySql\n   ----\""
    vm.provision :shell, inline:  mysqlInstall
    vm.provision :shell, inline:  "mysql --user=root --password=#{self.db_root_password()} -e \"#{mysqlCreateDb}\""
  end

  def nginx(vm)
    vm.provision :shell, inline:  "echo \"   ----\n   Prepare Nginx\n   ----\""
    
    tempDest = "/tmp/#{@nginxFile}"
    confDest = "/etc/nginx/conf.d/#{@nginxFile}"

    vm.provision :file, source:   "provision/nginx_dev.conf", destination: tempDest

    {
      "app_deploy_dir" => self.app_path(),
      "app_server_name" => self.app_server_name()
    }.each do | find, replace |
      vm.provision :shell, inline: "sed -i 's|{{\\s?#{find}\\s?}}|#{replace}|g' #{tempDest}"
    end

    vm.provision :shell, inline: "mv #{tempDest} #{confDest}"
    vm.provision :shell, path:    "provision/nginx_prep.sh"
  end

  def composer(vm)
    vm.provision :shell, inline:  "echo \"   ----\n   Composer\n   ----\""
    vm.provision :shell, keep_color: true, inline:  "echo \"           \e[32m composer install manual for now\e[0m\n                 see: https://github.com/hashicorp/vagrant/issues/8615"
    vm.provision "shell",  inline: "echo           vagrant ssh; cd #{self.app_path()}; composer install"

    # https://github.com/hashicorp/vagrant/issues/8615
    # vm.provision :shell, inline:  "git config --global github.accesstoken '#{`git config github.accesstoken`.strip!}'"
    # vm.provision :shell, path:    "provision/composer_prep.sh"
    # vm.provision :shell, inline:  "composer install -d #{self.app_path()}", privileged: false
  end

  def laravel(vm)
    vm.provision :shell, inline:  "echo \"   ----\n   Laravel\n   ----\""

    vm.provision "shell",  inline: "echo           \e[32m Laravel install requires composer\e[0m\n"

    hint = <<~ECHO
      php artisan key:generate \n
      php artisan module:migrate \n
      php artisan module:seed \n
      sudo npm install -g n
      sudo n latest
      sudo npm install -g npm
      npm install\n
      npm run build \n
    ECHO

    vm.provision :shell, inline: "echo \n\"#{hint}\""

    vm.provision :shell, inline:  "ln -s #{self.app_path()} ~/current", privileged: false
    # vm.provision :shell, path:    "provision/laravel_prep.sh", privileged: false
  end
end