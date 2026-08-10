{
  config,
  lib,
  pkgs,
  username,
  ...
}:

let
  homeLan = import ./home-lan.nix;
  nginxErrorPages = import ./nginx-error-pages.nix;
  reverseProxyCfg = config.homeServer.reverseProxy;
  certDir = "/opt/certs/${homeLan.domain}";
  certSyncRoot = "/var/lib/house-leo-surf-cert-sync";
  certSyncIncoming = "${certSyncRoot}/incoming";

  certSyncInstall = pkgs.writeShellScript "house-leo-surf-cert-sync-install" ''
    set -euo pipefail

    incoming=${certSyncIncoming}
    fullchain="$incoming/fullchain.pem"
    privkey="$incoming/privkey.pem"

    [ -f "$fullchain" ]
    [ -f "$privkey" ]

    ${pkgs.openssl}/bin/openssl x509 -in "$fullchain" -noout -checkend 0
    ${pkgs.openssl}/bin/openssl pkey -in "$privkey" -noout

    certificate_public_key="$(
      ${pkgs.openssl}/bin/openssl x509 -in "$fullchain" -pubkey -noout |
        ${pkgs.openssl}/bin/openssl pkey -pubin -outform DER |
        ${pkgs.coreutils}/bin/sha256sum
    )"
    private_public_key="$(
      ${pkgs.openssl}/bin/openssl pkey -in "$privkey" -pubout -outform DER |
        ${pkgs.coreutils}/bin/sha256sum
    )"
    [ "$certificate_public_key" = "$private_public_key" ]

    install -d -m 0755 ${certDir}
    install -m 0644 "$fullchain" ${certDir}/fullchain.pem
    install -m 0600 "$privkey" ${certDir}/privkey.pem
    rm -f "$incoming/fullchain.pem" "$incoming/privkey.pem" "$incoming/complete"

    ${pkgs.systemd}/bin/systemctl try-reload-or-restart podman-reverse-proxy.service
  '';
