{ lib, pkgs, ... }:

let
  homeLan = import ../../modules/home-lan.nix;
  nginxErrorPages = import ../../modules/nginx-error-pages.nix;
  linksCorsProbes = import ../../modules/links-cors-probes.nix;

  yaml = pkgs.formats.yaml { };

  grafanaImageTag = builtins.head (lib.splitString "+" pkgs.grafana.version);
  heimdallImage = "docker.house.leo.surf/heimdall:latest";
  hyperionImage = "docker.house.leo.surf/hyperion:latest";
  irisImage = "docker.house.leo.surf/iris:latest";
  janusImage = "docker.house.leo.surf/janus:latest";
  linksImage = "docker.house.leo.surf/links:latest";
  nabuImage = "docker.house.leo.surf/nabu:latest";
  certMount = "/etc/house.leo.surf";

  tlsConfig = ''
    listen 443 ssl;
    ssl_certificate ${certMount}/fullchain.pem;
    ssl_certificate_key ${certMount}/privkey.pem;
  '';

  janusAuthRequestLocation = ''
    location = /_janus_validate {
      internal;
      proxy_pass https://janus.house.leo.surf/auth/validate?app_name=$host&identity=$remote_addr;
      proxy_pass_request_body off;
      proxy_set_header Content-Length "";
      proxy_set_header Host janus.house.leo.surf;
      proxy_ssl_server_name on;
    }
  '';

  vpnProtectedLocation = proxyConfig: ''
    location / {
      error_page 418 = @janus_auth;
      if ($janus_vpn_client) {
        return 418;
      }
      ${proxyConfig}
    }

    location @janus_auth {
      internal;
      recursive_error_pages on;
      error_page 403 = @house_error_403;
      auth_request /_janus_validate;
      ${proxyConfig}
    }

    ${janusAuthRequestLocation}
  '';

  houseNodeTargets =
    (map (name: {
      targets = [
        "${name}.${homeLan.domain}:9100"
      ];
      labels.node = name;
    }) homeLan.nodeNames)
    ++ [
      {
        targets = [
          "10.0.0.100:9100"
        ];
        labels.node = "raspberrypi";
      }
    ];

  webNodeTargets = [
    {
      targets = [
        "100.64.88.1:9100"
      ];
      labels.node = "vps-prod";
    }
  ];

  prometheusConfig = yaml.generate "prometheus.yml" {
    scrape_configs = [
      {
        job_name = "house";
        static_configs = houseNodeTargets;
      }
      {
        job_name = "web";
        static_configs = webNodeTargets;
      }
    ];
  };

  grafanaConfig = pkgs.writeText "grafana.ini" ''
    [server]
    http_addr = 127.0.0.1
    http_port = 3001
    domain = grafana.house.leo.surf
    root_url = https://grafana.house.leo.surf/

    [security]
    admin_user = $__env{GRAFANA_ADMIN_USER}
    admin_password = $__env{GRAFANA_ADMIN_PASSWORD}

    [analytics]
    reporting_enabled = false
  '';

  grafanaDashboardJson = pkgs.writeText "home-lab-overview.json" (
    builtins.readFile ./dashboards/home-lab-overview.json
  );

  grafanaDatasourceConfig = yaml.generate "datasources.yml" {
    apiVersion = 1;
    datasources = [
      {
        name = "Prometheus";
        type = "prometheus";
        access = "proxy";
        url = "http://127.0.0.1:9090";
        isDefault = true;
      }
    ];
  };

  grafanaDashboardConfig = yaml.generate "dashboards.yml" {
    apiVersion = 1;
    providers = [
      {
        name = "home-lab";
        orgId = 1;
        folder = "";
        type = "file";
        allowUiUpdates = true;
        disableDeletion = false;
        editable = true;
        options.path = "/var/lib/grafana/dashboards";
      }
    ];
  };

  grafanaDashboards = pkgs.runCommand "grafana-dashboards" { } ''
    mkdir -p $out
    cp ${grafanaDashboardJson} $out/home-lab-overview.json
  '';

  grafanaDashboardPayload = pkgs.runCommand "grafana-dashboard-payload.json" { } ''
    ${pkgs.jq}/bin/jq -n \
      --slurpfile dashboard ${grafanaDashboardJson} \
      '{
        dashboard: ($dashboard[0] + { id: null }),
        overwrite: true,
        message: "reconcile from nix"
      }' > $out
  '';

  grafanaProvisioning = pkgs.runCommand "grafana-provisioning" { } ''
    mkdir -p $out/dashboards $out/datasources
    cp ${grafanaDashboardConfig} $out/dashboards/dashboards.yml
    cp ${grafanaDatasourceConfig} $out/datasources/datasources.yml
  '';

  reverseProxyNginxConf = pkgs.writeText "reverse-proxy-nginx.conf" ''
    events {}

    http {
      include /etc/nginx/mime.types;
      default_type application/octet-stream;
      access_log /dev/stdout combined;
      resolver 127.0.0.1 ipv6=off valid=30s;
      ${linksCorsProbes.headers}
      ${linksCorsProbes.methodMap}
      ${linksCorsProbes.hideUpstreamHeaders}

      map $http_upgrade $connection_upgrade {
        default upgrade;
        "" close;
      }

      geo $janus_vpn_client {
        default 0;
        ${homeLan.vpnClientCidr} 1;
      }

      server {
        listen 80 default_server;
        server_name _;
        ${nginxErrorPages.serverSnippet}
        return 404;
      }

      server {
        listen 80;
        server_name
          grafana.house.leo.surf
          git.house.leo.surf
          heimdall.house.leo.surf
          links.house.leo.surf
          hyperion.house.leo.surf
          iris.house.leo.surf
          janus.house.leo.surf
          nabu.house.leo.surf
          prometheus.house.leo.surf
          red-files.house.leo.surf;
        return 301 https://$host$request_uri;
      }

      server {
        listen 443 ssl default_server;
        server_name _;
        ssl_certificate ${certMount}/fullchain.pem;
        ssl_certificate_key ${certMount}/privkey.pem;
        ${nginxErrorPages.serverSnippet}
        return 404;
      }

      server {
        ${tlsConfig}
        server_name grafana.house.leo.surf;
        ${nginxErrorPages.serverSnippet}

        ${vpnProtectedLocation ''
          proxy_pass http://127.0.0.1:3001;
          ${linksCorsProbes.proxyMethod}
          proxy_http_version 1.1;
          proxy_set_header Host $host;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Port 443;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection $connection_upgrade;
          proxy_read_timeout 300s;
          proxy_buffering off;
        ''}
      }

      server {
        ${tlsConfig}
        server_name git.house.leo.surf;
        ${nginxErrorPages.serverSnippet}
        client_max_body_size 50m;

        ${vpnProtectedLocation ''
          proxy_pass http://127.0.0.1:3002;
          ${linksCorsProbes.proxyMethod}
          proxy_http_version 1.1;
          proxy_set_header Host $host;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Port 443;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection $connection_upgrade;
          proxy_read_timeout 300s;
          proxy_buffering off;
        ''}
      }

      server {
        ${tlsConfig}
        server_name links.house.leo.surf;
        ${nginxErrorPages.serverSnippet}

        ${vpnProtectedLocation ''
          proxy_pass http://127.0.0.1:8088;
          ${linksCorsProbes.proxyMethod}
          proxy_http_version 1.1;
          proxy_set_header Host $host;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Port 443;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection $connection_upgrade;
          proxy_read_timeout 300s;
          proxy_buffering off;
        ''}
      }

      server {
        ${tlsConfig}
        server_name hyperion.house.leo.surf;
        ${nginxErrorPages.serverSnippet}

        ${vpnProtectedLocation ''
          proxy_pass http://127.0.0.1:8090;
          ${linksCorsProbes.proxyMethod}
          proxy_http_version 1.1;
          proxy_set_header Host $host;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Port 443;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection $connection_upgrade;
          proxy_read_timeout 300s;
          proxy_buffering off;
        ''}
      }

      server {
        ${tlsConfig}
        server_name heimdall.house.leo.surf;
        ${nginxErrorPages.serverSnippet}

        ${vpnProtectedLocation ''
          proxy_pass http://127.0.0.1:8093;
          ${linksCorsProbes.proxyMethod}
          proxy_http_version 1.1;
          proxy_set_header Host $host;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Port 443;
        ''}
      }

      server {
        ${tlsConfig}
        server_name nabu.house.leo.surf;
        ${nginxErrorPages.serverSnippet}

        ${vpnProtectedLocation ''
          proxy_pass http://127.0.0.1:8091;
          ${linksCorsProbes.proxyMethod}
          proxy_http_version 1.1;
          proxy_set_header Host $host;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Port 443;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection $connection_upgrade;
          proxy_read_timeout 300s;
          proxy_buffering off;
        ''}
      }

      server {
        ${tlsConfig}
        server_name iris.house.leo.surf;
        ${nginxErrorPages.serverSnippet}

        ${vpnProtectedLocation ''
          proxy_pass http://127.0.0.1:8092;
          ${linksCorsProbes.proxyMethod}
          proxy_http_version 1.1;
          proxy_set_header Host $host;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Port 443;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection $connection_upgrade;
          proxy_read_timeout 300s;
          proxy_buffering off;
        ''}
      }

      server {
        ${tlsConfig}
        server_name janus.house.leo.surf;
        ${nginxErrorPages.serverSnippet}

        location / {
          proxy_pass http://127.0.0.1:8094;
          ${linksCorsProbes.proxyMethod}
          proxy_http_version 1.1;
          proxy_set_header Host $host;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Port 443;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection $connection_upgrade;
          proxy_read_timeout 300s;
          proxy_buffering off;
        }
      }

      server {
        ${tlsConfig}
        server_name prometheus.house.leo.surf;
        ${nginxErrorPages.serverSnippet}

        ${vpnProtectedLocation ''
          proxy_pass http://127.0.0.1:9090;
          ${linksCorsProbes.proxyMethod}
          proxy_http_version 1.1;
          proxy_set_header Host $host;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Port 443;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection $connection_upgrade;
          proxy_read_timeout 300s;
          proxy_buffering off;
        ''}
      }

      server {
        ${tlsConfig}
        server_name red-files.house.leo.surf;
        ${nginxErrorPages.serverSnippet}
        client_max_body_size 0;

        ${vpnProtectedLocation ''
          proxy_pass http://127.0.0.1:8089;
          ${linksCorsProbes.proxyMethod}
          proxy_http_version 1.1;
          proxy_set_header Host $host;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Port 443;
          proxy_read_timeout 300s;
          proxy_buffering off;
        ''}
      }
    }
  '';

