{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.nordvpnGateway;
  profileOrder = lib.unique ([ cfg.activeProfile ] ++ cfg.fallbackProfiles);
  profileExists = name: builtins.hasAttr name cfg.profiles;
  sourceConfig = name: builtins.readFile cfg.profiles.${name};
  hasTunDevice = name: profileExists name && lib.hasInfix "dev tun\n" (sourceConfig name);
  hasInteractiveAuth = name: profileExists name && lib.hasInfix "auth-user-pass\n" (sourceConfig name);
  effectiveConfig = name:
    builtins.replaceStrings
      [
        "dev tun\n"
        "auth-user-pass\n"
      ]
      [
        "dev tun-nord\n"
        "auth-user-pass ${cfg.credentialsFile}\n"
      ]
      (sourceConfig name);
  profileConfigs = lib.genAttrs profileOrder (
    name: pkgs.writeText "openvpn-config-nordvpn-${name}" (effectiveConfig name)
  );
  profileArray = lib.concatMapStringsSep "\n" (name: "        ${lib.escapeShellArg name}") profileOrder;
  profileCase = lib.concatMapStringsSep "\n" (
    name: ''
      ${lib.escapeShellArg name})
        printf '%s\n' ${lib.escapeShellArg "${profileConfigs.${name}}"}
        ;;
    ''
  ) profileOrder;

  irisNotify = lib.attrByPath [ "homeServer" "irisNotify" "package" ] null config;

  cleanup = pkgs.writeShellApplication {
    name = "nordvpn-gateway-cleanup";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.iproute2
    ];
    text = ''
      if ip link show tun-nord >/dev/null 2>&1; then
        ip route del 0.0.0.0/1 dev tun-nord >/dev/null 2>&1 || true
        ip route del 128.0.0.0/1 dev tun-nord >/dev/null 2>&1 || true
        ip route flush dev tun-nord >/dev/null 2>&1 || true
        ip link delete tun-nord >/dev/null 2>&1 || true
      fi
    '';
  };

  launcher = pkgs.writeShellApplication {
    name = "nordvpn-gateway-openvpn";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.openvpn
    ];
    text = ''
      state_dir=/var/lib/nordvpn-gateway
      active_file="$state_dir/active-profile"
      mkdir -p "$state_dir"

      if [ -s "$active_file" ]; then
        active_profile="$(head -n 1 "$active_file")"
      else
        active_profile=${lib.escapeShellArg cfg.activeProfile}
        printf '%s\n' "$active_profile" > "$active_file"
      fi

      profile_config="$(
        case "$active_profile" in
      ${profileCase}
          *)
            active_profile=${lib.escapeShellArg cfg.activeProfile}
            printf '%s\n' "$active_profile" > "$active_file"
            printf '%s\n' ${lib.escapeShellArg "${profileConfigs.${cfg.activeProfile}}"}
            ;;
        esac
      )"

      exec openvpn --suppress-timestamps --config "$profile_config"
    '';
  };

  watchdog = pkgs.writeShellApplication {
    name = "nordvpn-gateway-watchdog";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.glibc.bin
      pkgs.gnugrep
      pkgs.iproute2
      pkgs.jq
      pkgs.systemd
      pkgs.util-linux
    ]
    ++ lib.optional (irisNotify != null) irisNotify;
    text = ''
      state_dir=/var/lib/nordvpn-gateway
      active_file="$state_dir/active-profile"
      status_file="$state_dir/status"
      failure_count_file="$state_dir/failure-count"
      lock_file=/run/nordvpn-gateway-watchdog.lock
      profiles=(
${profileArray}
      )
      connect_timeout=${toString cfg.connectTimeoutSec}
      failure_threshold=${toString cfg.failureThreshold}

      mkdir -p "$state_dir"

      notify() {
        message=$1
        profile=''${2:-}
        status=''${3:-}
        previous=''${4:-}
        attr="$(
          jq -cn \
            --arg profile "$profile" \
            --arg status "$status" \
            --arg previous "$previous" \
            '{profile: $profile, status: $status, previous: $previous}'
        )"
        if command -v iris-notify >/dev/null 2>&1; then
          iris-notify -t nordvpn-gateway -a "$attr" "$message" || true
        fi
      }

      current_profile() {
        if [ -s "$active_file" ]; then
          head -n 1 "$active_file"
        else
          printf '%s\n' ${lib.escapeShellArg cfg.activeProfile}
        fi
      }

      current_status() {
        if [ -s "$status_file" ]; then
          head -n 1 "$status_file"
        else
          printf 'unknown\n'
        fi
      }

      record_vpn() {
        profile=$1
        printf 'vpn:%s\n' "$profile" > "$status_file"
        rm -f "$failure_count_file"
      }

      record_failure() {
        failures=0
        if [ -s "$failure_count_file" ]; then
          failures="$(head -n 1 "$failure_count_file")"
        fi
        case "$failures" in
          ""|*[!0-9]*)
            failures=0
            ;;
        esac
        failures=$((failures + 1))
        printf '%s\n' "$failures" > "$failure_count_file"
        [ "$failures" -ge "$failure_threshold" ]
      }

      vpn_healthy() {
        systemctl is-active --quiet openvpn-nordvpn.service || return 1
        ip link show tun-nord >/dev/null 2>&1 || return 1
        ip route | grep -Eq '^0\.0\.0\.0/1 .* dev tun-nord( |$)' || return 1
        ip route | grep -Eq '^128\.0\.0\.0/1 .* dev tun-nord( |$)' || return 1
        ip route get 1.1.1.1 2>/dev/null | grep -q ' dev tun-nord ' || return 1
        curl --fail --silent --show-error --interface tun-nord --max-time 10 https://ifconfig.me >/dev/null 2>&1 || return 1
      }

      wait_for_health() {
        deadline=$((SECONDS + connect_timeout))
        while [ "$SECONDS" -lt "$deadline" ]; do
          if vpn_healthy; then
            return 0
          fi
          sleep 5
        done
        return 1
      }

      (
        flock -n 9 || exit 0

        active_profile="$(current_profile)"
        previous_status="$(current_status)"
        if vpn_healthy; then
          record_vpn "$active_profile"
          case "$previous_status" in
            fallback)
              notify "VPN restored" "$active_profile" "restored" "$previous_status"
              ;;
            vpn:*)
              if [ "$previous_status" != "vpn:$active_profile" ]; then
                notify "VPN profile active" "$active_profile" "switched" "$previous_status"
              fi
              ;;
          esac
          exit 0
        fi

        if ! record_failure; then
          exit 0
        fi

        for profile in "''${profiles[@]}"; do
          printf '%s\n' "$profile" > "$active_file"
          systemctl --no-block restart openvpn-nordvpn.service || true
          if wait_for_health; then
            record_vpn "$profile"
            if [ "$profile" = "$active_profile" ]; then
              notify "VPN restored" "$profile" "restored" "$previous_status"
            else
              notify "VPN switched profile" "$profile" "switched" "$active_profile"
            fi
            exit 0
          fi
        done

        systemctl stop openvpn-nordvpn.service || true
        ${cleanup}/bin/nordvpn-gateway-cleanup || {
          notify "VPN cleanup failed" "$(current_profile)" "cleanup-failed" "$previous_status"
          exit 1
        }
        printf 'fallback\n' > "$status_file"
        rm -f "$failure_count_file"
        if [ "$previous_status" != "fallback" ]; then
          notify "All NordVPN profiles failed; normal routing fallback is active" "$(current_profile)" "fallback" "$previous_status"
        fi
      ) 9>"$lock_file"
    '';
  };
