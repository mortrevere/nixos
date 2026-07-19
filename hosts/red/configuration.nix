_:

{
  imports = [
    ../../modules/base.nix
    ../../modules/server.nix
    ../../modules/features/dhcp-server.nix
    ../../modules/features/nordvpn-gateway.nix
    ./hardware-configuration.nix
    ./containers.nix
  ]
  ++ (if builtins.pathExists ./private.nix then [ ./private.nix ] else [ ]);

  boot.loader.grub.enable = false;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  security.sudo.wheelNeedsPassword = false;

  homeLanDhcp = {
    enable = true;
    interface = "wlp0s20f3";
    router = "10.0.0.19";
  };

  nordvpnGateway = {
    enable = true;
    lanInterface = "wlp0s20f3";
    profiles.be247-udp = ./nordvpn/be247.nordvpn.com.udp_2.6.ovpn;
    activeProfile = "be247-udp";
  };

  homeServer = {
    wifi = {
      ssidVariable = "RED_WIFI_SSID";
      pskVariable = "RED_WIFI_PSK";
      interface = "wlp0s20f3";
      ipv4 = {
        method = "manual";
        address = "10.0.0.19/24";
        gateway = "10.0.0.1";
      };
    };
    firewall = {
      extraInputRules = [
        "udp dport 67 accept"
        "tcp dport 80 ip saddr $private_v4 accept"
      ];
      extraForwardRules = [
        "iifname \"podman*\" accept"
        "oifname \"podman*\" accept"
        "iifname \"cni-podman0\" accept"
        "oifname \"cni-podman0\" accept"
        "iifname \"wlp0s20f3\" oifname \"tun-nord\" ip saddr 10.0.0.0/24 accept"
        "iifname \"wlp0s20f3\" oifname \"wlp0s20f3\" ip saddr 10.0.0.0/24 ip daddr != 10.0.0.0/8 ip daddr != 172.16.0.0/12 ip daddr != 192.168.0.0/16 accept"
      ];
      extraNatRules = [
        "oifname \"tun-nord\" ip saddr 10.0.0.0/24 masquerade"
        "oifname \"wlp0s20f3\" ip saddr 10.0.0.0/24 masquerade"
      ];
    };
  };
}
