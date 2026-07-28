{ pkgs, ... }:

let
  certMount = "/etc/house.leo.surf";

  redirectServer = serverName: ''
    server {
      listen 80;
      server_name ${serverName};
      return 301 https://$host$request_uri;
    }
  '';

  proxyHeaders = ''
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;
    proxy_set_header X-Forwarded-Port 443;
    proxy_read_timeout 300s;
    proxy_buffering off;
  '';

  reverseProxyNginxConf = pkgs.writeText "reverse-proxy-nginx.conf" ''
    events {}

    http {
      include /etc/nginx/mime.types;
      default_type application/octet-stream;

      ${redirectServer "docker.house.leo.surf"}
      ${redirectServer "black-files.house.leo.surf"}

      server {
        listen 443 ssl default_server;
        server_name docker.house.leo.surf;
        ssl_certificate ${certMount}/fullchain.pem;
        ssl_certificate_key ${certMount}/privkey.pem;
        client_max_body_size 0;

        location / {
          proxy_pass http://127.0.0.1:5000;
          ${proxyHeaders}
        }
      }

      server {
        listen 443 ssl;
        server_name black-files.house.leo.surf;
        ssl_certificate ${certMount}/fullchain.pem;
        ssl_certificate_key ${certMount}/privkey.pem;
        client_max_body_size 0;

        location / {
          proxy_pass http://127.0.0.1:8089;
          ${proxyHeaders}
        }
      }
    }
  '';
in
{
  virtualisation.oci-containers.backend = "podman";

  systemd.tmpfiles.rules = [
    "d /opt/docker-registry 0755 root root -"
    "d /opt/filebrowser 0755 root root -"
    "d /opt/filebrowser/config 0750 1000 100 -"
    "d /opt/filebrowser/database 0750 1000 100 -"
  ];

  homeServer.reverseProxy = {
    nginxConfig = reverseProxyNginxConf;
    after = [
      "podman-docker-registry.service"
      "podman-filebrowser.service"
    ];
    wants = [
      "podman-docker-registry.service"
      "podman-filebrowser.service"
    ];
  };

  virtualisation.oci-containers.containers = {
    docker-registry = {
      image = "docker.io/library/registry:2.8";
      environment = {
        REGISTRY_HTTP_ADDR = "127.0.0.1:5000";
        REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY = "/var/lib/registry";
      };
      volumes = [
        "/opt/docker-registry:/var/lib/registry"
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

  systemd.services.podman-filebrowser = {
    after = [ "mount-data-drives.service" ];
    wants = [ "mount-data-drives.service" ];
  };
}
