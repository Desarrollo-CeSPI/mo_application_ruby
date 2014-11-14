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
    group www_group
  end

  setup_upstart

  setup_ssh

  if new_resource.deploy

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
      before_deploy(&new_resource.callback_before_deploy) if new_resource.callback_before_deploy
    end

  else

    directory new_resource.path do
      owner new_resource.user
      group new_resource.group
    end

  end

  link ::File.join('/home',new_resource.user,'application') do
    to ::File.join(new_resource.path)
  end

  nginx_create_configuration

  logrotate


end

action :remove do
  sudo_reload :remove

  nginx_create_configuration :delete

  directory new_resource.path do
    recursive true
    action :remove
  end

  mo_application_user new_resource.user do
    group new_resource.group
    action :remove
  end

  logrotate false
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


def nginx_options_for(action, name, options)
  {
    "action"    => action,
    "listen"    => "80",
    "root"      => nginx_document_root(options['relative_document_root']),
    "locations" => {
      %q(/) => {
        "try_files"     => "$uri $uri/ @ruby_app"
      },
      %q(~* \.(jpg|jpeg|gif|html|png|css|js|ico|txt|xml)$) => {
        "access_log"    => "off",
        "log_not_found" => "off",
        "expires"       => "365d"
      },
      %q(@ruby_app) => {
        "proxy_set_header"       => ["X-Forwarded-For $proxy_add_x_forwarded_for",
                                     "Host $http_host"],
        "proxy_redirect" => "off",
        "proxy_pass"    => "http://ruby_app"
      },
      %q(~ ^/(status|ping)$) => {
        "access_log"    => "off",
        "allow"         => node['mo_application_php']['status']['allow'],
        "deny"          => "all",
        "include"       => "fastcgi_params",
        "fastcgi_pass"  => "unix:#{fpm_socket}"
      }
    },
    "keepalive_timeout" => "10",
    "client_max_body_size" => "2G"
  }
end

def setup_upstart
  directory "/home/#{new_resource.user}/.init" 
end
