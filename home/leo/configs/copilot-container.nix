# home-manager/modules/copilot-container.nix
#
# Plumbing only. All Copilot logic (Dockerfile, wrapper script, profiles,
# hooks, instructions) lives in the standalone repo:
#
#   https://github.com/mortrevere/copilot-container
#
# On every rebuild we clone/update that repo and expose its root
# `copilot-container` script as the system-wide `copilot` command.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.programs.copilot-container;

  # Host checkout of the standalone stack. Kept under XDG_DATA_HOME so it
  # persists across rebuilds and can be updated in place.
  repoDir = "${config.xdg.dataHome}/copilot-container";

  # `copilot` simply forwards to the repo's root wrapper. The ntfy topic (if
  # any) is passed through as an environment variable, keeping notification
  # configuration out of this repo.
  copilotScript = ''
    #!/usr/bin/env bash
    set -euo pipefail

    ${lib.optionalString (cfg.ntfyTopic != "") ''
      export COPILOT_NTFY_TOPIC="''${COPILOT_NTFY_TOPIC:-${cfg.ntfyTopic}}"
    ''}

    exec "${repoDir}/copilot-container" "$@"
  '';
in
{
  options.programs.copilot-container = {
    enable = mkEnableOption "containerized GitHub Copilot CLI wrapper (mortrevere/copilot-container)";

    repoUrl = mkOption {
      type = types.str;
      default = "https://github.com/mortrevere/copilot-container.git";
      description = "Git URL of the standalone copilot-container stack.";
    };

    package = mkOption {
      type = types.package;
      default = pkgs.podman;
      description = "Container engine used by the wrapper script.";
    };

    ntfyTopic = mkOption {
      type = types.str;
      default = "";
      description = ''
        ntfy.sh topic forwarded to the wrapper as COPILOT_NTFY_TOPIC. Left
        empty by default (notifications disabled); set a real topic through a
        host-specific or private override.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Runtime dependencies of the wrapper script (container engine + tools it
    # shells out to). The Copilot logic itself is not shipped from this repo.
    home.packages = [
      cfg.package
      pkgs.git
      pkgs.gh
      pkgs.bash
      pkgs.coreutils
      pkgs.gnugrep
    ];

    home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];

    # Host-side alias to jump straight into the copilot persistent state dir
    # (the host path bind-mounted as /copilot-state inside the container).
    programs.bash.shellAliases.cdcopilot = "cd ${config.xdg.dataHome}/copilot-cli";

    home.file.".local/bin/copilot" = {
      text = copilotScript;
      executable = true;
    };

    # On each rebuild: clone the stack if missing, otherwise fast-forward it.
    # Best-effort so activation never fails when offline.
    home.activation.copilotContainerRepo = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      export PATH="${lib.makeBinPath [ pkgs.git pkgs.coreutils ]}:$PATH"
      mkdir -p "${config.home.homeDirectory}/.local/bin"

      if [ -d "${repoDir}/.git" ]; then
        run git -C "${repoDir}" pull --ff-only || \
          echo "copilot-container: update failed (offline?), keeping existing checkout" >&2
      else
        mkdir -p "$(dirname "${repoDir}")"
        run git clone "${cfg.repoUrl}" "${repoDir}" || \
          echo "copilot-container: clone failed (offline?), 'copilot' unavailable until next rebuild" >&2
      fi
    '';
  };
}
