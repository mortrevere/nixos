{ pkgs, ... }:

let
  jellyfinTranscodeTmpfsSize = "4G";

  reverseProxyNginxConf = pkgs.writeText "reverse-proxy-nginx.conf" ''
    events {}

    http {
      include /etc/nginx/mime.types;
      default_type application/octet-stream;

      map $http_upgrade $connection_upgrade {
        default upgrade;
        "" close;
      }

      server {
        listen 80;
        server_name transmission.house;

        location / {
          proxy_pass http://127.0.0.1:9091;
          proxy_http_version 1.1;
          proxy_set_header Host $host;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Port 80;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection $connection_upgrade;
          proxy_read_timeout 300s;
          proxy_buffering off;
        }
      }

      server {
        listen 80;
        server_name cinema.house;

        location / {
          proxy_pass http://127.0.0.1:8096;
          proxy_http_version 1.1;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Port 80;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection $connection_upgrade;
          proxy_read_timeout 300s;
          proxy_buffering off;
        }
      }

      server {
        listen 80;
        server_name blue.files.house;
        client_max_body_size 0;

        location / {
          proxy_pass http://127.0.0.1:8089;
          proxy_http_version 1.1;
          proxy_set_header Host $host;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Port 80;
          proxy_read_timeout 300s;
          proxy_buffering off;
        }
      }
    }
  '';

  jellyfinElegantFinCss = ''
    @import url("https://cdn.jsdelivr.net/gh/lscambo13/ElegantFin@main/Theme/ElegantFin-jellyfin-theme-build-latest-minified.css");
  '';

  jellyfinBranding = pkgs.writeText "jellyfin-branding.xml" ''
    <?xml version="1.0" encoding="utf-8"?>
    <BrandingOptions xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
      <LoginDisclaimer />
      <CustomCss>${jellyfinElegantFinCss}</CustomCss>
      <SplashscreenEnabled>false</SplashscreenEnabled>
    </BrandingOptions>
  '';

  jellyfinBootstrap = pkgs.writeShellScript "jellyfin-bootstrap" ''
    set -euo pipefail

    system_xml=/opt/jellyfin/config/system.xml
    if [ -f "$system_xml" ] && ${pkgs.gnugrep}/bin/grep -q '<IsStartupWizardCompleted>true</IsStartupWizardCompleted>' "$system_xml"; then
      exit 0
    fi

    if [ -z "''${JELLYFIN_ADMIN_USER:-}" ] || [ -z "''${JELLYFIN_ADMIN_PASSWORD:-}" ]; then
      echo "JELLYFIN_ADMIN_USER and JELLYFIN_ADMIN_PASSWORD must be set"
      exit 1
    fi

    base_url=http://127.0.0.1:8096

    startup_complete=false
    for _ in $(${pkgs.coreutils}/bin/seq 1 60); do
      info="$(${pkgs.curl}/bin/curl --fail --silent "$base_url/System/Info/Public" 2>/dev/null || true)"
      if [ -n "$info" ]; then
        startup_complete="$(printf '%s' "$info" | ${pkgs.jq}/bin/jq -r '.StartupWizardCompleted')"
        break
      fi
      ${pkgs.coreutils}/bin/sleep 2
    done

    if [ "$startup_complete" = true ]; then
      exit 0
    fi

    config_json=
    for _ in $(${pkgs.coreutils}/bin/seq 1 60); do
      config_json="$(${pkgs.curl}/bin/curl --fail --silent "$base_url/Startup/Configuration" 2>/dev/null || true)"
      if [ -n "$config_json" ]; then
        break
      fi
      ${pkgs.coreutils}/bin/sleep 2
    done

    ${pkgs.curl}/bin/curl --fail --silent --show-error \
      --header 'Content-Type: application/json' \
      --data "$(printf '%s' "$config_json" | ${pkgs.jq}/bin/jq '.ServerName = "blue" | .UICulture = "fr-FR" | .MetadataCountryCode = "FR" | .PreferredMetadataLanguage = "fr"')" \
      "$base_url/Startup/Configuration" >/dev/null

    ${pkgs.curl}/bin/curl --fail --silent --show-error \
      --header 'Content-Type: application/json' \
      --data "$(${pkgs.jq}/bin/jq -n --arg name "$JELLYFIN_ADMIN_USER" --arg password "$JELLYFIN_ADMIN_PASSWORD" '{Name: $name, Password: $password}')" \
      "$base_url/Startup/User" >/dev/null

    ${pkgs.curl}/bin/curl --fail --silent --show-error \
      --header 'Content-Type: application/json' \
      --data '{"EnableRemoteAccess":true}' \
      "$base_url/Startup/RemoteAccess" >/dev/null

    ${pkgs.curl}/bin/curl --fail --silent --show-error \
      --request POST \
      "$base_url/Startup/Complete" >/dev/null
  '';
