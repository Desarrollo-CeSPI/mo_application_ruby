def _ruby_app_deploy(data, which, &before_deploy_block)
  r = mo_application_deploy(data, which, &before_deploy_block)

  node.set[:rbenv][:group_users] = if data['remove']
                                     Array(node[:rbenv][:group_users]).delete(r.user)
                                   else
                                     Array(node[:rbenv][:group_users]) + [ r.user ]
                                   end

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

def ruby_define_service
  run_context.resource_collection.find("service[#{new_resource.upstart_service(new_resource.main_service)}]")
  rescue Chef::Exceptions::ResourceNotFound
    service new_resource.upstart_service(new_resource.main_service) do
      provider Chef::Provider::Service::Upstart
      action :nothing
    end
end

def ruby_application_template(name, &block)
  ruby_define_service
  application_shared_template(name, &block).tap do |t|
    t.notifies :restart, "service[#{new_resource.upstart_service(new_resource.main_service)}]"
  end
end
