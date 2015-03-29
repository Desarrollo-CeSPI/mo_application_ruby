class MoApplicationRuby
  module DeployResourceBase
    def self.included(klass)
      klass.send(:include, ::MoApplication::DeployResourceBase)
      klass.attribute :ruby_version, :kind_of => String, :default => "2.1.4"
      klass.attribute :bundle_without_groups, :kind_of => Array, :default => %q(development test)
    end

    # All services will depend on this service name
    def main_service
      "application"
    end

    # Upstart service name
    def upstart_service(name)
      "#{user}/#{name}"
    end

    def initialize(name, run_context=nil)
      super
      @user = name
      @group = name
      @home = "/home/#{user}"
      @environment = {"RACK_ENV" => "production" }
      @restart_command = "sudo service #{user}/application restart"
      me = self
      @before_migrate = Proc.new do
        bundle_binstubs = ::File.join(me.path, me.relative_path, 'shared','bundle-bin')
        bundle_path = ::File.join(me.path, me.relative_path, 'shared','bundle')
        rbenv_execute "Run bundle install #{me.name}" do
          command "bundle install --deployment --binstubs #{bundle_binstubs} --path #{bundle_path} --without #{Array(me.bundle_without_groups).join}"
          cwd release_path
          environment me.environment
          ruby_version me.ruby_version
          user me.user
        end
      end
      @provider = lookup_provider_constant :mo_application_ruby
    end

  end
end


