actions :install, :remove
default_action :install

include ::MoApplicationRuby::DeployResourceBase

def initialize(name, run_context=nil)
  super
  @shared_dirs = {'log' => 'log', 'tmp' => 'tmp'}
end