in
{
  virtualisation.oci-containers.backend = "podman";

  homeServer.irisNotify.serviceNames = [
    "podman-grafana"
    "grafana-dashboard-reconcile"
    "podman-heimdall"
    "podman-forgejo"
    "podman-hyperion"
    "podman-iris"
    "podman-janus"
    "podman-nabu"
    "podman-links"
    "podman-prometheus"
    "podman-filebrowser"
  ];

  systemd.tmpfiles.rules = [
    "d /opt/grafana 0755 root root -"
    "d /opt/grafana/data 0750 472 472 -"
    "d /opt/heimdall 0755 root root -"
    "d /opt/hyperion 0755 root root -"
    "d /opt/iris 0755 root root -"
    "d /opt/janus 0755 root root -"
    "d /opt/nabu 0755 root root -"
    "d /opt/prometheus 0755 root root -"
    "d /opt/prometheus/data 0750 65534 65534 -"
    "d /opt/filebrowser 0755 root root -"
    "d /opt/filebrowser/config 0750 1000 100 -"
    "d /opt/filebrowser/database 0750 1000 100 -"
    "d /opt/forgejo 0755 1000 1000 -"
  ];

  homeServer.reverseProxy = {
    nginxConfig = reverseProxyNginxConf;
    after = [
      "grafana-dashboard-reconcile.service"
      "podman-heimdall.service"
      "podman-hyperion.service"
      "podman-iris.service"
      "podman-janus.service"
      "podman-nabu.service"
      "podman-links.service"
      "podman-forgejo.service"
      "podman-grafana.service"
      "podman-prometheus.service"
      "podman-filebrowser.service"
    ];
    wants = [
      "grafana-dashboard-reconcile.service"
      "podman-heimdall.service"
      "podman-hyperion.service"
      "podman-iris.service"
      "podman-janus.service"
      "podman-nabu.service"
      "podman-links.service"
      "podman-forgejo.service"
      "podman-grafana.service"
      "podman-prometheus.service"
      "podman-filebrowser.service"
    ];
  };

  virtualisation.oci-containers.containers = {
    grafana = {
      image = "docker.io/grafana/grafana:${grafanaImageTag}";
      environmentFiles = [
        "/etc/nixos/secrets/red.env"
      ];
      environment = {
        GF_PATHS_PROVISIONING = "/var/lib/grafana/provisioning";
        GF_LOG_LEVEL = "warn";
      };
      volumes = [
        "/opt/grafana/data:/var/lib/grafana"
        "${grafanaConfig}:/etc/grafana/grafana.ini:ro"
        "${grafanaProvisioning}:/var/lib/grafana/provisioning:ro"
        "${grafanaDashboards}:/var/lib/grafana/dashboards:ro"
      ];
      extraOptions = [
        "--network=host"
      ];
    };

    links = {
      image = linksImage;
      environment = {
        HOST = "127.0.0.1";
        PORT = "8088";
        BLUE_ADDRESS = homeLan.addresses.blue;
        BLACK_ADDRESS = homeLan.addresses.black;
      };
      extraOptions = [
        "--network=host"
      ];
    };

    forgejo = {
      image = "codeberg.org/forgejo/forgejo:16";
      cmd = [
        "/bin/bash"
        "-c"
        ''
          cd /etc/s6/gitea
          source ./setup
          cd /app/gitea
          exec su-exec "$USER" /usr/local/bin/gitea web
        ''
      ];
      environment = {
        USER_UID = "1000";
        USER_GID = "1000";
        FORGEJO__server__DOMAIN = "git.house.leo.surf";
        FORGEJO__server__ROOT_URL = "https://git.house.leo.surf/";
        FORGEJO__server__HTTP_ADDR = "127.0.0.1";
        FORGEJO__server__HTTP_PORT = "3002";
        FORGEJO__server__DISABLE_SSH = "true";
        FORGEJO__log__LEVEL = "warn";
      };
      volumes = [
        "/opt/forgejo:/data"
      ];
      extraOptions = [
        "--network=host"
      ];
    };

    hyperion = {
      image = hyperionImage;
      environmentFiles = [
        "/etc/nixos/secrets/red.env"
      ];
      environment = {
        HOST = "127.0.0.1";
        PORT = "8090";
      };
      volumes = [
        "/opt/hyperion:/opt/hyperion"
      ];
      extraOptions = [
        "--network=host"
      ];
    };

    heimdall = {
      image = heimdallImage;
      environment = {
        HOST = "127.0.0.1";
        PORT = "8093";
        CIDR = "10.0.0.0/24";
        VPN_CIDR = "100.64.88.0/24";
        VPN_BANDWIDTH_COMMAND = "ssh -i /run/secrets/heimdall_vps_ed25519 -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/opt/heimdall/vps_known_hosts debian@91.134.140.52 sudo wg show wg0 dump";
        CONNTRACK_PATH = "/proc/net/nf_conntrack";
        DHCP_LEASES_PATH = "/run/heimdall/dnsmasq.leases";
        HOSTS_PATH = "/opt/heimdall/hosts.json";
        KNOWN_HOSTS = "red=10.0.0.19,blue=10.0.0.30,black=10.0.0.29";
        RETENTION_DAYS = "8";
        SCAN_INTERVAL_SECONDS = "60";
      };
      volumes = [
        "/opt/heimdall:/opt/heimdall"
        "/var/lib/dnsmasq/dnsmasq.leases:/run/heimdall/dnsmasq.leases:ro"
        "/etc/nixos/secrets/janus_vps_ed25519:/run/secrets/heimdall_vps_ed25519:ro"
      ];
      extraOptions = [
        "--network=host"
      ];
    };

    nabu = {
      image = nabuImage;
      environment = {
        HOST = "127.0.0.1";
        PORT = "8091";
        SQLITE_PATH = "/opt/nabu/nabu.sqlite3";
      };
      volumes = [
        "/opt/nabu:/opt/nabu"
      ];
      extraOptions = [
        "--network=host"
      ];
    };

    iris = {
      image = irisImage;
      environmentFiles = [
        "/run/podman-iris/ntfy-forward.env"
      ];
      environment = {
        HOST = "127.0.0.1";
        PORT = "8092";
        SQLITE_PATH = "/opt/iris/iris.sqlite3";
      };
      volumes = [
        "/opt/iris:/opt/iris"
      ];
      extraOptions = [
        "--network=host"
      ];
    };

    janus = {
      image = janusImage;
      environmentFiles = [
        "/etc/nixos/secrets/red.env"
      ];
      environment = {
        HOST = "127.0.0.1";
        PORT = "8094";
        SQLITE_PATH = "/opt/janus/janus.sqlite3";
        MNEMOSYNE_URL = "https://mnemosyne.house.leo.surf";
        IRIS_URL = "http://127.0.0.1:8092";
        VPN_CIDR = "100.64.88.0/24";
        ENDPOINT = "91.134.140.52:33333";
        INTERFACE = "wg0";
        LISTEN_PORT = "33333";
        SERVER_ADDRESS = "100.64.88.1/24";
        REMOTE_HOST = "91.134.140.52";
        REMOTE_USER = "debian";
        REMOTE_CONFIG_PATH = "/etc/wireguard/wg0.conf";
        SSH_KEY_PATH = "/run/secrets/janus_vps_ed25519";
        SSH_KNOWN_HOSTS_PATH = "/opt/janus/known_hosts";
      };
      volumes = [
        "/opt/janus:/opt/janus"
        "/etc/nixos/secrets/janus_vps_ed25519:/run/secrets/janus_vps_ed25519:ro"
      ];
      extraOptions = [
        "--network=host"
      ];
    };

    prometheus = {
      image = "docker.io/prom/prometheus:v${pkgs.prometheus.version}";
      cmd = [
        "--config.file=/etc/prometheus/prometheus.yml"
        "--storage.tsdb.path=/prometheus"
        "--storage.tsdb.retention.time=60d"
        "--storage.tsdb.min-block-duration=24h"
        "--storage.tsdb.max-block-duration=24h"
        "--web.listen-address=127.0.0.1:9090"
        "--web.external-url=https://prometheus.house.leo.surf/"
      ];
      volumes = [
        "/opt/prometheus/data:/prometheus"
        "${prometheusConfig}:/etc/prometheus/prometheus.yml:ro"
      ];
      extraOptions = [
        "--network=host"
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
        "/opt:/srv/opt"
        "/opt/filebrowser/config:/config"
        "/opt/filebrowser/database:/database"
      ];
      extraOptions = [
        "--no-healthcheck"
        "--publish=127.0.0.1:8089:8080"
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    podman-compose
  ];

  system.activationScripts.restartRedContainers.text = ''
    if [ "''${NIXOS_ACTION:-}" = switch ] && [ -d /run/systemd/system ]; then
      for service in prometheus grafana forgejo heimdall hyperion iris janus links nabu filebrowser; do
        if ${pkgs.systemd}/bin/systemctl --quiet is-active "podman-$service.service"; then
          ${pkgs.systemd}/bin/systemctl restart "podman-$service.service"
        fi
      done
    fi
  '';

  systemd.services.podman-prometheus.restartTriggers = [
    prometheusConfig
  ];

  systemd.services.podman-grafana = {
    after = [ "podman-prometheus.service" ];
    wants = [ "podman-prometheus.service" ];
    restartTriggers = [
      grafanaConfig
      grafanaDatasourceConfig
      grafanaDashboardConfig
      grafanaDashboardJson
    ];
  };

  systemd.services.grafana-dashboard-reconcile = {
    description = "Reconcile Grafana dashboards from Nix";
    after = [ "podman-grafana.service" ];
    wants = [ "podman-grafana.service" ];
    wantedBy = [ "multi-user.target" ];
    restartTriggers = [
      grafanaDashboardPayload
    ];
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = "/etc/nixos/secrets/red.env";
    };
    script = ''
      for _ in $(seq 1 60); do
        if ${pkgs.curl}/bin/curl -fsS http://127.0.0.1:3001/api/health >/dev/null; then
          break
        fi
        sleep 1
      done

      ${pkgs.curl}/bin/curl -fsS \
        --retry 10 \
        --retry-delay 1 \
        --retry-connrefused \
        -u "$GRAFANA_ADMIN_USER:$GRAFANA_ADMIN_PASSWORD" \
        -H 'Content-Type: application/json' \
        --data-binary @${grafanaDashboardPayload} \
        http://127.0.0.1:3001/api/dashboards/db >/dev/null
    '';
  };

  systemd.services.podman-hyperion = {
    after = [
      "network-online.target"
      "podman-coredns.service"
    ];
    wants = [
      "network-online.target"
      "podman-coredns.service"
    ];
    preStart = lib.mkBefore ''
      ${pkgs.podman}/bin/podman rmi -f ${hyperionImage} 2>/dev/null || true
      ${pkgs.podman}/bin/podman pull ${hyperionImage}
    '';
  };

  systemd.services.podman-heimdall = {
    after = [
      "network-online.target"
      "podman-coredns.service"
    ];
    wants = [
      "network-online.target"
      "podman-coredns.service"
    ];
    preStart = lib.mkBefore ''
      ${pkgs.podman}/bin/podman rmi -f ${heimdallImage} 2>/dev/null || true
      ${pkgs.podman}/bin/podman pull ${heimdallImage}
    '';
  };

  systemd.services.podman-nabu = {
    after = [
      "network-online.target"
      "podman-coredns.service"
    ];
    wants = [
      "network-online.target"
      "podman-coredns.service"
    ];
    preStart = lib.mkBefore ''
      ${pkgs.podman}/bin/podman rmi -f ${nabuImage} 2>/dev/null || true
      ${pkgs.podman}/bin/podman pull ${nabuImage}
    '';
  };

  systemd.services.podman-iris = {
    after = [
      "network-online.target"
      "podman-coredns.service"
    ];
    wants = [
      "network-online.target"
      "podman-coredns.service"
    ];
    preStart = lib.mkBefore ''
      set -a
      . /etc/nixos/secrets/red.env
      set +a

      if [ -z "''${IRIS_NTFY_TOPIC:-}" ]; then
        echo "IRIS_NTFY_TOPIC must be set in /etc/nixos/secrets/red.env" >&2
        exit 1
      fi

      install -d -m 0755 /run/podman-iris
      install -m 0600 /dev/null /run/podman-iris/ntfy-forward.env
      printf 'NTFY_FORWARD=%s\n' "$IRIS_NTFY_TOPIC" > /run/podman-iris/ntfy-forward.env

      ${pkgs.podman}/bin/podman rmi -f ${irisImage} 2>/dev/null || true
      ${pkgs.podman}/bin/podman pull ${irisImage}
    '';
  };

  systemd.services.podman-janus = {
    after = [
      "network-online.target"
      "podman-coredns.service"
      "podman-iris.service"
    ];
    wants = [
      "network-online.target"
      "podman-coredns.service"
      "podman-iris.service"
    ];
    serviceConfig = {
      Restart = "always";
      RestartSec = "5min";
    };
    preStart = lib.mkBefore ''
      ${pkgs.podman}/bin/podman rmi -f ${janusImage} 2>/dev/null || true
      ${pkgs.podman}/bin/podman pull ${janusImage}
    '';
  };

  systemd.services.podman-links = {
    after = [
      "network-online.target"
      "podman-coredns.service"
    ];
    wants = [
      "network-online.target"
      "podman-coredns.service"
    ];
    preStart = lib.mkBefore ''
      ${pkgs.podman}/bin/podman rmi -f ${linksImage} 2>/dev/null || true
      ${pkgs.podman}/bin/podman pull ${linksImage}
    '';
  };

  systemd.services.podman-filebrowser = {
    after = [ "mount-data-drives.service" ];
    wants = [ "mount-data-drives.service" ];
  };
}
