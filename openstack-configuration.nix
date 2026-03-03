{ pkgs, lib, ... }:
{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  system.stateVersion = "25.11";

  services.cloud-init = {
    enable = true;
    network.enable = true;
    settings = {
      datasource_list = [
        "Ec2"
        "ConfigDrive"
      ];
      ssh_pwauth = false;
      growpart = {
        mode = "auto";
        devices = [ "/" ];
      };
      resize_rootfs = true;
      system_info.default_user = {
        name = "nixos";
        lock_passwd = true;
        groups = [ "wheel" ];
        sudo = [ "ALL=(ALL) NOPASSWD:ALL" ];
      };
    };
  };

  # Avoid legacy EC2 user-data nixos-rebuild behavior; use cloud-init instead
  systemd.services.amazon-init.enable = lib.mkForce false;

  networking.useDHCP = false;

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  services.qemuGuest.enable = true;

  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [
    cloud-init
    qemu-utils
    git
    nano
    vim
  ];
}
