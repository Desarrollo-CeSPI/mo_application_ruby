include_recipe 'mo_application::install'
include_recipe 'java::default'

%w(
  git git-core build-essential libreadline6-dev zlib1g-dev libssl-dev bison
  libxml2-dev libxslt-dev libmysqlclient-dev mysql-client libmagickwand-dev
  imagemagick libmagickcore-dev lsb-core lsb-release nodejs npm libffi-dev).
  each { |p| package p }

