{
  inputs,
  pkgs,
  username,
  ...
}:

{
  imports = [
    ../../modules/core.nix
    ./hardware-configuration.nix
    ./network.nix
    inputs.nixos-raspberrypi.nixosModules.raspberry-pi-4.base
    inputs.nixos-raspberrypi.nixosModules.raspberry-pi-4.display-vc4
    inputs.nixos-raspberrypi.lib.inject-overlays
    inputs.nixos-raspberrypi.nixosModules.trusted-nix-caches
  ];

  boot.loader.raspberry-pi = {
    enable = true;
    firmwarePath = "/boot/firmware";
    bootPath = "/boot";
  };

  users.users.${username} = {
    extraGroups = [ "networkmanager" ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDdwLcy4I1WBVCqTrhku3uVQ/bbXoatNuOm0k4rlctABC4mSACLvuIMIdXKUXdNisOgJ9FDUvL+jK3Jks9gi1AeDL0mP3cCBWu951pkI3j13SW78rKG5qUHfXbmiV2KfxTaVmLDXQTh2cy0+AJ7iuQIvglm5vSRmLSTg81UzxlEElb+wRiIwBPgMqD0yWb7HuRngBkQLS0ioydxOE9NQ4k/chCcLee5d1MEtHN9K28P6UdGqJcxKnrGyCoOiJygdBfHaYhjHyMYpV1hWNKY8vxODrd4Ja8iKXV1tdya1bNAt6eEyeIFDpRU8VunT+XL7YNzTcQdurGGnAwf7CENlWYh mortrevere@leo-vaio"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINtZ7X63RfDOWIi9q33xeoOOpKKjQMVN/uw5oYdeBQXx leo@MaitreYoga"
    ];
  };

  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
  };

  programs.hyprland = {
    enable = true;
    xwayland.enable = false;
  };

  hardware.graphics.enable = true;

  fonts.packages = [ pkgs.iosevka-bin ];

  services.greetd = {
    enable = true;
    settings.initial_session = {
      command = "${pkgs.hyprland}/bin/Hyprland";
      user = username;
    };
  };
}
