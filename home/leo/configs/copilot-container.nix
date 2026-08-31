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
    ENV PATH="/usr/local/bin:/usr/bin:/bin"

    RUN apt-get update \
        && apt-get install -y --no-install-recommends \
            bash \
            build-essential \
            ca-certificates \
            curl \
            g++ \
            gcc \
            gdb \
            git \
            gh \
            make \
            openssh-client \
            python3 \
            python3-pip \
        && rm -rf /var/lib/apt/lists/*

    # Install gh from GitHub's official apt repo so the CLI stays up to date
    # (Ubuntu's bundled package can lag well behind upstream).
    RUN mkdir -p -m 755 /etc/apt/keyrings \
        && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
            -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
        && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
        && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
            > /etc/apt/sources.list.d/github-cli.list \
        && apt-get update \
        && apt-get install -y --no-install-recommends gh \
        && rm -rf /var/lib/apt/lists/*

    RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh

    RUN /usr/local/bin/uv tool install ruff

    RUN curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

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
    GLOBAL_RESUME_DIR="/copilot-state/global-resume"

    UID_VALUE="$(id -u)"
    GID_VALUE="$(id -g)"
    GROUPS_CSV="$(id -G | tr ' ' ',')"
    CALLER_PWD="$(pwd)"
    HOST_COPILOT_HOME="''${HOST_COPILOT_HOME:-${config.xdg.dataHome}/copilot-cli}"
    USE_GLOBAL_RESUME=false
    ENABLE_PONY=false

    # Filter out our own flags (e.g. --pony) so they are never forwarded to
    # the copilot binary, while still detecting resume for the global mount.
    PONY_FILTERED_ARGS=()
    for arg in "$@"; do
      case "''${arg}" in
        --pony)
          ENABLE_PONY=true
          continue
          ;;
        --resume|--resume=*|-r|-r=*)
          USE_GLOBAL_RESUME=true
          ;;
      esac
      PONY_FILTERED_ARGS+=("''${arg}")
    done
    set -- ''${PONY_FILTERED_ARGS[@]+"''${PONY_FILTERED_ARGS[@]}"}

    # --pony uses a fully separate persistent state dir so the ponytail plugin
    # is confined to pony sessions and never bleeds into instances started
    # without the flag (split-brain by design). It is seeded with the same
    # settings/hooks/instructions as the main dir by the home-manager
    # activation hook below.
    if [ "''${ENABLE_PONY}" = true ]; then
      HOST_COPILOT_HOME="''${HOST_COPILOT_HOME}-pony"
    fi

    mkdir -p "''${HOST_COPILOT_HOME}"
    if [ "''${USE_GLOBAL_RESUME}" = true ]; then
      mkdir -p "''${HOST_COPILOT_HOME}/global-resume"
    fi

    # Carry the host Git identity into the container so commits use the same
    # author as the surrounding host checkout.
    HOST_GIT_NAME="$(git config --get user.name 2>/dev/null || true)"
    HOST_GIT_EMAIL="$(git config --get user.email 2>/dev/null || true)"
    GIT_IDENTITY_ARGS=()
    if [ -n "''${HOST_GIT_NAME}" ]; then
      GIT_IDENTITY_ARGS+=(
        -e GIT_AUTHOR_NAME="''${HOST_GIT_NAME}"
        -e GIT_COMMITTER_NAME="''${HOST_GIT_NAME}"
      )
    fi
    if [ -n "''${HOST_GIT_EMAIL}" ]; then
      GIT_IDENTITY_ARGS+=(
        -e GIT_AUTHOR_EMAIL="''${HOST_GIT_EMAIL}"
        -e GIT_COMMITTER_EMAIL="''${HOST_GIT_EMAIL}"
      )
    fi

    # Mounted outside of /tmp/home: bind-mounting directly into /tmp/home
    # would make the container engine auto-create /tmp/home as root before
    # the container's non-root user starts, breaking later mkdir calls
    # (e.g. copilot's own /tmp/home/.cache). GIT_CONFIG_GLOBAL (git >= 2.32)
    # lets us point git at it without touching /tmp/home at all.
    GITCONFIG_MOUNT_ARGS=()
    if [ -f "''${HOME}/.gitconfig" ]; then
      GITCONFIG_MOUNT_ARGS+=(
        -v "''${HOME}/.gitconfig:/tmp/host-gitconfig:ro"
        -e GIT_CONFIG_GLOBAL=/tmp/host-gitconfig
      )
    fi

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

    # Build the image only when it's missing. Use `copilot update` to force a
    # rebuild once the image exists.
    if ! "''${ENGINE}" image inspect "''${IMAGE_NAME}" >/dev/null 2>&1; then
      echo "Building ''${IMAGE_NAME} (first run) ..." >&2
      "''${ENGINE}" build \
        -t "''${IMAGE_NAME}" \
        -f "''${DOCKERFILE_PATH}" \
        "$(dirname "''${DOCKERFILE_PATH}")" >/dev/null
    fi

    if [ -n "''${COPILOT_GITHUB_TOKEN:-}" ]; then
      COPILOT_TOKEN="''${COPILOT_GITHUB_TOKEN}"
    elif [ -n "''${GH_TOKEN:-}" ]; then
      COPILOT_TOKEN="''${GH_TOKEN}"
    elif ! command -v gh >/dev/null 2>&1; then
      echo "error: no GitHub token available" >&2
      echo "       set COPILOT_GITHUB_TOKEN or GH_TOKEN, or install the gh CLI and run 'gh auth login'" >&2
      exit 1
    elif ! COPILOT_TOKEN="$(gh auth token 2>/dev/null)" || [ -z "''${COPILOT_TOKEN}" ]; then
      echo "error: could not obtain a GitHub token from gh" >&2
      echo "       run 'gh auth login', or set COPILOT_GITHUB_TOKEN or GH_TOKEN" >&2
      exit 1
    fi

    # Full auto-approval by default because the CLI runs inside this container.
    COPILOT_DEFAULTS=(
      --allow-all
    )

    if [[ "''${1:-}" == "bash" ]]; then
      : # drop into container shell as-is
    elif [ "$#" -eq 0 ]; then
      set -- copilot "''${COPILOT_DEFAULTS[@]}"
    elif [ "''${USE_GLOBAL_RESUME}" = true ]; then
      set -- copilot "''${COPILOT_DEFAULTS[@]}" -C "''${GLOBAL_RESUME_DIR}" --add-dir "''${WORKDIR_IN_CONTAINER}" "$@"
    else
      set -- copilot "''${COPILOT_DEFAULTS[@]}" "$@"
    fi

    # --pony: install and enable the ponytail plugin
    # (https://github.com/dietrichgebert/ponytail) for this instance. The
    # plugin is registered in the pony-only COPILOT_HOME selected above, so it
    # persists there (idempotent install) without ever affecting non-pony runs.
    if [ "''${ENABLE_PONY}" = true ]; then
      PONY_SETUP='copilot plugin marketplace add DietrichGebert/ponytail >/dev/null 2>&1 || true; copilot plugin install ponytail@ponytail >/dev/null 2>&1 || true; '
      set -- bash -c "''${PONY_SETUP}"'exec "$@"' pony "$@"
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
      ''${GIT_IDENTITY_ARGS[@]+"''${GIT_IDENTITY_ARGS[@]}"}
      ''${GITCONFIG_MOUNT_ARGS[@]+"''${GITCONFIG_MOUNT_ARGS[@]}"}
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

    # Host-side alias to jump straight into the copilot persistent state dir
    # (this is the host path bind-mounted as /copilot-state inside the container).
    programs.bash.shellAliases.cdcopilot = "cd ${config.xdg.dataHome}/copilot-cli";

    xdg.configFile."copilot-container/Dockerfile".text = dockerfileText;

    home.file.".local/bin/copilot" = {
      text = copilotScript;
      executable = true;
    };

    home.activation.copilotContainerDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            mkdir -p "${config.home.homeDirectory}/.local/bin"
            mkdir -p "${config.xdg.configHome}/copilot-container"

            # Seed the default and the --pony state dirs identically so pony
            # sessions get the same trust, notification hooks and instructions.
            # They stay otherwise separate (split-brain), which is what keeps
            # the ponytail plugin out of non-pony instances.
            for _cpdir in "${config.xdg.dataHome}/copilot-cli" "${config.xdg.dataHome}/copilot-cli-pony"; do
              mkdir -p "$_cpdir" "$_cpdir/global-resume" "$_cpdir/hooks"

              # Auto-trust /workspace so copilot doesn't prompt on startup
              if [ ! -f "$_cpdir/settings.json" ]; then
                echo '{"trustedFolders":["/workspace"]}' > "$_cpdir/settings.json"
              fi

              # ntfy.sh notification hooks: always regenerated from Nix config
              cat > "$_cpdir/hooks/notify.json" << 'HOOKSEOF'
      ${notifyHooksJson}
      HOOKSEOF

              # Global instructions: always regenerated from Nix config.
              # The container carries the host Git identity (see the `copilot`
              # wrapper script), so commits must use that identity as-is.
              cat > "$_cpdir/copilot-instructions.md" << 'INSTRUCTIONSEOF'
      # Git commit authorship

      This session runs inside a container that is pre-configured with the
      host user's real Git identity (via `GIT_AUTHOR_NAME`/`GIT_AUTHOR_EMAIL`
      and a mounted `.gitconfig`). When creating commits:

      - Never override `user.name` or `user.email`.
      - Do not add tool-specific co-author trailers.
      - Do not replace the host user's commit author identity.

      Commits must be authored solely as the host user.
      INSTRUCTIONSEOF
            done
    '';
  };
}