in
{
  imports = [
    ./features/autobackup.nix
    ./features/backlight.nix
    ./features/home-dns.nix
    ./features/home-server.nix
    ./features/iris-notify.nix
    ./features/public-ip-metrics.nix
  ];

  options.homeServer.reverseProxy = {
    nginxConfig = lib.mkOption {
      type = lib.types.path;
      default = pkgs.writeText "reverse-proxy-nginx.conf" ''
        events {}

        http {
          server {
            listen 80 default_server;
            ${nginxErrorPages.serverSnippet}
            return 404;
          }
        }
      '';
      description = "nginx.conf used by the always-on server reverse-proxy container.";
    };

    after = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Systemd units the reverse proxy should start after.";
    };

    wants = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Systemd units the reverse proxy should pull in.";
    };

    conflicts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Systemd units that conflict with the reverse proxy.";
    };
  };

  options.houseLeoSurf.certSyncPublicKey = lib.mkOption {
    type = lib.types.nullOr lib.types.singleLineStr;
    default = null;
    description = "Public half of Red's certificate-sync key, installed for the restricted cert-sync user when set.";
  };

  config = {
    services.timesyncd = {
      enable = true;
      servers = [
        "0.pool.ntp.org"
        "1.pool.ntp.org"
      ];
    };

    services.logind.settings.Login = {
      HandleLidSwitch = "ignore";
      HandleLidSwitchExternalPower = "ignore";
      HandleLidSwitchDocked = "ignore";
    };

    virtualisation.oci-containers.backend = lib.mkDefault "podman";

    homeServer.irisNotify.serviceNames =
      [ "podman-reverse-proxy" ]
      ++ lib.optionals (config.houseLeoSurf.certSyncPublicKey != null) [
        "house-leo-surf-cert-sync-install"
      ];

    virtualisation.oci-containers.containers.reverse-proxy = {
      image = "docker.io/library/nginx:1.27-alpine";
      volumes = [
        "/var/lib/reverse-proxy/nginx.conf:/etc/nginx/nginx.conf:ro"
        "${certDir}:/etc/house.leo.surf:ro"
      ];
      extraOptions = [
        "--network=host"
      ];
    };

    systemd.tmpfiles.rules = [
      "d /opt/certs 0755 root root -"
      "d ${certDir} 0755 root root -"
      "d /var/lib/reverse-proxy 0755 root root -"
    ] ++ lib.optionals (config.houseLeoSurf.certSyncPublicKey != null) [
      "d ${certSyncRoot} 0755 root root -"
      "d ${certSyncIncoming} 0700 cert-sync cert-sync -"
    ];

    systemd.services.podman-reverse-proxy = {
      inherit (reverseProxyCfg) after;
      inherit (reverseProxyCfg) wants;
      inherit (reverseProxyCfg) conflicts;
      restartTriggers = [
        reverseProxyCfg.nginxConfig
      ];
      preStart = ''
        install -d -m 0755 ${certDir}
        if [ ! -s ${certDir}/privkey.pem ]; then
          ${pkgs.openssl}/bin/openssl req -x509 -newkey rsa:2048 -nodes \
            -keyout ${certDir}/privkey.pem \
            -out ${certDir}/fullchain.pem \
            -days 7 \
            -subj "/CN=${homeLan.domain}" \
            -addext "subjectAltName=DNS:${homeLan.domain},DNS:*.${homeLan.domain}"
          chmod 0600 ${certDir}/privkey.pem
          chmod 0644 ${certDir}/fullchain.pem
        fi
        install -d -m 0755 /var/lib/reverse-proxy
        install -m 0644 ${reverseProxyCfg.nginxConfig} /var/lib/reverse-proxy/nginx.conf
      '';
    };

    users.users.${username} = {
      extraGroups = [
        "users"
      ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINtZ7X63RfDOWIi9q33xeoOOpKKjQMVN/uw5oYdeBQXx leo@MaitreYoga"
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDdwLcy4I1WBVCqTrhku3uVQ/bbXoatNuOm0k4rlctABC4mSACLvuIMIdXKUXdNisOgJ9FDUvL+jK3Jks9gi1AeDL0mP3cCBWu951pkI3j13SW78rKG5qUHfXbmiV2KfxTaVmLDXQTh2cy0+AJ7iuQIvglm5vSRmLSTg81UzxlEElb+wRiIwBPgMqD0yWb7HuRngBkQLS0ioydxOE9NQ4k/chCcLee5d1MEtHN9K28P6UdGqJcxKnrGyCoOiJygdBfHaYhjHyMYpV1hWNKY8vxODrd4Ja8iKXV1tdya1bNAt6eEyeIFDpRU8VunT+XL7YNzTcQdurGGnAwf7CENlWYh mortrevere@leo-vaio"
      ];
    };

    users.groups.cert-sync = lib.mkIf (config.houseLeoSurf.certSyncPublicKey != null) { };

    users.users.cert-sync = lib.mkIf (config.houseLeoSurf.certSyncPublicKey != null) {
      isSystemUser = true;
      group = "cert-sync";
      home = certSyncRoot;
      createHome = false;
      openssh.authorizedKeys.keys = [ config.houseLeoSurf.certSyncPublicKey ];
    };

    services.openssh.extraConfig = lib.mkIf (config.houseLeoSurf.certSyncPublicKey != null) ''
      Match User cert-sync
        ChrootDirectory ${certSyncRoot}
        ForceCommand internal-sftp -d /incoming
        PasswordAuthentication no
        KbdInteractiveAuthentication no
        PermitTTY no
        AllowTcpForwarding no
        X11Forwarding no
        PermitTunnel no
        GatewayPorts no
    '';

    systemd.services.house-leo-surf-cert-sync-install = lib.mkIf (
      config.houseLeoSurf.certSyncPublicKey != null
    ) {
      description = "Install a certificate staged by the restricted cert-sync user";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = certSyncInstall;
      };
    };

    systemd.paths.house-leo-surf-cert-sync-install = lib.mkIf (
      config.houseLeoSurf.certSyncPublicKey != null
    ) {
      wantedBy = [ "multi-user.target" ];
      pathConfig = {
        PathExists = "${certSyncIncoming}/complete";
        Unit = "house-leo-surf-cert-sync-install.service";
      };
    };

    environment.systemPackages = with pkgs; [
      tmux
    ];
  };
}
