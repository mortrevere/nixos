_:

{
  imports = [
    ../../modules/base.nix
    ../../modules/server.nix
    ./hardware-configuration.nix
    ./containers.nix
  ]
  ++ (if builtins.pathExists ./private.nix then [ ./private.nix ] else [ ]);

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
    useOSProber = true;
  };

  security.sudo.wheelNeedsPassword = false;

  homeServer = {
    wifi = {
      ssidVariable = "BLACK_WIFI_SSID";
      pskVariable = "BLACK_WIFI_PSK";
    };
    firewall.extraInputRules = [ "tcp dport 80 accept" ];
    storage.periodicScan = true;
  };
}
