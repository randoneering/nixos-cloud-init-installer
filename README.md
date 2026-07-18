# nixos-cloud-init-installer
A minimal NixOS flake for building NixOS installer ISOs plus cloud-init guest images for OpenStack and Proxmox.

This repository contains two different image families:

- Installer ISOs, intended for booting a live environment and then installing NixOS.
- Cloud-init guest images, intended to be imported directly as VM disks on platforms like OpenStack and Proxmox.

The installer ISO path was designed for workflows that boot a temporary live system on a Proxmox VM and then run `nixos-anywhere`. The cloud-init guest image paths are for template-style VM images that boot directly into an installed NixOS system.

There exist pre-built ISO images that you are able to download, for both x86_64 and aarch64, in this repository's releases.

Built against `nixos-26.05`. Bump `nixpkgs.url` in `flake.nix` on major releases.

**NOTE:** SSH login via password is disabled, for security reasons! Instead, it is recommended to pass public SSH keys to NixOS via cloud-init when using this installer. However, for ease of installation, no password is required to use sudo.

## Available image targets

| Target | Architecture | Output (`./result`) | Built via | Use case |
| --- | --- | --- | --- | --- |
| `installer-iso` | x86_64, aarch64 | bootable `.iso` | `isoImage` (`configuration.nix`) | Live installer for `nixos-anywhere` |
| `openstack-image` | x86_64, aarch64 | `qcow2` archive | `images.openstack` (`openstack-configuration.nix`) | OpenStack Glance upload |
| `proxmox-image` | x86_64, aarch64 | `.vma.zst` Proxmox archive | `images.proxmox` (`openstack-configuration.nix` + NoCloud datasource) | Proxmox `qmrestore` template |

All three are exposed as both `nixosConfigurations.<arch>-<variant>` and `packages.<system>.<name>`. Cross-architecture builds require binfmt/QEMU on the host (see below).

## Build installer ISO images

This assumes that you have Nix installed on your system, with flakes and nix-commands enabled.

`nixos-generators` is deprecated as of newer NixOS releases. The commands below use the built-in `nixos-rebuild build-image` workflow instead.

If you prefer plain `nix build`, this flake also exposes package outputs for the current build system:

- `.#installer-iso`
- `.#openstack-image`
- `.#proxmox-image`

1. First, clone this Git repository.
2. Then, you can run one of these commands based on the architecture that you want to target:

**x86_64 (Intel/AMD):**
```bash
nixos-rebuild build-image \
  --image-variant iso \
  --flake .#x86_64
```

Or:
```bash
nix build .#installer-iso
```

**aarch64 (ARM64):**
```bash
nixos-rebuild build-image \
  --image-variant iso \
  --flake .#aarch64
```

If you are building for a non-native architecture, you can also select the package output explicitly:
```bash
nix build .#packages.aarch64-linux.installer-iso
```

After building, your image will be linked from `./result`.

These ISO targets intentionally boot a live installer environment because `configuration.nix` imports `installation-cd-minimal.nix`.

## Build OpenStack guest images

These targets are intended for OpenStack "user-provided" images and are separate from the installer ISO targets.

The OpenStack image profile is defined in `openstack-configuration.nix` and is exposed by two flake targets:

- `openstack-x86_64`
- `openstack-aarch64`

This profile enables cloud-init metadata/network handling (EC2 + ConfigDrive), auto-resizes the root filesystem on first boot, enables the QEMU guest agent, and disables `amazon-init` so cloud-init owns first-boot initialization.

**x86_64 (Intel/AMD):**
```bash
nixos-rebuild build-image \
  --image-variant openstack \
  --flake .#openstack-x86_64
```

Or:
```bash
nix build .#openstack-image
```

**aarch64 (ARM64):**
```bash
nixos-rebuild build-image \
  --image-variant openstack \
  --flake .#openstack-aarch64
```

Or explicitly:
```bash
nix build .#packages.aarch64-linux.openstack-image
```

After building, the image will be linked from `./result`.

OSL recommends uploading `raw` images on Ceph-backed OpenStack. If your output is qcow2, convert it first:

```bash
qemu-img convert -O raw -p ./result nixos-openstack.raw
```

Source your OpenStack RC file first (downloaded from Horizon, usually as `*openrc.sh`):

```bash
source ~/Downloads/*openrc.sh
```

Then upload with image properties that match OSL defaults:

```bash
openstack image create \
  --file nixos-openstack.raw \
  --disk-format raw \
  --container-format bare \
  --property hw_scsi_model=virtio-scsi \
  --property hw_disk_bus=scsi \
  --property hw_qemu_guest_agent=yes \
  --property os_require_quiesce=yes \
  nixos-26.05-openstack
```

