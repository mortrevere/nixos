{
  config,
  lib,
  ...
}:

let
  cfg = config.nordvpnGateway;
  profileExists = builtins.hasAttr cfg.activeProfile cfg.profiles;
  selectedProfile = if profileExists then cfg.profiles.${cfg.activeProfile} else null;
  sourceConfig = if selectedProfile != null then builtins.readFile selectedProfile else "";
  hasTunDevice = lib.hasInfix "dev tun\n" sourceConfig;
  hasInteractiveAuth = lib.hasInfix "auth-user-pass\n" sourceConfig;
  effectiveConfig = builtins.replaceStrings [
    "dev tun\n"
    "auth-user-pass\n"
  ] [
    "dev tun-nord\n"
    "auth-user-pass ${cfg.credentialsFile}\n"
  ] sourceConfig;
in
{
  options.nordvpnGateway = {
    enable = lib.mkEnableOption "NordVPN as a fail-open IPv4 gateway";

    lanInterface = lib.mkOption {
      type = lib.types.str;
      description = "LAN interface which receives traffic to forward through NordVPN.";
    };

    credentialsFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/nixos/secrets/nordvpn.auth";
      description = "Two-line OpenVPN service-credential file, containing username then password.";
    };

    profiles = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = { };
      description = "Named NordVPN OpenVPN profiles available for selection.";
    };

    activeProfile = lib.mkOption {
      type = lib.types.str;
      description = "Name of the NordVPN OpenVPN profile to activate.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = profileExists;
        message = "nordvpnGateway.activeProfile must name an entry in nordvpnGateway.profiles";
      }
      {
        assertion = hasTunDevice;
        message = "The selected NordVPN profile must contain a 'dev tun' directive";
      }
      {
        assertion = hasInteractiveAuth;
        message = "The selected NordVPN profile must contain a bare 'auth-user-pass' directive";
      }
    ];

    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv4.conf.all.send_redirects" = 0;
      "net.ipv4.conf.default.send_redirects" = 0;
      "net.ipv4.conf.${cfg.lanInterface}.send_redirects" = 0;
      "net.ipv4.conf.all.accept_redirects" = 0;
      "net.ipv4.conf.default.accept_redirects" = 0;
    };

    services.openvpn.servers.nordvpn = {
      autoStart = true;
      config = effectiveConfig;
    };

    systemd.services.openvpn-nordvpn.unitConfig.ConditionPathExists = cfg.credentialsFile;
  };
}
