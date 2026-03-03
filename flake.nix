{
  description = "NixOS cloud-init images for installer ISO and OpenStack";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11"; # Change me on NixOS upgrades!
  };

  outputs = { self, nixpkgs }: {
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
    };
  };
}
