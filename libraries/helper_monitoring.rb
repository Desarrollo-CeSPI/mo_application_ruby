def mo_application_ruby_monitoring_from_databag(cookbook_name)
  mo_application_from_data_bag(cookbook_name, false).tap do |data|
    mo_application_ruby_monitoring data
  end
end

def mo_application_ruby_monitoring(data)
  mo_application_http_check data
  mo_application_custom_check data
end
