# The per-platform machine spec lives in vagrant-env/<platform>.yaml and is
# parsed here with Ruby's stdlib YAML (no external gem needed). The spec is a
# tree of shadowing parameters: params declared at the top level are overridden
# by provider-level params, which are in turn overridden by architecture-level
# params. This lets each file specify only what differs from the defaults.
require "yaml"

platform = ENV.fetch("DOTFILES_PLATFORM")
spec = YAML.load_file(File.join(__dir__, "vagrant-env", "#{platform}.yaml"))

# Normalize an architecture name to the tokens used in the spec files so host
# detection and spec lookup agree (uname reports arm64/x86_64; specs use
# arm64/amd64).
def normalize_arch(name)
  case name
  when "arm64", "aarch64" then "arm64"
  when "x86_64", "amd64", "x64" then "amd64"
  else name
  end
end

host_arch = normalize_arch(`uname -m`.strip)

# Provider: an explicit override wins, otherwise use the platform's first-listed
# (preferred) provider.
providers = spec.fetch("providers")
provider_name = ENV["DOTFILES_VAGRANT_PROVIDER"] || providers.first.fetch("name")
provider = providers.find { |p| p.fetch("name") == provider_name }
raise "Provider '#{provider_name}' not supported by platform '#{platform}'" if provider.nil?

# The arch field is flexible: a single string, a list of strings, or a list of
# {name, ...} objects. Normalize all three to a list of hashes.
arch_entries =
  case (arch_field = provider.fetch("arch"))
  when String then [{"name" => arch_field}]
  when Array then arch_field.map { |a| a.is_a?(String) ? {"name" => a} : a }
  else raise "Invalid 'arch' for #{platform}/#{provider_name}"
  end

# Prefer an explicit override, then the arch matching the host, then the first
# supported arch (e.g. emulation when the host arch has no native box).
wanted_arch = normalize_arch(ENV["DOTFILES_VAGRANT_ARCH"] || host_arch)
arch = arch_entries.find { |a| a.fetch("name") == wanted_arch } || arch_entries.first

# Merge the shadowing lineage: top-level -> provider -> arch. Scalar fields
# (box, setup_dir) and the params bag both shadow.
def merge_level(into, level)
  into["box"] = level["box"] if level.key?("box")
  into["setup_dir"] = level["setup_dir"] if level.key?("setup_dir")
  into["params"].merge!(level.fetch("params", {}))
end

defaults = {
  "params" => {
    "cpu_count" => 2,
    "memory_mb" => 4096,
    "libvirt_driver" => "kvm",
    "libvirt_uri" => "qemu://system",
    "qemu_machine" => "virt,accel=hvf,highmem=off",
    "qemu_cpu" => "host",
  }
}

resolved = {"params" => {}}
[defaults, spec, provider, arch].each { |level| merge_level(resolved, level) }

box = resolved.fetch("box")
setup_dir = resolved.fetch("setup_dir")
params = resolved.fetch("params")

Vagrant.configure("2") do |config|
  config.vm.box = box

  case provider_name
  when "qemu"
    config.vagrant.plugins = ["vagrant-qemu"]
    config.vm.provider "qemu" do |qe|
      qe.arch = arch.fetch("name") == "arm64" ? "aarch64" : "x86_64"
      qe.machine = params["qemu_machine"] if params["qemu_machine"]
      qe.cpu = params["qemu_cpu"] if params["qemu_cpu"]
      qe.net_device = params["qemu_net_device"] if params["qemu_net_device"]
      qe.memory = "#{params.fetch('memory_mb')}M"
      qe.smp = params.fetch("cpu_count")
      # vagrant-qemu has no disk-resize option; the guest disk is whatever the
      # box ships, so disk_gb (shared with the other providers) is not applied
      # here. Rebuild the box or add a qemu-img resize step if it ever matters.
    end
  when "libvirt"
    config.vagrant.plugins = ["vagrant-libvirt"]
    config.vm.provider "libvirt" do |lv|
      lv.memory = params.fetch("memory_mb")
      lv.cpus = params.fetch("cpu_count")
      lv.machine_virtual_size = params["disk_gb"] if params["disk_gb"]
      lv.driver = params["libvirt_driver"] if params["libvirt_driver"]
      lv.uri = params["libvirt_uri"] if params["libvirt_uri"]
    end
  when "virtualbox"
    config.vagrant.plugins = ["vagrant-disksize"]
    config.disksize.size = "#{params.fetch('disk_gb')}GB" if params["disk_gb"]
    config.vm.provider "virtualbox" do |vb|
      vb.memory = params.fetch("memory_mb")
      vb.cpus = params.fetch("cpu_count")
    end
  else
    raise "Unhandled provider '#{provider_name}'"
  end

  # Setup as root user.
  config.vm.provision "shell", inline: "/vagrant/#{setup_dir}/setup.sh"
  # Configure as root user.
  config.vm.provision "shell", inline: "/vagrant/config/config.sh"
  # Configure as non-root user.
  config.vm.provision "shell", inline: "/bin/su --command '/vagrant/config/config.sh' vagrant"
end
