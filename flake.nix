{
  description = "NixOS cloud-init images for installer ISO and OpenStack";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05"; # Change me on NixOS upgrades!
  };

  outputs = { self, nixpkgs }:
  let
    nixosConfigurations = {
      x86_64 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
        ];
      };
      aarch64 = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          ./configuration.nix
        ];
      };
      openstack-x86_64 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./openstack-configuration.nix
        ];
      };
      openstack-aarch64 = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          ./openstack-configuration.nix
        ];
      };
      proxmox-x86_64 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./openstack-configuration.nix
          ({ lib, ... }: {
            services.cloud-init.settings.datasource_list = lib.mkForce [
              "NoCloud"
              "ConfigDrive"
            ];
          })
        ];
      };
      proxmox-aarch64 = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          ./openstack-configuration.nix
          ({ lib, ... }: {
            services.cloud-init.settings.datasource_list = lib.mkForce [
              "NoCloud"
              "ConfigDrive"
            ];
          })
        ];
      };
    };
  in {
    inherit nixosConfigurations;

    packages.x86_64-linux = {
      installer-iso = nixosConfigurations.x86_64.config.system.build.isoImage;
      openstack-image = nixosConfigurations.openstack-x86_64.config.system.build.images.openstack;
      proxmox-image = nixosConfigurations.proxmox-x86_64.config.system.build.images.proxmox;
    };

    packages.aarch64-linux = {
      installer-iso = nixosConfigurations.aarch64.config.system.build.isoImage;
      openstack-image = nixosConfigurations.openstack-aarch64.config.system.build.images.openstack;
      proxmox-image = nixosConfigurations.proxmox-aarch64.config.system.build.images.proxmox;
    };
  };
}
