# dotfiles2

Second major version of my personal dotfiles.
You can find the old ones [here](https://github.com/chpatton013/dotfiles).

## Design

I don't want to reinvent the wheel every time I spin up a new platform. I like
my systems to be more-or-less the same; the OS I'm running on shouldn't impact
me. So I designed my dotfiles accordingly.

All platform-specific steps to set up a machine are in one of the `setup-*`
directories. In each you will find an executable `setup.sh` script (the
entrypoint to configure the machine), an Ansible playbook, all of the
associated Ansible roles, and optionally a few other files leveraged by the
aforementioned setup script. Once that platform-specific setup script has been
applied, you should never need to run it again unless you intend to add new
software to the system, or want to upgrade software on the system.

The entirety of the user-space configuration should be platform-agnostic. You
can apply if by running `config/config.sh`. By religiously leveraging common
conventions such as XDG directories, I can ensure that all personal
configuration files are the same across all of my platforms. Anytime you make a
configuration change you should be able to re-apply this config script and see
the effect immediately.

## Usage

1. Find the `setup-*` directory for your platform and run the contained
   `setup.sh` script. This will install all dependencies for the setup tools and
   then apply the platform-specific setup playbook.
1. Run `config/config.sh`. This will apply the platform-agnostic config
   playbook.

### What about SecureBoot?

If you must use it, you will notice failures upon attempting to load kernel
modules (most likely during application of the setup playbook). You must create
a signing key and sign each kernel module in order to resolve these problems:

```
sudo secure-boot/create-signing-key.sh
sudo secure-boot/sign-module.sh MODULE1 MODULE2 ETC
```

## Testing changes

Vagrant really is the best option for a testing harness due to its flexibility
to run with different platforms (boxes). However, it normally is difficult to
dynamically change the platform you're running on because Vagrant is backed by
virtual machines.

To work around this I made a thin wrapper script and config loading convention.
Supported platforms have a spec file at `vagrant-env/$PLATFORM_NAME.yaml`
describing the box, setup directory, and machine parameters. The `Vagrantfile`
parses it (via Ruby's stdlib YAML — no plugin needed) and builds the VM. Params
form a shadowing tree: values at the top level are overridden by provider-level
values, which are in turn overridden by architecture-level values, so each file
specifies only what differs from the defaults.

The harness uses the **qemu** provider (via the `vagrant-qemu` plugin) by
default so it runs on any host, including Apple Silicon. Each platform lists the
providers it supports (the first is the default); `virtualbox` and `libvirt` are
also handled. Set `DOTFILES_VAGRANT_PROVIDER` to override the provider, and
`DOTFILES_VAGRANT_ARCH` to override the architecture.
**Caveat:** The harness prefers the architecture matching the host machine, but
falls back to the first architecture the platform lists (running under emulation,
with noticeable slowdown). For example, `archlinux` has no arm64 box, so on
Apple Silicon it emulates x86_64.
**Note:** `disk_gb` is only honored by the VirtualBox (`vagrant-disksize`
plugin) and libvirt providers; `vagrant-qemu` has no disk-resize option, so
under qemu the guest disk is whatever the box ships.

When you want to run `vagrant`, you instead run the following (substituting
`PLATFORM_NAME` and `OPTIONS` accordingly:
```
DOTFILES_PLATFORM=PLATFORM_NAME ./vagrant.sh OPTIONS
```

Or you can set the `DOTFILES_PLATFORM` environment variable to something
persistently; up to you. However, you always must invoke the `vagrant.sh`
wrapper script.

To perform a full test of the system for the `archlinux` platform, you would run
the following:
```
export DOTFILES_PLATFORM=archlinux
./vagrant.sh up --no-provision
./vagrant.sh provision
# make changes, repeat provision command
```

And if you wanted to cleanup after yourself, you would run:
```
export DOTFILES_PLATFORM=archlinux
./vagrant.sh halt
./vagrant.sh destroy
```
