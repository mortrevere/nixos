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

  houseLeoSurf.certSyncPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDBI8fr4dZLJ52Bj2i4LgExkFHuLIiyeUW+UitsGuA75 cert-sync";

  homeServer = {
    wifi = {
      ssidVariable = "BLACK_WIFI_SSID";
      pskVariable = "BLACK_WIFI_PSK";
    };
    firewall.extraInputRules = [
      "tcp dport 80 accept"
      "tcp dport 443 accept"
    ];
    storage.periodicScan = true;
  };
}
