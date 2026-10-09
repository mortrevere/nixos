# home/leo/configs/codex-container.nix
#
# Plumbing only. All Codex logic (Dockerfile, wrapper script, profiles,
# hooks, instructions) lives in the standalone repo:
#
#   https://github.com/mortrevere/codex-container
#
# On every rebuild we clone/update that repo and expose its root
# `codex-container` script as the user-local `codex` command.
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

  cfg = config.programs.codex-container;

  # Host checkout of the standalone stack. Kept under XDG_DATA_HOME so it
  # persists across rebuilds and can be updated in place.
  repoDir = "${config.xdg.dataHome}/codex-container";

  # `codex` simply forwards to the repo's root wrapper. The ntfy topic (if
  # any) is passed through as an environment variable, keeping notification
  # configuration out of this repo.
  codexScript = ''
    #!/usr/bin/env bash
    set -euo pipefail

    ${lib.optionalString (cfg.ntfyTopic != "") ''
      export CODEX_NTFY_TOPIC="''${CODEX_NTFY_TOPIC:-${cfg.ntfyTopic}}"
    ''}

    exec "${repoDir}/codex-container" "$@"
  '';
in
{
  options.programs.codex-container = {
    enable = mkEnableOption "containerized OpenAI Codex CLI wrapper (mortrevere/codex-container)";

    repoUrl = mkOption {
      type = types.str;
      default = "https://github.com/mortrevere/codex-container.git";
      description = "Git URL of the standalone codex-container stack.";
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
        ntfy.sh topic forwarded to the wrapper as CODEX_NTFY_TOPIC. Left
        empty by default (notifications disabled); set a real topic through a
        host-specific or private override.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Runtime dependencies of the wrapper script (container engine + tools it
    # shells out to). The Codex logic itself is not shipped from this repo.
    home.packages = [
      cfg.package
      pkgs.git
      pkgs.gh
      pkgs.bash
      pkgs.coreutils
      pkgs.gnugrep
    ];

    home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];

    # Host-side alias to jump straight into the codex persistent state dir
    # (profiles and shared authentication live under this directory).
    programs.bash.shellAliases.cdcodex = "cd ${config.xdg.dataHome}/codex-cli";

    home.file.".local/bin/codex" = {
      text = codexScript;
      executable = true;
    };

    # On each rebuild: clone the stack if missing, otherwise fast-forward it.
    # Best-effort so activation never fails when offline.
    home.activation.codexContainerRepo = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      export PATH="${lib.makeBinPath [ pkgs.git pkgs.coreutils ]}:$PATH"
      mkdir -p "${config.home.homeDirectory}/.local/bin"

      if [ -d "${repoDir}/.git" ]; then
        run git -C "${repoDir}" pull --ff-only || \
          echo "codex-container: update failed (offline?), keeping existing checkout" >&2
      else
        mkdir -p "$(dirname "${repoDir}")"
        run git clone "${cfg.repoUrl}" "${repoDir}" || \
          echo "codex-container: clone failed (offline?), 'codex' unavailable until next rebuild" >&2
      fi
    '';
  };
}
