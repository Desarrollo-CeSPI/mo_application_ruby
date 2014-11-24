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
    recursive true
    owner www_user
    group www_group
  end

  setup_upstart

  sudo_reload :install

  setup_ssh new_resource.user, new_resource.group, new_resource.ssh_private_key

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

  sudo_reload :remove
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

def nginx_upstream
  "#{new_resource.name}_ruby_app"
end

def nginx_options_for(action, name, options)
  {
    "action"    => action,
    "upstream" => {
      nginx_upstream => {
        "server"  => "unix:#{nginx_document_root(::File.join('shared', options['shared_socket'] || 'var/run/socket'))}"
      }
    },
    "listen"    => "80",
    # path for static files
    "root"      => nginx_document_root(::File.join('current', options['relative_document_root'] || 'public')),
    "locations" => {
      "@#{nginx_upstream}" => {
        "proxy_set_header"  => ["X-Forwarded-For $proxy_add_x_forwarded_for",
                                     "Host $http_host"],
        "proxy_redirect" => "off",
        "proxy_pass" => "http://#{nginx_upstream}",
      },
      %q(/) => {
        "try_files" => "$uri @#{nginx_upstream}",
      }.merge(options['allow'] ? {'allow' => options['allow'], 'deny' => 'all'}: {}),
      # Now this supposedly should work as it gets the filenames with querystrings that Rails provides.
      # BUT there's a chance it could break the ajax calls.
      %q(~* \.(ico|css|gif|jpe?g|png|js)(\?[0-9]+)?$) => {
        "try_files"     => "$uri @#{nginx_upstream}",
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

def setup_upstart
  directory "/etc/init/#{new_resource.user}" do
    owner new_resource.user
    group new_resource.group
  end
end

def sudo_reload(to_do)
  service_name = "#{new_resource.user}/application"
  sudo "ruby_app_#{new_resource.user}" do
    user      new_resource.user
    runas     'root'
    commands  ["/usr/sbin/service #{service_name} *", "/sbin/start #{service_name}", "/sbin/stop #{service_name}", "/sbin/restart #{service_name}"]
    nopasswd  true
    action to_do
  end
end
