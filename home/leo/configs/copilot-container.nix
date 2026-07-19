# home-manager/modules/copilot-container.nix
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

  notifyHooksJson = builtins.toJSON {
    version = 1;
    hooks = {
      notification = [
        {
          type = "command";
          matcher = "permission_prompt|elicitation_dialog|agent_idle";
          bash = "/usr/local/bin/copilot-hooks/notify-waiting.sh";
          timeoutSec = 10;
        }
      ];
      preToolUse = [
        {
          type = "command";
          matcher = "ask_user";
          bash = "/usr/local/bin/copilot-hooks/notify-waiting.sh";
          timeoutSec = 5;
        }
      ];
      agentStop = [
        {
          type = "command";
          bash = "/usr/local/bin/copilot-hooks/notify-done.sh";
          timeoutSec = 10;
        }
      ];
    };
  };

  dockerfileText = ''
    FROM ubuntu:24.04

    ENV DEBIAN_FRONTEND=noninteractive
    ENV PATH="/root/.local/bin:/usr/local/bin:/usr/bin:/bin"

    RUN apt-get update \
        && apt-get install -y --no-install-recommends \
            bash \
            ca-certificates \
            curl \
            git \
            gh \
            python3 \
            python3-pip \
        && rm -rf /var/lib/apt/lists/*

    RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh

    RUN /usr/local/bin/uv tool install ruff

    RUN curl -fsSL https://gh.io/copilot-install | bash

    RUN mkdir -p /usr/local/bin/copilot-hooks \
        && printf '%s\n' \
            '#!/usr/bin/env bash' \
            '# Backgrounded so this never adds latency when used from a blocking hook (e.g. preToolUse).' \
            '[ -z "${cfg.ntfyTopic}" ] && exit 0' \
            '(curl -fsS -d "Copilot is waiting for me" "https://ntfy.sh/${cfg.ntfyTopic}" >/dev/null 2>&1 &) || true' \
            > /usr/local/bin/copilot-hooks/notify-waiting.sh \
        && printf '%s\n' \
            '#!/usr/bin/env bash' \
            '[ -z "${cfg.ntfyTopic}" ] && exit 0' \
            'curl -fsS -d "Copilot is done" "https://ntfy.sh/${cfg.ntfyTopic}" >/dev/null 2>&1 || true' \
            > /usr/local/bin/copilot-hooks/notify-done.sh \
        && chmod +x /usr/local/bin/copilot-hooks/notify-waiting.sh /usr/local/bin/copilot-hooks/notify-done.sh

    WORKDIR /workspace
    CMD ["bash"]
  '';

  copilotScript = ''
    #!/usr/bin/env bash
    set -euo pipefail

    IMAGE_NAME="''${IMAGE_NAME:-${cfg.imageName}}"
    WORKDIR_IN_CONTAINER="/workspace"

    UID_VALUE="$(id -u)"
    GID_VALUE="$(id -g)"
    GROUPS_CSV="$(id -G | tr ' ' ',')"
    CALLER_PWD="$(pwd)"
    HOST_COPILOT_HOME="''${HOST_COPILOT_HOME:-${config.xdg.dataHome}/copilot-cli}"

    mkdir -p "''${HOST_COPILOT_HOME}"

    ENGINE="''${CONTAINER_ENGINE:-${cfg.engine}}"
    DOCKERFILE_PATH="''${XDG_CONFIG_HOME:-$HOME/.config}/copilot-container/Dockerfile"

    if [[ "''${1:-}" == "update" ]]; then
      BACKUP_TAG="backup-$(date +%d%m%Y)"
      echo "Tagging current image as ''${IMAGE_NAME%:*}:''${BACKUP_TAG} ..."
      "''${ENGINE}" tag "''${IMAGE_NAME}" "''${IMAGE_NAME%:*}:''${BACKUP_TAG}"
      echo "Rebuilding ''${IMAGE_NAME} (no cache) ..."
      "''${ENGINE}" build --no-cache \
        -t "''${IMAGE_NAME}" \
        -f "''${DOCKERFILE_PATH}" \
        "$(dirname "''${DOCKERFILE_PATH}")"
      echo "Done. Previous image kept as ''${IMAGE_NAME%:*}:''${BACKUP_TAG}"
      exit 0
    fi

    "''${ENGINE}" build \
      -t "''${IMAGE_NAME}" \
      -f "''${DOCKERFILE_PATH}" \
      "$(dirname "''${DOCKERFILE_PATH}")" >/dev/null

    if [ -n "''${COPILOT_GITHUB_TOKEN:-}" ]; then
      COPILOT_TOKEN="''${COPILOT_GITHUB_TOKEN}"
    elif [ -n "''${GH_TOKEN:-}" ]; then
      COPILOT_TOKEN="''${GH_TOKEN}"
    else
      COPILOT_TOKEN="$(gh auth token)"
    fi

    # Yolo mode by default: full auto-approval (tools, paths, URLs).
    # Safe here because the CLI already runs sandboxed inside this container.
    COPILOT_DEFAULTS=(
      --allow-all
    )

    if [[ "''${1:-}" == "bash" ]]; then
      : # drop into container shell as-is
    elif [ "$#" -eq 0 ]; then
      set -- copilot "''${COPILOT_DEFAULTS[@]}"
    else
      set -- copilot "''${COPILOT_DEFAULTS[@]}" "$@"
    fi

    ENGINE_INFO="$("''${ENGINE}" info 2>/dev/null || true)"

    RUN_ARGS=(
      --rm
      -it
      -w "''${WORKDIR_IN_CONTAINER}"
      -e HOME=/tmp/home
      -e COPILOT_HOME=/copilot-state
      -e COPILOT_GITHUB_TOKEN="''${COPILOT_TOKEN}"
      -e GH_TOKEN="''${COPILOT_TOKEN}"
      --network=host
    )

    if printf '%s' "''${ENGINE_INFO}" | grep -qi podman; then
      RUN_ARGS+=(
        --userns=keep-id
        --user "''${UID_VALUE}:''${GID_VALUE}"
        --group-add keep-groups
        --security-opt label=disable
        -v "''${CALLER_PWD}:''${WORKDIR_IN_CONTAINER}:Z"
        -v "''${HOST_COPILOT_HOME}:/copilot-state:Z"
      )
    else
      RUN_ARGS+=(
        --user "''${UID_VALUE}:''${GID_VALUE}"
        -v "''${CALLER_PWD}:''${WORKDIR_IN_CONTAINER}"
        -v "''${HOST_COPILOT_HOME}:/copilot-state"
      )

      IFS=',' read -r -a EXTRA_GROUPS <<< "''${GROUPS_CSV}"
      for grp in "''${EXTRA_GROUPS[@]}"; do
        RUN_ARGS+=(--group-add "''${grp}")
      done
    fi

    exec "''${ENGINE}" run "''${RUN_ARGS[@]}" "''${IMAGE_NAME}" "$@"
  '';
in
{
  options.programs.copilot-container = {
    enable = mkEnableOption "containerized GitHub Copilot CLI wrapper";

    engine = mkOption {
      type = types.str;
      default = "podman";
    };

    imageName = mkOption {
      type = types.str;
      default = "copilot-cli:latest";
    };

    package = mkOption {
      type = types.package;
      default = pkgs.podman;
    };

    ntfyTopic = mkOption {
      type = types.str;
      default = "";
      description = ''
        ntfy.sh topic used to notify when Copilot is waiting for input or done
        working. Left empty by default (notifications become a no-op curl to
        an empty path); set a real topic through a host-specific override.
      '';
    };
  };

  config = mkIf cfg.enable {
    home.packages = [
      cfg.package
      pkgs.gh
      pkgs.bash
      pkgs.coreutils
      pkgs.gnugrep
    ];

    home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];

    xdg.configFile."copilot-container/Dockerfile".text = dockerfileText;

    home.file.".local/bin/copilot" = {
      text = copilotScript;
      executable = true;
    };

    home.activation.copilotContainerDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "${config.xdg.dataHome}/copilot-cli"
      mkdir -p "${config.xdg.dataHome}/copilot-cli/hooks"
      mkdir -p "${config.home.homeDirectory}/.local/bin"
      mkdir -p "${config.xdg.configHome}/copilot-container"

      # Auto-trust /workspace so copilot doesn't prompt on startup
      if [ ! -f "${config.xdg.dataHome}/copilot-cli/settings.json" ]; then
        echo '{"trustedFolders":["/workspace"]}' > "${config.xdg.dataHome}/copilot-cli/settings.json"
      fi

      # ntfy.sh notification hooks: always regenerated from Nix config
      cat > "${config.xdg.dataHome}/copilot-cli/hooks/notify.json" << 'HOOKSEOF'
${notifyHooksJson}
HOOKSEOF
    '';
  };
}
