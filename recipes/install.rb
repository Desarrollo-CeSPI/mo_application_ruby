include_recipe 'chef-msttcorefonts::default'
include_recipe 'mo_application::install'

%w(
  git build-essential libreadline6-dev zlib1g-dev libssl-dev bison libxml2-dev
  libxslt-dev libmysqlclient-dev mysql-client libmagickwand-dev openjdk-7-jre).
  each { |p| package p }

