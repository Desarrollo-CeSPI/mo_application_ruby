# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.require_version ">= 1.5.0"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  if Vagrant.has_plugin?("vagrant-cachier")
    config.cache.scope = :box
  end

  config.vm.define 'app' do |app|
    app.vm.hostname = "mo-application-ruby.vagrant.desarrollo.unlp.edu.ar"
    app.omnibus.chef_version = :latest
    app.vm.box = "chef/ubuntu-14.04"
    app.vm.network :private_network, ip: "10.101.5.2"
    app.berkshelf.enabled = true
    app.vm.provision :chef_solo do |chef|
      chef.json = {
      }
      chef.run_list = [
        "recipe[apt::default]",
        "recipe[mo_application_ruby::install]"
      ]
    end
  end
end
