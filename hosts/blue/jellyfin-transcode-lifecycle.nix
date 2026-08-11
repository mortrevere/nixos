{ lib, pkgs, ... }:

let
  image = "docker.house.leo.surf/jellyfin-transcode-lifecycle:latest";
  transcodeDir = "/opt/jellyfin/transcodes";
  jellyfinLogDir = "/opt/jellyfin/config/log";
  staleAgeMinutes = "120";
  pruneHighBytes = toString (2560 * 1024 * 1024);
  pruneTargetBytes = toString (2048 * 1024 * 1024);
  pressureCheckSeconds = "5";

  jellyfinLogging = pkgs.writeText "jellyfin-logging.json" ''
    {
      "Serilog": {
        "MinimumLevel": {
          "Default": "Information",
          "Override": {
            "Microsoft": "Warning",
            "System": "Warning",
            "Jellyfin.Api.Controllers.DynamicHlsController": "Debug"
          }
        }
      }
    }
  '';
in
{
  homeServer.irisNotify.serviceNames = [
    "podman-jellyfin-transcode-lifecycle"
  ];

  systemd.tmpfiles.rules = [
    "C+ /opt/jellyfin/config/logging.json 0644 1000 100 - ${jellyfinLogging}"
  ];

  virtualisation.oci-containers.containers."jellyfin-transcode-lifecycle" = {
    inherit image;
    environment = {
      JTL_TRANSCODE_DIR = "/transcodes";
      JTL_LOG_DIR = "/jellyfin-logs";
      JTL_STALE_AGE_MINUTES = staleAgeMinutes;
      JTL_STALE_PRUNE_INTERVAL_SECONDS = "60";
      JTL_HIGH_BYTES = pruneHighBytes;
      JTL_TARGET_BYTES = pruneTargetBytes;
      JTL_PRESSURE_CHECK_SECONDS = pressureCheckSeconds;
      JTL_LOG_POLL_SECONDS = "5";
      JTL_LOG_REOPEN_SECONDS = "300";
      JTL_REQUIRE_MOUNTPOINT = "true";
    };
    volumes = [
      "${transcodeDir}:/transcodes"
      "${jellyfinLogDir}:/jellyfin-logs:ro"
    ];
    extraOptions = [
      "--pid=host"
    ];
  };

  systemd.services.podman-jellyfin-transcode-lifecycle = {
    after = [
      "podman-jellyfin.service"
      "opt-jellyfin-transcodes.mount"
    ];
    wants = [
      "podman-jellyfin.service"
      "opt-jellyfin-transcodes.mount"
    ];
    preStart = lib.mkBefore ''
      ${pkgs.podman}/bin/podman rmi -f ${image} 2>/dev/null || true
      ${pkgs.podman}/bin/podman pull ${image}
    '';
  };

  system.activationScripts.restartJellyfinTranscodeLifecycle.text = ''
    if [ "''${NIXOS_ACTION:-}" = switch ] && [ -d /run/systemd/system ]; then
      if ${pkgs.systemd}/bin/systemctl --quiet is-active podman-jellyfin-transcode-lifecycle.service; then
        ${pkgs.systemd}/bin/systemctl restart podman-jellyfin-transcode-lifecycle.service
      fi
    fi
  '';
}
