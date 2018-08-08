
platform = node['platform']

if platform == "centos"
  %w(httpd mariadb mariadb-server).each do |p|
    package p do
      action :install
    end
  end
elsif platform == "ubuntu"
  %w(mysql-server mysql-client).each do |p|
    package p do
      action :install
    end
  end
end
  
if platform == "centos"
  execute 'Epel Release' do
    not_if "rpm -qa | grep -i 'epel'"
    command 'rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm'
  end

  execute 'Webtatic Release' do
    not_if "rpm -qa | grep -i 'webtatic'"
    command 'rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm'
  end
end

if platform == "centos"
  execute 'makecache' do
    command 'yum makecache'
  end
elsif platform == "ubuntu"
  execute 'update' do
    command 'apt-get update -y'
  end
end

if platform == "centos"
  %w(mod_php71w.x86_64 php71w-cli.x86_64 php71w-common.x86_64 php71w-gd.x86_64 php71w-mbstring.x86_64 php71w-mcrypt.x86_64 php71w-mysqlnd.x86_64 php71w-xml.x86_64).each do |p|
    package p do
      action :install
    end
  end
elsif platform == "ubuntu"
	%w(apache2 php7.2 php7.2-cgi php7.2-cli php7.2-mbstring php7.2-mysql libapache2-mod-php7.2 php7.2-common php-pear php7.2-mbstring php-gettext).each do |p|
    package p do
      action :install
    end
  end
end

if platform == "ubuntu"
  search(:database, 'id:database').each do |db|
    template '/etc/apache2/sites-enabled/000-default.conf' do
      source '000-default.conf.erb'
      mode "0755"
      variables ({
        :hostname  => node['hostname'],
        :fqdn      => node['fqdn'],
        :email     => db['email'],
      })
    end
  end
end

if platform == "ubuntu"
  cookbook_file '/etc/apache2/mods-enabled/dir.conf' do
    source "dir.conf"
    action :create
  end
end

if platform == "ubuntu"
  cookbook_file '/etc/php/7.2/apache2/php.ini' do
    source 'php.ini'
    mode '0644'
    action :create
  end
end

if platform == "ubuntu"
  execute 'Enable PHP for Apache2' do
    command 'a2enconf php7.2-cgi'
  end
end

if platform == "centos"
  service 'httpd' do
    action [:start, :enable]
  end
elsif platform == "ubuntu"
  service 'apache2' do
    action [:start, :enable]
  end
end

remote_file '/tmp/phpmyadmin.tgz' do
  source 'https://files.phpmyadmin.net/phpMyAdmin/4.8.2/phpMyAdmin-4.8.2-english.tar.gz'
end

bash "Extract phpMyAdmin" do
  code <<-EOT
  tar -zxvf /tmp/phpmyadmin.tgz -C /var/www/html/
  mv /var/www/html/phpMyAdmin-*/{*,.*} /var/www/html/
  rm -rf /var/www/html/phpMyAdmin-*
  EOT
end

search(:fedora, 'id:phpmyadmin').each do |php|
  template '/var/www/html/config.inc.php' do
    source 'config.inc.php.erb'
    mode "0755"
    variables ({
      :hostname  => node['hostname'],
      :ipaddress => node['ipaddress'],
      :pmauser   => php['pmauser'],
      :pmapass   => php['pmapass'],
      :user      => php['user'],
      :password  => php['password'],
    })
  end
end

search(:database, 'id:database').each do |pma|
  template '/tmp/pma.sql' do
    source 'pma.sql.erb'
    mode "0755"
    variables ({
      :pmauser   => pma['pmauser'],
      :pmapass   => pma['pmapass'],
      :pmaschema => pma['pmaschema'],
      :fqdn      => node['fqdn'],
    })
  end
end

cookbook_file '/tmp/create_tables.sql' do
  source 'create_tables.sql'
end

if platform == "centos "
  package "firewalld" do
    action :remove
  end
end

if platform == "centos"
  execute "Open up MariaDB" do
    command 'perl -pi -e "s/#bind-address=0.0.0.0/bind-address=0.0.0.0/g" /etc/my.cnf.d/mariadb-server.cnf'
  end
end

if platform == "centos"
  service "mariadb" do
    action [:start,:enable]
  end
elsif platform == "ubuntu"
  service 'mysql' do
    action [:start, :enable]
  end
end

execute "configure phpmyadmin tables" do
  command 'mysql -u root < /tmp/create_tables.sql | tee -a /tmp/create_table'
  not_if {File.exists?("/tmp/create_table")}
end

execute "create database setup users" do
  command 'mysql -u root < /tmp/pma.sql | tee -a /tmp/pma'
  not_if {File.exists?("/tmp/pma")}
end

if platform == "centos"
  execute "allow httpd and mysql connect" do
      command 'setsebool -P httpd_can_network_connect_db 1 && setsebool -P allow_user_mysql_connect 1'
  end
end

if platform == "ubuntu"
  service 'apache2' do
    action :reload
  end
end
