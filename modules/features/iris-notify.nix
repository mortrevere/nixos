{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.homeServer.irisNotify;

  irisNotify = pkgs.writeShellApplication {
    name = "iris-notify";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
    ];
    text = ''
      usage() {
        printf 'usage: iris-notify [-t topic] [-a attr-json-object] message\n' >&2
      }

      topic=
      attr='{}'

      while getopts ':t:a:h' option; do
        case "$option" in
          t)
            topic=$OPTARG
            ;;
          a)
            attr=$OPTARG
            ;;
          h)
            usage
            exit 0
            ;;
          :)
            usage
            printf 'iris-notify: option -%s requires an argument\n' "$OPTARG" >&2
            exit 64
            ;;
          \?)
            usage
            printf 'iris-notify: unknown option -%s\n' "$OPTARG" >&2
            exit 64
            ;;
        esac
      done

      shift "$((OPTIND - 1))"

      if [ "$#" -ne 1 ]; then
        usage
        exit 64
      fi

      message=$1
      if [ -z "$(printf '%s' "$message" | tr -d '[:space:]')" ]; then
        printf 'iris-notify: message cannot be blank\n' >&2
        exit 64
      fi

      if ! printf '%s' "$attr" | jq -e 'type == "object"' >/dev/null; then
        printf 'iris-notify: -a must be a JSON object\n' >&2
        exit 64
      fi

      payload="$(
        jq -cn \
          --arg message "$message" \
          --arg topic "$topic" \
          --argjson attr "$attr" \
          '{message: $message, attr: $attr} + (if $topic == "" then {} else {topic: $topic} end)'
      )"

      url=''${IRIS_NOTIFY_URL:-${lib.escapeShellArg cfg.url}}
      if ! curl \
        --fail \
        --silent \
        --show-error \
        --location \
        --max-time 10 \
        --retry 2 \
        --header 'Content-Type: application/json' \
        --data "$payload" \
        "$url" >/dev/null; then
        printf 'iris-notify: failed to deliver notification to %s\n' "$url" >&2
      fi
    '';
  };

  failureNotify = pkgs.writeShellScript "iris-systemd-failure-notify" ''
    service_name=''${1:-unknown}
    attr="$(${pkgs.jq}/bin/jq -cn --arg service "$service_name" '{service: $service}')"
    ${cfg.package}/bin/iris-notify -t systemctl -a "$attr" failed
  '';

  startHook =
    serviceName:
    let
      unitName = "${serviceName}.service";
      attr = builtins.toJSON { service = unitName; };
    in
    {
      postStart = lib.mkAfter ''
        ${cfg.package}/bin/iris-notify -t systemctl -a ${lib.escapeShellArg attr} started || true
      '';
      unitConfig.OnFailure = lib.mkAfter [ "iris-systemd-failure@%n.service" ];
    };
in
{
  options.homeServer.irisNotify = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable Iris notification helpers for server hosts.";
    };

    url = lib.mkOption {
      type = lib.types.str;
      default = "https://iris.house.leo.surf/notifications";
      description = "Default Iris notification API endpoint used by iris-notify.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = irisNotify;
      readOnly = true;
      description = "The generated iris-notify package.";
    };

    serviceNames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Systemd service names, without .service, that should send Iris start and failure notifications.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package
    ];

    systemd.services = (lib.genAttrs cfg.serviceNames startHook) // {
      "iris-systemd-failure@" = {
        description = "Send Iris notification for failed unit %I";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${failureNotify} %I";
        };
      };
    };
  };
}
