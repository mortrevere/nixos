{ pkgs, ... }:

let
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

  jellyfinTranscodeCleaner = pkgs.writeShellApplication {
    name = "jellyfin-transcode-cleaner";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.util-linux
    ];
    text = ''
      transcode_dir=${transcodeDir}
      stale_age_minutes=${staleAgeMinutes}

      if [ ! -d "$transcode_dir" ]; then
        exit 0
      fi

      if ! mountpoint -q "$transcode_dir"; then
        echo "$transcode_dir is not a mountpoint; refusing to prune" >&2
        exit 1
      fi

      find "$transcode_dir" \
        -xdev \
        -type f \
        -mmin +"$stale_age_minutes" \
        \( -iname '*.mp4' -o -iname '*.m3u8' \) \
        -delete
    '';
  };

  jellyfinTranscodeServedCleaner = pkgs.writeShellApplication {
    name = "jellyfin-transcode-served-cleaner";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.procps
    ];
    text = ''
      log_dir=${jellyfinLogDir}
      transcode_dir=${transcodeDir}
      high_bytes=${pruneHighBytes}
      target_bytes=${pruneTargetBytes}
      pressure_check_seconds=${pressureCheckSeconds}
      ffmpeg_paused=0

      used_bytes() {
        df --block-size=1 --output=used "$transcode_dir" |
          tail -n 1 |
          tr -d '[:space:]'
      }

      ffmpeg_pids() {
        pgrep -f '/usr/lib/jellyfin-ffmpeg/ffmpeg .* /config/cache/transcodes/' || true
      }

      resume_ffmpeg() {
        while IFS= read -r pid; do
          [ -n "$pid" ] || continue
          kill -CONT "$pid" 2>/dev/null || true
        done < <(ffmpeg_pids)
      }

      pressure_control() {
        while true; do
          used="$(used_bytes)"

          if [ "$used" -ge "$high_bytes" ]; then
            if [ "$ffmpeg_paused" -eq 0 ]; then
              echo "pausing Jellyfin ffmpeg because $transcode_dir uses $used bytes; high watermark is $high_bytes bytes"
              ffmpeg_paused=1
            fi

            while IFS= read -r pid; do
              [ -n "$pid" ] || continue
              kill -STOP "$pid" 2>/dev/null || true
            done < <(ffmpeg_pids)
          elif [ "$used" -le "$target_bytes" ]; then
            if [ "$ffmpeg_paused" -eq 1 ]; then
              echo "resuming Jellyfin ffmpeg because $transcode_dir uses $used bytes; target watermark is $target_bytes bytes"
              ffmpeg_paused=0
            fi

            resume_ffmpeg
          fi

          sleep "$pressure_check_seconds"
        done
      }

      current_log() {
        find "$log_dir" -maxdepth 1 -type f -name 'log_*.log' -printf '%T@ %p\n' 2>/dev/null |
          sort -n |
          tail -n 1 |
          cut -d' ' -f2-
      }

      delete_served_segment() {
        line=$1
        container_path="''${line##*Finished serving }"
        container_path="''${container_path%\"}"
        container_path="''${container_path#\"}"

        case "$container_path" in
          /config/cache/transcodes/* | /config/transcodes/*) ;;
          *) return 0 ;;
        esac

        segment="''${container_path##*/}"
        case "$segment" in
          "" | .* | *[!A-Za-z0-9._-]* | *-1.mp4) return 0 ;;
          *.mp4 | *.m4s | *.ts) ;;
          *) return 0 ;;
        esac

        file="$transcode_dir/$segment"
        if [ -f "$file" ]; then
          rm -f -- "$file"
          echo "deleted served Jellyfin transcode segment $file"
        fi
      }

      delete_stopped_stream() {
        line=$1
        container_path="''${line##*Deleting partial stream file(s) }"
        container_path="''${container_path%\"}"
        container_path="''${container_path#\"}"

        case "$container_path" in
          /config/cache/transcodes/*.m3u8 | /config/transcodes/*.m3u8) ;;
          *) return 0 ;;
        esac

        playlist="''${container_path##*/}"
        stream_id="''${playlist%.m3u8}"
        case "$stream_id" in
          "" | .* | *[!A-Za-z0-9._-]*) return 0 ;;
        esac

        deleted=0
        while IFS= read -r -d "" file; do
          rm -f -- "$file"
          deleted=$((deleted + 1))
        done < <(
          find "$transcode_dir" \
            -xdev \
            -maxdepth 1 \
            -type f \
            -name "$stream_id*" \
            -print0
        )

        if [ "$deleted" -gt 0 ]; then
          echo "deleted $deleted Jellyfin transcode files for stopped stream $stream_id"
        fi
      }

      echo "starting Jellyfin served-segment cleaner; transcodes=$transcode_dir logs=$log_dir high=$high_bytes target=$target_bytes pressure_check=''${pressure_check_seconds}s"

      pressure_control &
      pressure_pid=$!
      trap 'resume_ffmpeg; kill "$pressure_pid" 2>/dev/null || true' EXIT

      while true; do
        log_file="$(current_log || true)"
        if [ -z "$log_file" ]; then
          sleep 5
          continue
        fi

        echo "watching Jellyfin log $log_file for served HLS segments"
        timeout 300 tail -n 0 -F "$log_file" 2>/dev/null |
          while IFS= read -r line; do
            case "$line" in
              *"Jellyfin.Api.Controllers.DynamicHlsController: Finished serving "*) delete_served_segment "$line" ;;
              *"MediaBrowser.MediaEncoding.Transcoding.TranscodeManager: Deleting partial stream file(s) "*) delete_stopped_stream "$line" ;;
            esac
          done
      done
    '';
  };
in
{
  environment.systemPackages = [
    jellyfinTranscodeCleaner
    jellyfinTranscodeServedCleaner
  ];

  systemd.tmpfiles.rules = [
    "C+ /opt/jellyfin/config/logging.json 0644 1000 100 - ${jellyfinLogging}"
  ];

  services.cron = {
    enable = true;
    systemCronJobs = [
      "* * * * * root ${jellyfinTranscodeCleaner}/bin/jellyfin-transcode-cleaner"
    ];
  };

  systemd.services.jellyfin-transcode-served-cleaner = {
    description = "Delete Jellyfin HLS segments after they are served";
    after = [ "podman-jellyfin.service" ];
    wants = [ "podman-jellyfin.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${jellyfinTranscodeServedCleaner}/bin/jellyfin-transcode-served-cleaner";
      Restart = "always";
      RestartSec = "5s";
    };
  };
}
