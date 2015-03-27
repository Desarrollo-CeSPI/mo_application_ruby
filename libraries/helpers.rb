def _ruby_app_deploy(data, which, &before_deploy_block)
  r = mo_application_deploy(data, which, &before_deploy_block)
  node.set[:rbenv][:group_users] = Array(node[:rbenv][:group_users]) + [ r.user ]
  group node[:rbenv][:group] do
    members node[:rbenv][:group_users]
    action :modify
  end
end

def ruby_application(data, &before_deploy_block)
  _ruby_app_deploy(data, :mo_application_ruby, &before_deploy_block)
end

def rails_application(data, &before_deploy_block)
  _ruby_app_deploy(data, :mo_application_ruby_rails, &before_deploy_block)
end
