{
  config,
  lib,
  pkgs,
  username,
  ...
}:

let
  reverseProxyCfg = config.homeServer.reverseProxy;
in
{
  imports = [
    ./features/autobackup.nix
    ./features/home-dns.nix
    ./features/home-server.nix
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

    virtualisation.containers.registries.insecure = [
      "docker.house:80"
    ];

    virtualisation.oci-containers.backend = lib.mkDefault "podman";

    virtualisation.oci-containers.containers.reverse-proxy = {
      image = "docker.io/library/nginx:1.27-alpine";
      volumes = [
        "/var/lib/reverse-proxy/nginx.conf:/etc/nginx/nginx.conf:ro"
      ];
      extraOptions = [
        "--network=host"
      ];
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/reverse-proxy 0755 root root -"
    ];

    systemd.services.podman-reverse-proxy = {
      inherit (reverseProxyCfg) after;
      inherit (reverseProxyCfg) wants;
      inherit (reverseProxyCfg) conflicts;
      restartTriggers = [
        reverseProxyCfg.nginxConfig
      ];
      preStart = ''
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

    environment.systemPackages = with pkgs; [
      rsync
      tmux
    ];
  };
}
