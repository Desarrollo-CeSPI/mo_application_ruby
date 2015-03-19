class MoApplicationRuby
  module DeployResourceBase
    def self.included(klass)
      klass.send(:include, ::MoApplication::DeployResourceBase)
      klass.attribute :ruby_version, :kind_of => String, :default => "2.1.4"
      klass.attribute :bundle_without_groups, :kind_of => Array, :default => %q(development test)
    end

    def initialize(name, run_context=nil)
      super
      @callbacks = {}
      @user = name
      @group = name
      @home = "/home/#{user}"
      @environment = {"RACK_ENV" => "production" }
      me = self
      @before_migrate = Proc.new do
        bundle_binstubs = ::File.join(me.path,me.relative_path, 'shared','bundle','bin')
        rbenv_execute "Run bundle install #{me.name}" do
          command "bundle install --deployment --binstubs #{bundle_binstubs} --without #{Array(me.bundle_without_groups).join}"
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