Verify the image reached `active` status and has the expected properties:

```bash
openstack image show nixos-26.05-openstack
```

## Build Proxmox guest images

These targets are intended for Proxmox cloud-init VM templates and are separate from the installer ISO targets.

The Proxmox image profile reuses the OpenStack guest-image configuration, but switches cloud-init to prefer Proxmox's default Linux datasource order (`NoCloud`, with `ConfigDrive` as a fallback).

- `proxmox-x86_64`
- `proxmox-aarch64`

**x86_64 (Intel/AMD):**
```bash
nixos-rebuild build-image \
  --image-variant proxmox \
  --flake .#proxmox-x86_64
```

Or:
```bash
nix build .#proxmox-image
```

**aarch64 (ARM64):**
```bash
nixos-rebuild build-image \
  --image-variant proxmox \
  --flake .#proxmox-aarch64
```

Or explicitly:
```bash
nix build .#packages.aarch64-linux.proxmox-image
```

After building, the image will be linked from `./result`.

This produces a Proxmox-compatible VM archive rather than a live ISO. If you prefer importing a qcow2 disk manually, the `openstack-*` images also work on Proxmox, but the `proxmox-*` targets match Proxmox's default cloud-init datasource more closely.

### Notice for cross-compiling images
If building an image for an architecture different to the native architecture of the build host, you will need to configure Nix accordingly.

Firstly, you will need to add the target architecture to your list of extra platforms on Nix.

For NixOS, you just need to add this line to your configuration file: `boot.binfmt.emulatedSystems = [ "ARCHITECTURE_NAME" ];`

For non-NixOS systems, you just need to add this line to `nix.conf`: `extra-platforms = ARCHITECTURE_NAME`

**Example for an x86_64 build system targeting aarch64:**
- `extra-platforms = aarch64-linux`

Furthermore, on non-NixOS systems, you will need QEMU installed, particularly the `qemu-system` and `qemu-efi` for your target architecture, as well as `binfmt-support` and `qemu-user-static`. This will allow you to run the binaries of your target architecture that are necessary for building the image with that architecture.

**Example apt command for Ubuntu on x86_64, for compiling as aarch64:**
- `sudo apt install qemu-system-aarch64 qemu-efi-aarch64 binfmt-support qemu-user-static` 

**NOTE:** As this approach uses emulation (with QEMU), build time is significantly increased, compared to native builds.

## Example workflow with Ansible on Proxmox
**1. Building or retrieving the ISO image**

Ansible can either build an ISO image (with the commands above), or download the latest release from GitHub.

**2. Uploading the ISO image to Proxmox**

The ISO image is then uploaded to Proxmox storage (accessible by the target node).

**3. Provisioning a new virtual machine**

Using the information from the playbook's inventory, as well as other provided variables, Ansible requests that Proxmox provision a new virtual machine. Furthermore, it attaches a cloud-init drive, providing credentials (e.g. SSH keys) and networking details needed by nixos-anywhere.

**4. Booting the virtual machine with the ISO image and cloud-init**

After the virtual machine is ready to start, Ansible boots the virtual machine, waiting until it can establish an SSH connection. Once NixOS is booted, cloud-init injects the listed credentials and details, allowing for unattended setup and SSH access.

**5. Initiating the install with nixos-anywhere**

With SSH ready, Ansible then runs nixos-anywhere, using the provided SSH key and a NixOS flake configuration, to then remotely install NixOS onto the virtual machine's disk. After this, NixOS should reboot into the new system.

**6. Post-installation**

With NixOS completely installed on the virtual machine, Ansible detaches the cloud-init drive and the ISO image, as they are no longer needed.

## Login to a restored Proxmox VM

`openstack-configuration.nix` ships with:

- `ssh_pwauth = false`
- `system_info.default_user = { name = "nixos"; lock_passwd = true; groups = [ "wheel" ]; sudo = [ "ALL=(ALL) NOPASSWD:ALL" ]; }`
- `services.openssh.settings.PermitRootLogin = "prohibit-password"` and `PasswordAuthentication = false`

Result: SSH key only, no password, sudo with no password.

A `.vma.zst` restored via `qmrestore` boots with no metadata attached. To get an SSH key in:

```bash
qm set <vmid> --ide2 local-lvm:cloudinit
qm set <vmid> --sshkey ~/.ssh/id_ed25519.pub
qm set <vmid> --ipconfig0 ip=dhcp
qm reboot <vmid>
```

Then:

```bash
ssh -i ~/.ssh/id_ed25519 nixos@<vm-ip>
```

If the VM was already booted once with no key, Proxmox's *Regenerate Image* in the Cloud-Init tab bumps the cloud-init `instance-id` so cloud-init re-runs and pulls the new key.
