actions :install, :remove
default_action :install

include ::MoApplicationRuby::DeployResourceBase

def initialize(name, run_context=nil)
  super
  @shared_dirs = {'log' => 'log', 'tmp' => 'tmp', 'public/assets' => 'public/assets'}
  @environment = {"RACK_ENV" => "production", "RAILS_ENV" => "production"}
  @migration_command = "bundle exec rake db:migrate"
  me = self
  @before_restart = Proc.new do
    rbenv_execute "Run assets compile #{me.name}" do
      command "bundle exec rake assets:clean && bundle exec rake assets:precompile"
      cwd release_path
      environment me.environment
      ruby_version me.ruby_version
      user me.user
    end
  end
end