in
{
  options.nordvpnGateway = {
    enable = lib.mkEnableOption "NordVPN as a fail-open IPv4 gateway";

    lanInterface = lib.mkOption {
      type = lib.types.str;
      description = "LAN interface which receives traffic to forward through NordVPN.";
    };

    credentialsFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/nixos/secrets/nordvpn.auth";
      description = "Two-line OpenVPN service-credential file, containing username then password.";
    };

    profiles = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = { };
      description = "Named NordVPN OpenVPN profiles available for selection.";
    };

    activeProfile = lib.mkOption {
      type = lib.types.str;
      description = "Name of the NordVPN OpenVPN profile to activate.";
    };

    fallbackProfiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Ordered NordVPN OpenVPN profiles to try after activeProfile fails.";
    };

    watchdogIntervalSec = lib.mkOption {
      type = lib.types.int;
      default = 60;
      description = "How often to check and repair the NordVPN gateway tunnel.";
    };

    connectTimeoutSec = lib.mkOption {
      type = lib.types.int;
      default = 75;
      description = "Seconds to wait for a profile to become healthy before trying the next one.";
    };

    failureThreshold = lib.mkOption {
      type = lib.types.int;
      default = 3;
      description = "Consecutive failed watchdog checks required before restarting or switching VPN profiles.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.all profileExists profileOrder;
        message = "nordvpnGateway.activeProfile and fallbackProfiles must name entries in nordvpnGateway.profiles";
      }
      {
        assertion = lib.all hasTunDevice profileOrder;
        message = "Every selected NordVPN profile must contain a 'dev tun' directive";
      }
      {
        assertion = lib.all hasInteractiveAuth profileOrder;
        message = "Every selected NordVPN profile must contain a bare 'auth-user-pass' directive";
      }
      {
        assertion = cfg.watchdogIntervalSec > 0;
        message = "nordvpnGateway.watchdogIntervalSec must be positive";
      }
      {
        assertion = cfg.connectTimeoutSec > 0;
        message = "nordvpnGateway.connectTimeoutSec must be positive";
      }
      {
        assertion = cfg.failureThreshold > 0;
        message = "nordvpnGateway.failureThreshold must be positive";
      }
    ];

    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv4.conf.all.send_redirects" = 0;
      "net.ipv4.conf.default.send_redirects" = 0;
      "net.ipv4.conf.${cfg.lanInterface}.send_redirects" = 0;
      "net.ipv4.conf.all.accept_redirects" = 0;
      "net.ipv4.conf.default.accept_redirects" = 0;
    };

    systemd.services.openvpn-nordvpn = {
      description = "OpenVPN instance 'nordvpn'";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      unitConfig.ConditionPathExists = cfg.credentialsFile;
      preStart = ''
        ${cleanup}/bin/nordvpn-gateway-cleanup
      '';
      serviceConfig = {
        Type = "notify";
        ExecStart = "${launcher}/bin/nordvpn-gateway-openvpn";
        Restart = "on-failure";
        RestartSec = "10s";
        StateDirectory = "nordvpn-gateway";
      };
    };

    systemd.services.nordvpn-gateway-watchdog = {
      description = "Watch and repair the NordVPN gateway tunnel";
      after = [ "network.target" ];
      unitConfig.ConditionPathExists = cfg.credentialsFile;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${watchdog}/bin/nordvpn-gateway-watchdog";
        StateDirectory = "nordvpn-gateway";
      };
    };

    systemd.timers.nordvpn-gateway-watchdog = {
      description = "Watch and repair the NordVPN gateway tunnel";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = "${toString cfg.watchdogIntervalSec}s";
        AccuracySec = "10s";
        Unit = "nordvpn-gateway-watchdog.service";
      };
    };
  };
}