in
{
  virtualisation.oci-containers.backend = "podman";

  systemd.tmpfiles.rules = [
    "d /opt/transmission 0755 root root -"
    "d /opt/transmission/config 0755 1000 100 -"
    "d /opt/transmission/downloads 0755 1000 100 -"
    "d /opt/transmission/watch 0755 1000 100 -"
    "d /opt/jellyfin 0755 root root -"
    "d /opt/jellyfin/config 0755 1000 100 -"
    "d /opt/jellyfin/transcodes 0770 1000 100 -"
    "C+ /opt/jellyfin/config/branding.xml 0644 1000 100 - ${jellyfinBranding}"
    "d /opt/others 0755 root root -"
    "d /opt/filebrowser 0755 root root -"
    "d /opt/filebrowser/config 0750 1000 100 -"
    "d /opt/filebrowser/database 0750 1000 100 -"
    "L+ /opt/jellyfin/media - - - - /opt/transmission/downloads"
  ];

  fileSystems."/opt/jellyfin/transcodes" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "rw"
      "nosuid"
      "nodev"
      "noatime"
      "mode=0770"
      "uid=1000"
      "gid=100"
      "size=${jellyfinTranscodeTmpfsSize}"
    ];
  };

  homeServer.reverseProxy = {
    nginxConfig = reverseProxyNginxConf;
    after = [
      "podman-transmission.service"
      "podman-jellyfin.service"
      "podman-filebrowser.service"
    ];
    wants = [
      "podman-transmission.service"
      "podman-jellyfin.service"
      "podman-filebrowser.service"
    ];
  };

  virtualisation.oci-containers.containers = {
    transmission = {
      image = "lscr.io/linuxserver/transmission:4.0.6";
      environment = {
        PUID = "1000";
        PGID = "100";
        TZ = "Europe/Paris";
      };
      volumes = [
        "/opt/transmission/config:/config"
        "/opt/transmission/downloads:/downloads"
        "/opt/transmission/watch:/watch"
      ];
      extraOptions = [
        "--publish=127.0.0.1:9091:9091"
        "--publish=51413:51413"
        "--publish=51413:51413/udp"
      ];
    };

    jellyfin = {
      image = "lscr.io/linuxserver/jellyfin:10.11.11ubu2404-ls41";
      environment = {
        PUID = "1000";
        PGID = "100";
        TZ = "Europe/Paris";
        JELLYFIN_PublishedServerUrl = "http://cinema.house";
      };
      volumes = [
        "/opt/jellyfin/config:/config"
        "/opt/jellyfin/transcodes:/config/transcodes"
        "/opt/jellyfin/transcodes:/config/cache/transcodes"
        "/opt/jellyfin/media:/data/media:ro"
        "/opt/others:/data/others:ro"
        "/data/Extreme_SSD/archives/films:/media/extreme-ssd-films:ro"
        "/data/Extreme_SSD/archives/series:/media/extreme-ssd-series:ro"
      ];
      extraOptions = [
        "--publish=127.0.0.1:8096:8096"
        "--device=/dev/dri:/dev/dri"
      ];
    };

    filebrowser = {
      image = "docker.io/filebrowser/filebrowser:latest";
      cmd = [
        "--address=0.0.0.0"
        "--port=8080"
        "--root=/srv"
        "--database=/database/filebrowser.db"
        "--config=/config/settings.json"
        "--noauth"
      ];
      volumes = [
        "/data:/srv"
        "/opt/filebrowser/config:/config"
        "/opt/filebrowser/database:/database"
      ];
      extraOptions = [
        "--no-healthcheck"
        "--publish=127.0.0.1:8089:8080"
      ];
    };

  };

  systemd.services = {
    podman-jellyfin = {
      after = [ "mount-data-drives.service" ];
      wants = [ "mount-data-drives.service" ];
    };

    podman-filebrowser = {
      after = [ "mount-data-drives.service" ];
      wants = [ "mount-data-drives.service" ];
    };
  };

  environment.systemPackages = with pkgs; [
    podman-compose
  ];

  system.activationScripts.restartBlueContainers.text = ''
    if [ "''${NIXOS_ACTION:-}" = switch ] && [ -d /run/systemd/system ]; then
      for service in transmission jellyfin filebrowser; do
        if ${pkgs.systemd}/bin/systemctl --quiet is-active "podman-$service.service"; then
          ${pkgs.systemd}/bin/systemctl restart "podman-$service.service"
        fi
      done
    fi
  '';

  systemd.services.jellyfin-bootstrap = {
    description = "Bootstrap Jellyfin admin user";
    after = [ "podman-jellyfin.service" ];
    wants = [ "podman-jellyfin.service" ];
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = "/etc/nixos/secrets/blue.env";
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = "/etc/nixos/secrets/blue.env";
      ExecStart = jellyfinBootstrap;
      TimeoutStartSec = "30s";
    };
  };
}
