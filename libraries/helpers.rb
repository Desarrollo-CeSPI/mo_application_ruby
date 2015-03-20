
def ruby_application(data, &before_deploy_block)
  mo_application_deploy(data, :mo_application_ruby, &before_deploy_block)
end

def rails_application(data, &before_deploy_block)
  mo_application_deploy(data, :mo_application_ruby_rails, &before_deploy_block)
end
