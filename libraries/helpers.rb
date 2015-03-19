def _ruby_application(data, rails_application, &before_deploy_block)
  meth = rails_application ? :mo_application_ruby_rails : :mo_application_ruby
  send meth, data['id'] do
    if data['migration_command']
      migration_command data['migration_command']
    end
    user data['user']
    group data['group']
    action (data['remove'] ? :remove : :install)
    path data['path']
    repo data['repo']
    revision data['revision']
    force_deploy data['force_deploy']
    ssh_private_key data['ssh_private_key']
    shared_files data['shared_files']
    shared_dirs data['shared_dirs']
    nginx_config data['applications']
    before_deploy(&before_deploy_block)
    ssh_keys data['ssh_keys']
    services data['services']
  end
  setup_dotenv data
end

def ruby_application(data, &before_deploy_block)
  _ruby_application(data, false, &before_deploy_block)
end

def rails_application(data, &before_deploy_block)
  _ruby_application(data, true, &before_deploy_block)
end
