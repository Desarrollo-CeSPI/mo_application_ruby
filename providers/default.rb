include MoApplication::DeployProviderBase
include Chef::Mixin::Rbenv

action :install do
  install_application
end

action :remove do
  uninstall_application
end


# Prior to install everything we will setup specified ruby version
def install_application
  setup_ruby
  super
end

def configure_user_environment
  custom_bashrc = ".bashrc.custom"

  bash "append_to_bash_rc #{new_resource.name}" do
   user new_resource.user
   code <<-EOF
      echo 'source $HOME/#{custom_bashrc}' >> /home/#{new_resource.user}/.bashrc
   EOF
   not_if "grep -q 'source $HOME/#{custom_bashrc}' /home/#{new_resource.user}/.bashrc "
 end

  file "/home/#{new_resource.user}/#{custom_bashrc}" do
    owner new_resource.user
    mode  '0600'
    content <<-EOF
export RACK_ENV=production
export RAILS_ENV=production
# cd to current app path
alias cdp='cd $HOME/application/current'
# run a rails console in the current app path
alias rc='cdp && bin/rails console'
# run rake db:migrate in the current app path
alias rdm='cdp && bin/rake db:migrate'
# tail -f current application logs
alias logs='cdp && tail -f log/*.log'
# interact with the application's service
alias srv='sudo service $USER/application'
# shorthand alias to restart the application
alias restart='srv restart'
    EOF
  end
end

# Install ruby
def setup_ruby
  rbenv_ruby new_resource.ruby_version
  rbenv_gem "bundler" do
    ruby_version new_resource.ruby_version
  end
end

# Service name can redirect stdout to this file
def application_log(name)
  ::File.join(application_shared_path, new_resource.log_dir,"#{name}.log")
end

# Service name can redirect stderr to this file
def application_error_log(name)
  ::File.join(application_shared_path, new_resource.log_dir,"#{name}-error.log")
end


# custom dirs to be created need to include upstart for services
def custom_dirs
  [upstart_base_dir]
end

# Configures upstart services files: 
# a main user/#{main_service} service and
# foreach specified service a user/service that will depend on user/#{main_service}
def create_services
  file ::File.join(upstart_base_dir, "#{main_service}.conf") do
    owner new_resource.user
    content <<-FILE
start on runlevel [2345]
stop on runlevel [!2345]
    FILE
  end

  environment = new_resource.environment.merge({"PATH" => ([rbenv_shims_path, rbenv_bin_path] + system_path).uniq.join(":")})
  depends = upstart_service(main_service)
  new_resource.services.each do |service, opts|
    raise "Upstart service must have an exec section for service #{service}" unless opts['exec']
    template ::File.join(upstart_base_dir,"#{service_name service}.conf") do
      source "upstart-template.conf.erb"
      owner new_resource.user
      cookbook 'mo_application_ruby'
      variables(
        :env => environment,
        :depends => depends,
        :setuid => new_resource.user,
        :chdir => application_current_path,
        :exec => opts['exec'],
        :options => Array(opts['options']),
        :log => application_log(service),
        :error_log => application_error_log(service))
    end
  end
end

# This array is a super method used to create sudo service restart permissions
def services_names
  super.map {|x| upstart_service(service_name(x))} << upstart_service(main_service)
end

# Remove services action must stop service before remove
# And then remove each script created
def remove_services
  service upstart_service(main_service) do
    provider Chef::Provider::Service::Upstart
    action :stop
  end

  directory upstart_base_dir do
    recursive true
    action :delete
  end
end

# Helper method to name each nginx upstream
def nginx_upstream(name)
  "#{new_resource.name}_#{name}_ruby_app"
end

# Helper method that returns application's socket
def ruby_application_socket(name)
  ::File.join(full_var_run_directory, "#{nginx_application_name name}.sock")
end

# Helper method that returns application's pid
def ruby_application_pidfile(name)
  ::File.join(full_var_run_directory, "#{nginx_application_name name}.pid")
end

# Custom nginx_options foreach ruby application
def nginx_options_for(action, name, options)
  allow_from = options && options.has_key?('allow') ? options.delete('allow') : false
  {
    "action"    => action,
    "upstream" => {
      nginx_upstream(name) => {
        "server"  => "unix:#{ruby_application_socket(name)}"
      }
    },
    "listen"    => "80",
    # path for static files
    "root"      => nginx_document_root(options['relative_document_root'] || 'public'),
    "locations" => {
      "@#{nginx_upstream(name)}" => {
        "proxy_set_header"  => ["X-Forwarded-For $proxy_add_x_forwarded_for",
                                     "Host $http_host"],
        "proxy_redirect" => "off",
        "proxy_pass" => "http://#{nginx_upstream(name)}",
      },
      %q(/) => {
        "try_files" => "$uri @#{nginx_upstream(name)}",
      }.merge(allow_from ? {'allow' => allow_from, 'deny' => 'all'}: {}),
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
      "access_log"  => www_access_log(name),
      "error_log"   => www_error_log(name),
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
    }.merge(options['options'] || Hash.new),
  }
end

private

# Where will upstart services for this application will be stored
def upstart_base_dir
  "/etc/init/#{new_resource.user}"
end

# All services will depend on this service name
def main_service
  new_resource.main_service
end

# Upstart service name
def upstart_service(name)
  new_resource.upstart_service(name)
end

def service_name(name)
  "#{main_service}-#{name}"
end

# Returns current PATH environment
def system_path
  shell_out!("echo $PATH").stdout.chomp.split(':')
end

