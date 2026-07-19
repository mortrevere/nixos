_:

{
  imports = [
    ../../modules/base.nix
    ../../modules/server.nix
    ./hardware-configuration.nix
    ./containers.nix
  ]
  ++ (if builtins.pathExists ./private.nix then [ ./private.nix ] else [ ]);

  boot.loader.grub.enable = false;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  security.sudo.wheelNeedsPassword = false;

  homeServer = {
    wifi = {
      ssidVariable = "BLUE_WIFI_SSID";
      pskVariable = "BLUE_WIFI_PSK";
    };
    firewall.extraInputRules = [
      "tcp dport 80 accept"
      "tcp dport 51413 accept"
      "udp dport 51413 accept"
    ];
  };
}
