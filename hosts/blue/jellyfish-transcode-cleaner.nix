{ pkgs, ... }:

let
  transcodeDir = "/opt/jellyfin/transcodes";
  pruneLimitBytes = toString (3584 * 1024 * 1024);

  jellyfishTranscodeCleaner = pkgs.writeShellApplication {
    name = "jellyfish-transcode-cleaner";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.util-linux
    ];
    text = ''
      transcode_dir=${transcodeDir}
      limit_bytes=${pruneLimitBytes}

      if [ ! -d "$transcode_dir" ]; then
        exit 0
      fi

      if ! mountpoint -q "$transcode_dir"; then
        echo "$transcode_dir is not a mountpoint; refusing to prune" >&2
        exit 1
      fi

      used_bytes() {
        df --block-size=1 --output=used "$transcode_dir" |
          tail -n 1 |
          tr -d '[:space:]'
      }

      used="$(used_bytes)"
      if [ "$used" -le "$limit_bytes" ]; then
        exit 0
      fi

      while IFS= read -r -d "" entry; do
        file="''${entry#* }"

        if [ ! -f "$file" ]; then
          continue
        fi

        rm -f -- "$file"
        used="$(used_bytes)"

        if [ "$used" -le "$limit_bytes" ]; then
          exit 0
        fi
      done < <(
        find "$transcode_dir" \
          -xdev \
          -type f \
          -iname '*.mp4' \
          -printf '%T@ %p\0' |
          sort -z -n
      )

      if [ "$used" -gt "$limit_bytes" ]; then
        echo "$transcode_dir still uses $used bytes after pruning all mp4 files; limit is $limit_bytes bytes" >&2
        exit 1
      fi
    '';
  };
in
{
  environment.systemPackages = [
    jellyfishTranscodeCleaner
  ];

  services.cron = {
    enable = true;
    systemCronJobs = [
      "*/5 * * * * root ${jellyfishTranscodeCleaner}/bin/jellyfish-transcode-cleaner"
    ];
  };
}
