include ::MoApplication::DeployResourceBase

def initialize(name, run_context=nil)
  super
  @callbacks = {}
  @user = name
  @group = name
  @home = "/home/#{user}"
end


