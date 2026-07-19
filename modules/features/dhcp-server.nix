let
  cfg = config.homeLanDhcp;

  reservations = [
    "12:F3:6C:0C:F6:78,10.0.0.11,iPhone,infinite"
    "5C:51:4F:CA:D1:A4,10.0.0.29,black,infinite"
    "30:24:32:1E:FD:F2,10.0.0.15,infinite"
    "28:6B:35:89:83:89,10.0.0.33,Miaou,infinite"
    "DC:A6:32:D2:93:D0,10.0.0.100,infinite"
    "C4:23:60:F9:EF:84,10.0.0.32,infinite"
    "EC:B5:FA:9A:C5:F1,10.0.0.10,hue-bridge,infinite"
    "98:59:7A:5B:86:E1,10.0.0.19,red,infinite"
    "9C:B6:D0:8E:09:6D,10.0.0.30,blue,infinite"
  ];
in
{
  config,
  lib,
  ...
}:

{
  options.homeLanDhcp = {
    enable = lib.mkEnableOption "the home LAN DHCP server";

    interface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Interface on which to serve DHCP; null serves on all interfaces.";
    };

    router = lib.mkOption {
      type = lib.types.str;
      default = "10.0.0.1";
      description = "IPv4 default gateway advertised to DHCP clients.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.dnsmasq = {
      enable = true;
      resolveLocalQueries = false;
      settings = {
        # DHCP only: CoreDNS already owns port 53 on red.
        port = 0;
        dhcp-authoritative = true;
        dhcp-range = [ "10.0.0.10,10.0.0.254,255.255.255.0,12h" ];
        dhcp-option = [
          "option:router,${cfg.router}"
          "option:dns-server,10.0.0.19,10.0.0.30,10.0.0.29"
        ];
        dhcp-host = reservations;
      } // lib.optionalAttrs (cfg.interface != null) {
        interface = cfg.interface;
        bind-interfaces = true;
      };
    };
  };
}
