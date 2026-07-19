{
  lib,
  pkgs,
  hostname,
  ...
}:

let
  homeLan = import ../home-lan.nix;

  hostLines = map (
    name:
    let
      address = builtins.getAttr name homeLan.addresses;
    in
    "${address} ${name}.${homeLan.domain}"
  ) homeLan.nodeNames;

  applicationHostLines = lib.mapAttrsToList (
    service: host:
    let
      address = builtins.getAttr host homeLan.addresses;
    in
    "${address} ${service}.${homeLan.domain}"
  ) homeLan.applicationHosts;

  localHosts = pkgs.writeText "home-lan.hosts" (
    lib.concatStringsSep "\n" (hostLines ++ applicationHostLines) + "\n"
  );

  corefile = pkgs.writeText "Corefile" ''
    ${homeLan.domain}:53 {
      hosts /etc/coredns/local.hosts {
      }
      cache 300
      errors
      log
    }

    .:53 {
      forward . ${lib.concatStringsSep " " homeLan.publicResolvers}
      cache 300
      errors
      log
    }
  '';
in
{
  assertions = [
    {
      assertion = builtins.hasAttr hostname homeLan.addresses;
      message = "home-dns is only configured for known home LAN nodes";
    }
  ];

  virtualisation.oci-containers.backend = lib.mkDefault "podman";

  virtualisation.oci-containers.containers.coredns = {
    image = "docker.io/coredns/coredns:1.11.3";
    cmd = [
      "-conf"
      "/etc/coredns/Corefile"
    ];
    volumes = [
      "${corefile}:/etc/coredns/Corefile:ro"
      "${localHosts}:/etc/coredns/local.hosts:ro"
    ];
    extraOptions = [
      "--network=host"
    ];
  };

  system.activationScripts.restartCoreDns.text = ''
    if [ "''${NIXOS_ACTION:-}" = switch ] && [ -d /run/systemd/system ]; then
      if ${pkgs.systemd}/bin/systemctl --quiet is-active podman-coredns.service; then
        ${pkgs.systemd}/bin/systemctl restart podman-coredns.service
      fi
    fi
  '';
}
