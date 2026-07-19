{ lib, pkgs, ... }:

let
  homeLan = import ../../modules/home-lan.nix;

  yaml = pkgs.formats.yaml { };

  grafanaImageTag = builtins.head (lib.splitString "+" pkgs.grafana.version);
  hyperionImage = "docker.house:80/hyperion:latest";
  nabuImage = "docker.house:80/nabu:latest";

  nodeTargets = map (name: {
    targets = [
      "${name}.${homeLan.domain}:9100"
    ];
    labels.node = name;
  }) homeLan.nodeNames;

  prometheusConfig = yaml.generate "prometheus.yml" {
    scrape_configs = [
      {
        job_name = "node";
        static_configs = nodeTargets;
      }
    ];
  };

  grafanaConfig = pkgs.writeText "grafana.ini" ''
    [server]
    http_addr = 127.0.0.1
    http_port = 3001
    domain = grafana.house
    root_url = http://grafana.house/

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

      map $upstream_status $probe_status_text {
        301 "Moved Permanently";
        302 "Found";
        303 "See Other";
        307 "Temporary Redirect";
        308 "Permanent Redirect";
      }

      map $http_upgrade $connection_upgrade {
        default upgrade;
        "" close;
      }

      server {
        listen 80;
        server_name grafana.house;

        location / {
          proxy_pass http://127.0.0.1:3001;
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
        server_name links.house;

        location / {
          proxy_pass http://127.0.0.1:8088;
          proxy_http_version 1.1;
          proxy_set_header Host $host;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Port 80;
        }

        location = /probe/cinema {
          proxy_pass http://10.0.0.30/;
          proxy_method GET;
          proxy_http_version 1.1;
          proxy_pass_request_body off;
          proxy_set_header Host cinema.house;
          proxy_set_header Content-Length "";
          proxy_intercept_errors on;
          error_page 301 302 303 307 308 = @probe_redirect;
          add_header X-Probe-Status $upstream_status always;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Port 80;
          proxy_read_timeout 10s;
        }

        location = /probe/grafana {
          proxy_pass http://127.0.0.1:3001/;
          proxy_method GET;
          proxy_http_version 1.1;
          proxy_pass_request_body off;
          proxy_set_header Host grafana.house;
          proxy_set_header Content-Length "";
          proxy_intercept_errors on;
          error_page 301 302 303 307 308 = @probe_redirect;
          add_header X-Probe-Status $upstream_status always;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Port 80;
          proxy_read_timeout 10s;
        }

        location = /probe/hyperion {
          proxy_pass http://127.0.0.1:8090/;
          proxy_method GET;
          proxy_http_version 1.1;
          proxy_pass_request_body off;
          proxy_set_header Host hyperion.house;
          proxy_set_header Content-Length "";
          proxy_intercept_errors on;
          error_page 301 302 303 307 308 = @probe_redirect;
          add_header X-Probe-Status $upstream_status always;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Port 80;
          proxy_read_timeout 10s;
        }

        location = /probe/nabu {
          proxy_pass http://127.0.0.1:8091/;
          proxy_method GET;
          proxy_http_version 1.1;
          proxy_pass_request_body off;
          proxy_set_header Host nabu.house;
          proxy_set_header Content-Length "";
          proxy_intercept_errors on;
          error_page 301 302 303 307 308 = @probe_redirect;
          add_header X-Probe-Status $upstream_status always;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Port 80;
          proxy_read_timeout 10s;
        }

        location = /probe/docker {
          proxy_pass http://10.0.0.29/;
          proxy_method GET;
          proxy_http_version 1.1;
          proxy_pass_request_body off;
          proxy_set_header Host docker.house;
          proxy_set_header Content-Length "";
          proxy_intercept_errors on;
          error_page 301 302 303 307 308 = @probe_redirect;
          add_header X-Probe-Status $upstream_status always;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Port 80;
          proxy_read_timeout 10s;
        }

        location = /probe/prometheus {
          proxy_pass http://127.0.0.1:9090/;
          proxy_method GET;
          proxy_http_version 1.1;
          proxy_pass_request_body off;
          proxy_set_header Host prometheus.house;
          proxy_set_header Content-Length "";
          proxy_intercept_errors on;
          error_page 301 302 303 307 308 = @probe_redirect;
          add_header X-Probe-Status $upstream_status always;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Port 80;
          proxy_read_timeout 10s;
        }

        location = /probe/transmission {
          proxy_pass http://10.0.0.30/;
          proxy_method GET;
          proxy_http_version 1.1;
          proxy_pass_request_body off;
          proxy_set_header Host transmission.house;
          proxy_set_header Content-Length "";
          proxy_intercept_errors on;
          error_page 301 302 303 307 308 = @probe_redirect;
          add_header X-Probe-Status $upstream_status always;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Port 80;
          proxy_read_timeout 10s;
        }

        location @probe_redirect {
          add_header X-Probe-Status $upstream_status always;
          add_header X-Probe-Status-Text $probe_status_text always;
          return 204;
        }
      }

      server {
        listen 80;
        server_name hyperion.house;

        location / {
          proxy_pass http://127.0.0.1:8090;
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
        server_name nabu.house;

        location / {
          proxy_pass http://127.0.0.1:8091;
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
        server_name prometheus.house;

        location / {
          proxy_pass http://127.0.0.1:9090;
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
    }
  '';

  linksNginxConf = pkgs.writeText "links-nginx.conf" ''
    events {}

    http {
      include /etc/nginx/mime.types;
      default_type application/octet-stream;

      server {
        listen 127.0.0.1:8088;
        server_name _;
        root /usr/share/nginx/html;
        index index.html;

        location = / {
          try_files /index.html =404;
        }

        location = /index.html {
          try_files /index.html =404;
        }
      }
    }
  '';
in
{
  virtualisation.oci-containers.backend = "podman";

  systemd.tmpfiles.rules = [
    "d /opt/grafana 0755 root root -"
    "d /opt/grafana/data 0750 472 472 -"
    "d /opt/hyperion 0755 root root -"
    "d /opt/nabu 0755 root root -"
    "d /opt/prometheus 0755 root root -"
    "d /opt/prometheus/data 0750 65534 65534 -"
    "d /var/lib/red-links-nginx 0755 root root -"
  ];

  homeServer.reverseProxy = {
    nginxConfig = reverseProxyNginxConf;
    after = [
      "grafana-dashboard-reconcile.service"
      "podman-hyperion.service"
      "podman-nabu.service"
      "podman-links-nginx.service"
      "podman-grafana.service"
      "podman-prometheus.service"
    ];
    wants = [
      "grafana-dashboard-reconcile.service"
      "podman-hyperion.service"
      "podman-nabu.service"
      "podman-links-nginx.service"
      "podman-grafana.service"
      "podman-prometheus.service"
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

    links-nginx = {
      image = "docker.io/library/nginx:1.27-alpine";
      volumes = [
        "/var/lib/red-links-nginx/nginx.conf:/etc/nginx/nginx.conf:ro"
        "${./links/index.html}:/usr/share/nginx/html/index.html:ro"
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

    prometheus = {
      image = "docker.io/prom/prometheus:v${pkgs.prometheus.version}";
      cmd = [
        "--config.file=/etc/prometheus/prometheus.yml"
        "--storage.tsdb.path=/prometheus"
        "--storage.tsdb.retention.time=60d"
        "--storage.tsdb.min-block-duration=24h"
        "--storage.tsdb.max-block-duration=24h"
        "--web.listen-address=127.0.0.1:9090"
        "--web.external-url=http://prometheus.house/"
      ];
      volumes = [
        "/opt/prometheus/data:/prometheus"
        "${prometheusConfig}:/etc/prometheus/prometheus.yml:ro"
      ];
      extraOptions = [
        "--network=host"
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    podman-compose
  ];

  system.activationScripts.restartRedContainers.text = ''
    if [ "''${NIXOS_ACTION:-}" = switch ] && [ -d /run/systemd/system ]; then
      for service in prometheus grafana hyperion nabu; do
        if ${pkgs.systemd}/bin/systemctl --quiet is-active "podman-$service.service"; then
          ${pkgs.systemd}/bin/systemctl restart "podman-$service.service"
        fi
      done
    fi
  '';

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

  systemd.services.podman-links-nginx = {
    restartTriggers = [ ./links/index.html ];
    preStart = ''
      install -d -m 0755 /var/lib/red-links-nginx
      install -m 0644 ${linksNginxConf} /var/lib/red-links-nginx/nginx.conf
    '';
  };
}
