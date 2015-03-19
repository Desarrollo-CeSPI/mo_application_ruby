include MoApplication::Logrotate
include MoApplication::SetupSSH
include MoApplication::Nginx

action :install do

  directory new_resource.path do
    owner new_resource.user
    group new_resource.group
    recursive true
  end

  mo_application_user new_resource.user do
    group new_resource.group
    ssh_keys new_resource.ssh_keys
  end

  directory www_log_dir do
    owner www_user
    group new_resource.group
    mode 0750
    recursive true
  end

  setup_upstart

  sudo_reload :install

  setup_ssh new_resource.user, new_resource.group, new_resource.ssh_private_key

  setup_var_run_dirs

  setup_ruby

  if new_resource.deploy

    services_create

    mo_application_deploy new_resource.name do
      user                        new_resource.user
      group                       new_resource.group
      path                        ::File.join(new_resource.path,new_resource.relative_path)
      repo                        new_resource.repo
      revision                    new_resource.revision
      migrate                     new_resource.migrate
      migration_command           new_resource.migration_command
      shared_dirs                 new_resource.shared_dirs
      shared_files                new_resource.shared_files
      create_dirs_before_symlink  new_resource.create_dirs_before_symlink
      force_deploy                new_resource.force_deploy
      ssh_wrapper                 new_resource.ssh_wrapper
      environment                 new_resource.environment
      restart_command             "sudo service #{upstart_main_service} restart"
      before_migrate              new_resource.before_migrate
      before_restart              new_resource.before_restart
      before_deploy(&new_resource.callback_before_deploy) if new_resource.callback_before_deploy
    end


  end

  directory ::File.join(new_resource.path,new_resource.relative_path) do
    owner new_resource.user
    group new_resource.group
    mode 0750
  end

  link ::File.join('/home',new_resource.user,'application') do
    to ::File.join(new_resource.path,new_resource.relative_path)
  end

  link ::File.join('/home',new_resource.user,'log') do
    to ::File.join(new_resource.path,'log')
  end


  nginx_create_configuration

  logrotate


end

action :remove do
  sudo_reload :remove

  nginx_create_configuration :delete

  remove_services

  directory new_resource.path do
    recursive true
    action :delete
  end

  mo_application_user new_resource.user do
    group new_resource.group
    action :remove
  end

  logrotate false

  sudo_reload :remove

end

def setup_ruby
  if node['mo_application_ruby']['rbenv']['enabled']
    rbenv_ruby new_resource.ruby_version
    rbenv_gem "bundler" do
      ruby_version new_resource.ruby_version
    end
  end
end

def services_remove
  service upstart_main_service do
    action :stop
  end

  directory upstart_base_dir do
    action :delete
  end
end

def services_create

  file ::File.join(upstart_base_dir, "#{main_service}.conf") do
    owner new_resource.user
    content <<-FILE
start on runlevel [2345]
stop on runlevel [!2345]
    FILE
  end

  new_resource.services.each do |service, command|
    template ::File.join(upstart_base_dir,"#{service}.conf") do
      source "upstart-template.conf.erb"
      owner new_resource.user
      cookbook 'mo_application_ruby'
      variables(
        :env => new_resource.environment.merge({"PATH" => ([rbenv_shims_path, rbenv_bin_path] + system_path).uniq.join(":")}),
        :depends => upstart_main_service,
        :setuid => new_resource.user,
        :chdir => ::File.join(new_resource.path,new_resource.relative_path,'current'),
        :exec => command,
        :log => application_log(service),
        :error_log => application_error_log(service))
    end
  end

end

def application_log(name)
  ::File.join(new_resource.path, new_resource.relative_path, 'shared', new_resource.log_dir,"#{name}.log")
end

def application_error_log(name)
  ::File.join(new_resource.path, new_resource.relative_path, 'shared', new_resource.log_dir,"#{name}-error.log")
end

def system_path
  shell_out!("echo $PATH").stdout.chomp.split(':')
end

