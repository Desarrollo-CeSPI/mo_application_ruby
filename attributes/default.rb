default['java']['install_flavor'] = 'oracle'
default['java']['jdk_version'] = '8'
default['java']['oracle']['accept_oracle_download_terms'] = true

default['mo_application_ruby']['rbenv']['ruby_version'] = "2.2.2"
default['mo_application_ruby']['update_gems'] = false

node.set['mo_backup']['ruby_version'] = node['mo_application_ruby']['rbenv']['ruby_version']
