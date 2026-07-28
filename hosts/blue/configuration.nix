_:

{
  imports = [
    ../../modules/base.nix
    ../../modules/server.nix
    ./hardware-configuration.nix
    ./containers.nix
    ./move-completed-films.nix
  ]
  ++ (if builtins.pathExists ./private.nix then [ ./private.nix ] else [ ]);

  boot.loader.grub.enable = false;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  security.sudo.wheelNeedsPassword = false;

  houseLeoSurf.certSyncPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDBI8fr4dZLJ52Bj2i4LgExkFHuLIiyeUW+UitsGuA75 cert-sync";

  homeServer = {
    wifi = {
      ssidVariable = "BLUE_WIFI_SSID";
      pskVariable = "BLUE_WIFI_PSK";
    };
    firewall.extraInputRules = [
      "tcp dport 80 accept"
      "tcp dport 443 accept"
      "tcp dport 51413 accept"
      "udp dport 51413 accept"
    ];
  };

}