def logrotate_service_logs
  Array(self.www_logs)
end

def logrotate_application_logs
  ::File.join(new_resource.path, 'shared', new_resource.log_dir, '*.log')
end

def logrotate_postrotate
  <<-CMD
    [ ! -f #{nginx_pid} ] || kill -USR1 `cat #{nginx_pid}`
  CMD
end

def nginx_upstream(name)
  "#{new_resource.name}_#{name}_ruby_app"
end

def setup_var_run_dirs
  directory nginx_document_root(::File.join(new_resource.relative_path, 'shared', var_run_directory)) do
    recursive true
    owner new_resource.user
  end
end

def ruby_application_socket(name)
  nginx_document_root(::File.join(new_resource.relative_path, 'shared', var_run_directory, "#{name}.sock"))
end

def ruby_application_pidfile(name)
  nginx_document_root(::File.join(new_resource.relative_path, 'shared', var_run_directory, "#{name}.pid"))
end

def var_run_directory
  ::File.join('var','run')
end

def nginx_options_for(action, name, options)
  {
    "action"    => action,
    "upstream" => {
      nginx_upstream(name) => {
        "server"  => "unix:#{ruby_application_socket(name)}"
      }
    },
    "listen"    => "80",
    # path for static files
    "root"      => nginx_document_root(::File.join(new_resource.relative_path, 'current', options['relative_document_root'] || 'public')),
    "locations" => {
      "@#{nginx_upstream(name)}" => {
        "proxy_set_header"  => ["X-Forwarded-For $proxy_add_x_forwarded_for",
                                     "Host $http_host"],
        "proxy_redirect" => "off",
        "proxy_pass" => "http://#{nginx_upstream(name)}",
      },
      %q(/) => {
        "try_files" => "$uri @#{nginx_upstream(name)}",
      }.merge(options['allow'] ? {'allow' => options['allow'], 'deny' => 'all'}: {}),
      # Now this supposedly should work as it gets the filenames with querystrings that Rails provides.
      # BUT there's a chance it could break the ajax calls.
      %q(~* \.(ico|css|gif|jpe?g|png|js)(\?[0-9]+)?$) => {
        "try_files"     => "$uri @#{nginx_upstream(name)}",
        "access_log"    => "off",
        "log_not_found" => "off",
        "expires"       => "max",
        "break"         => nil,
      }
    },
    "options" => {
      "access_log"  => ::File.join(www_log_dir, "#{name}-access.log"),
      "error_log"   => ::File.join(www_log_dir, "#{name}-error.log"),

      # ~2 seconds is often enough for most folks to parse HTML/CSS and
      # retrieve needed images/icons/frames, connections are cheap in
      # nginx so increasing this is generally safe...
      "keepalive_timeout" => "10",
      "client_max_body_size" => "50M",
      # this rewrites all the requests to the maintenance.html
      # page if it exists in the doc root. This is for capistrano's
      # disable web task
      "if" => {
        "-f $document_root/mantenimiento.html" => {
          "rewrite" =>  "^(.*)$  /mantenimiento.html last",
          "break" => nil,
        }
     },
    },
  }
end

def upstart_base_dir
  "/etc/init/#{new_resource.user}"
end

def setup_upstart
  directory upstart_base_dir do
    owner new_resource.user
    group new_resource.group
  end
end

def main_service
  "application"
end

def upstart_main_service
  "#{new_resource.user}/#{main_service}"
end

def sudo_reload(to_do)
  service_name = upstart_main_service

  cmd_list = new_resource.services.keys.map do |service|
    "#{service_name}-#{service}"
  end

  cmd_list = (cmd_list << service_name).map do |service|
    ["/usr/sbin/service #{service} *", "/sbin/start #{service}", "/sbin/stop #{service}", "/sbin/restart #{service}"]
  end.flatten

  sudo "ruby_app_#{new_resource.user}" do
    user      new_resource.user
    runas     'root'
    commands  cmd_list
    nopasswd  true
    action to_do
  end
end
