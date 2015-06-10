require 'chef/mixin/shell_out'

include Chef::Mixin::Rbenv


def update_installed_ruby
    out = shell_out("rbenv versions --bare",
                    :user => node['rbenv']['user'],
                    :cwd  => rbenv_root_path,
                    :env  => { 'RBENV_ROOT' => rbenv_root_path })
    out.stdout.chomp.split.each {|v| update_ruby v}
end

def update_ruby(ruby_version)
  rbenv_execute "update bundler #{ruby_version}" do
    user node['rbenv']['user']
    command "gem update bundler"
    action :nothing
    ruby_version ruby_version
  end

  rbenv_execute "gem update system #{ruby_version}" do
    user node['rbenv']['user']
    command "gem update --system"
    action :nothing
    ruby_version ruby_version
    notifies :run, "rbenv_execute[update bundler #{ruby_version}]", :immediate
  end

  ruby_block "update ruby #{ruby_version}" do
    block do
      rbenv_command("install --force #{ruby_version}")
    end
    only_if { node['mo_application_ruby']['update_gems'] }
    notifies :run, "rbenv_execute[gem update system #{ruby_version}]", :immediate
  end
end
