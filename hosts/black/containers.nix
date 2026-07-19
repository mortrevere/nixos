{ pkgs, ... }:

let
  reverseProxyNginxConf = pkgs.writeText "reverse-proxy-nginx.conf" ''
    events {}

    http {
      include /etc/nginx/mime.types;
      default_type application/octet-stream;

      server {
        listen 80 default_server;
        server_name _;
        client_max_body_size 0;

        location / {
          proxy_pass http://127.0.0.1:5000;
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
in
{
  virtualisation.oci-containers.backend = "podman";

  systemd.tmpfiles.rules = [
    "d /opt/docker-registry 0755 root root -"
  ];

  homeServer.reverseProxy = {
    nginxConfig = reverseProxyNginxConf;
    after = [ "podman-docker-registry.service" ];
    wants = [ "podman-docker-registry.service" ];
  };

  virtualisation.oci-containers.containers.docker-registry = {
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
}
