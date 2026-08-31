{ lib, pkgs, ... }:

let
  homeLan = import ../../modules/home-lan.nix;
  certMount = "/etc/house.leo.surf";
  nginxErrorPages = import ../../modules/nginx-error-pages.nix;
  linksCorsProbes = import ../../modules/links-cors-probes.nix;
  mnemosyneImage = "docker.house.leo.surf/mnemosyne:latest";

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

  reverseProxyNginxConf = pkgs.writeText "reverse-proxy-nginx.conf" ''
    events {}

    http {
      include /etc/nginx/mime.types;
      default_type application/octet-stream;
      access_log off;
      resolver 127.0.0.1 ipv6=off valid=30s;
      ${linksCorsProbes.headers}
      ${linksCorsProbes.methodMap}
      ${linksCorsProbes.hideUpstreamHeaders}

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

      ${redirectServer "docker.house.leo.surf"}
      ${redirectServer "black-files.house.leo.surf"}
      ${redirectServer "mnemosyne.house.leo.surf"}

      server {
        listen 443 ssl default_server;
        server_name _;
        ssl_certificate ${certMount}/fullchain.pem;
        ssl_certificate_key ${certMount}/privkey.pem;
        ${nginxErrorPages.serverSnippet}
        return 404;
      }

      server {
        listen 443 ssl;
        server_name docker.house.leo.surf;
        ssl_certificate ${certMount}/fullchain.pem;
        ssl_certificate_key ${certMount}/privkey.pem;
        ${nginxErrorPages.serverSnippet}
        client_max_body_size 0;

        ${vpnProtectedLocation ''
          proxy_pass http://127.0.0.1:5000;
          ${linksCorsProbes.proxyMethod}
          ${proxyHeaders}
        ''}
      }

      server {
        listen 443 ssl;
        server_name black-files.house.leo.surf;
        ssl_certificate ${certMount}/fullchain.pem;
        ssl_certificate_key ${certMount}/privkey.pem;
        ${nginxErrorPages.serverSnippet}
        client_max_body_size 0;

        ${vpnProtectedLocation ''
          proxy_pass http://127.0.0.1:8089;
          ${linksCorsProbes.proxyMethod}
          ${proxyHeaders}
        ''}
      }

      server {
        listen 443 ssl;
        server_name mnemosyne.house.leo.surf;
        ssl_certificate ${certMount}/fullchain.pem;
        ssl_certificate_key ${certMount}/privkey.pem;
        ${nginxErrorPages.serverSnippet}

        ${vpnProtectedLocation ''
          proxy_pass http://127.0.0.1:8090;
          ${linksCorsProbes.proxyMethod}
          ${proxyHeaders}
        ''}
      }
    }
  '';
in
{
  virtualisation.oci-containers.backend = "podman";

  homeServer.irisNotify.serviceNames = [
    "podman-docker-registry"
    "podman-filebrowser"
    "podman-mnemosyne"
  ];

  systemd.tmpfiles.rules = [
    "d /opt/docker-registry 0755 root root -"
    "d /opt/filebrowser 0755 root root -"
    "d /opt/filebrowser/config 0750 1000 100 -"
    "d /opt/filebrowser/database 0750 1000 100 -"
    "d /opt/mnemosyne 0755 root root -"
  ];

  homeServer.reverseProxy = {
    nginxConfig = reverseProxyNginxConf;
    after = [
      "podman-docker-registry.service"
      "podman-filebrowser.service"
      "podman-mnemosyne.service"
    ];
    wants = [
      "podman-docker-registry.service"
      "podman-filebrowser.service"
      "podman-mnemosyne.service"
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

    mnemosyne = {
      image = mnemosyneImage;
      environment = {
        HOST = "127.0.0.1";
        PORT = "8090";
        SQLITE_PATH = "/opt/mnemosyne/mnemosyne.sqlite3";
        SALT = "mnemosyne";
      };
      volumes = [
        "/opt/mnemosyne:/opt/mnemosyne"
      ];
      extraOptions = [
        "--network=host"
      ];
    };
  };

  systemd.services.podman-filebrowser = {
    after = [ "mount-data-drives.service" ];
    wants = [ "mount-data-drives.service" ];
  };

  systemd.services.podman-mnemosyne = {
    after = [
      "network-online.target"
      "podman-coredns.service"
    ];
    wants = [
      "network-online.target"
      "podman-coredns.service"
    ];
    preStart = lib.mkBefore ''
      ${pkgs.podman}/bin/podman rmi -f ${mnemosyneImage} 2>/dev/null || true
      ${pkgs.podman}/bin/podman pull ${mnemosyneImage}
    '';
  };
}
