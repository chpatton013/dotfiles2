vagrant_box = ENV.fetch("DOTFILES_VAGRANT_BOX")
vagrant_disksize = ENV.fetch("DOTFILES_VAGRANT_DISKSIZE")
setup_dir = ENV.fetch("DOTFILES_SETUP_DIR")

Vagrant.configure("2") do |config|
  config.vagrant.plugins = ["vagrant-disksize"]

  config.vm.box = vagrant_box
  config.disksize.size = vagrant_disksize
  config.vm.provider "virtualbox" do |vm|
    vm.memory = 4096
    vm.cpus = 2
  end

  # Setup as root user.
  config.vm.provision "shell", inline: "/vagrant/#{setup_dir}/setup.sh"
  # Configure as root user.
  config.vm.provision "shell", inline: "/vagrant/config/config.sh"
  # Configure as non-root user.
  config.vm.provision "shell", inline: "/bin/su --command '/vagrant/config/config.sh' vagrant"
end
