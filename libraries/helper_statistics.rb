def mo_application_ruby_statistics_from_databag(cookbook_name)
  mo_application_from_data_bag(cookbook_name, false).tap do |data|
    mo_application_ruby_statistics data
  end
end

def mo_application_ruby_statistics(data)
  mo_collectd_user_rss data['id'], !!!data['remove']
  mo_collectd_file_count data['id'], mo_application_filecount_directories(data),!!!data['remove']
end

def mo_application_filecount_directories(data)
  {
    "home_#{data['user']}"  =>  "/home/#{data['user']}",
    "app_#{data['user']}"   =>  data['path']
  }
end
