Vagrant.configure("2") do |config|
  config.vagrant.plugins = ["vagrant-disksize"]

  config.vm.box = "ubuntu/bionic64"
  config.disksize.size = "16GB"
  config.vm.provider "virtualbox" do |vm|
    vm.memory = 4096
    vm.cpus = 2
  end

  # Setup as root user.
  config.vm.provision "shell", inline: "/vagrant/setup-ubuntu/setup.sh"
  # Configure as root user.
  config.vm.provision "shell", inline: "/vagrant/config/config.sh"
  # Configure as non-root user.
  config.vm.provision "shell", inline: "/bin/su --command '/vagrant/config/config.sh' vagrant"
end
