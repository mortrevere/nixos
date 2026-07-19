{
  config,
  lib,
  pkgs,
  hostname,
  username,
  ...
}:

let
  cfg = config.homeServer;
  homeLan = import ../home-lan.nix;

  dnsServers = [ "127.0.0.1" ] ++ homeLan.peerAddresses hostname;
  mountDataDrives = pkgs.writeShellScript "mount-data-drives" ''
    set -euo pipefail

    mkdir -p /data

    ${pkgs.util-linux}/bin/lsblk -P -p -o NAME,TYPE,TRAN,PKNAME,FSTYPE,LABEL,UUID,MOUNTPOINT |
      while IFS= read -r line; do
        eval "$line"

        [ "''${TYPE:-}" = part ] || continue

        transport="''${TRAN:-}"
        if [ -z "$transport" ] && [ -n "''${PKNAME:-}" ]; then
          transport="$( ${pkgs.util-linux}/bin/lsblk -dn -o TRAN "$PKNAME" 2>/dev/null || true )"
        fi

        [ "$transport" = usb ] || continue
        [ -n "''${FSTYPE:-}" ] && [ -z "''${MOUNTPOINT:-}" ] || continue

        name="''${LABEL:-''${UUID:-$(basename "$NAME")}}"
        safe_name=$(printf '%s' "$name" | ${pkgs.gnused}/bin/sed 's/[^A-Za-z0-9._-]/_/g')
        target="/data/$safe_name"

        mkdir -p "$target"

        uid="$( ${pkgs.coreutils}/bin/id -u ${username} )"
        gid="$( ${pkgs.coreutils}/bin/id -g ${username} )"
        case "''${FSTYPE:-}" in
          exfat|vfat|ntfs|ntfs3)
            options="nofail,uid=$uid,gid=$gid,umask=022"
            ;;
          *)
            options="nofail"
            ;;
        esac

        ${pkgs.util-linux}/bin/mount -o "$options" "$NAME" "$target"
      done
  '';

  optionalInterface = lib.optionalAttrs (cfg.wifi.interface != null) {
    interface-name = cfg.wifi.interface;
  };

  manualIpv4 = lib.optionalAttrs (cfg.wifi.ipv4.address != null) {
    addresses = cfg.wifi.ipv4.address;
    inherit (cfg.wifi.ipv4) gateway;
  };
in
{
  options.homeServer = {
    wifi = {
      secretFile = lib.mkOption {
        type = lib.types.str;
        default = "/etc/nixos/secrets/${hostname}.env";
      };
      ssidVariable = lib.mkOption { type = lib.types.str; };
      pskVariable = lib.mkOption { type = lib.types.str; };
      interface = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      ipv4 = {
        method = lib.mkOption {
          type = lib.types.enum [
            "auto"
            "manual"
          ];
          default = "auto";
        };
        address = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
        gateway = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
      };
    };

    firewall = {
      extraInputRules = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
      extraForwardRules = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
      extraNatRules = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
    };

    storage.periodicScan = lib.mkEnableOption "periodic USB data-drive scans";
  };

  config = {
    networking.networkmanager = {
      enable = true;
      ensureProfiles = {
        environmentFiles = [ cfg.wifi.secretFile ];
        profiles."${hostname}-wifi" = {
          connection = {
            id = "${hostname}-wifi";
            type = "wifi";
            autoconnect = true;
          }
          // optionalInterface;
          wifi = {
            mode = "infrastructure";
            ssid = "$${cfg.wifi.ssidVariable}";
          };
          wifi-security = {
            key-mgmt = "wpa-psk";
            psk = "$${cfg.wifi.pskVariable}";
          };
          ipv4 = {
            inherit (cfg.wifi.ipv4) method;
            dns = (lib.concatStringsSep ";" dnsServers) + ";";
            ignore-auto-dns = true;
          }
          // manualIpv4;
          ipv6.method = "auto";
        };
      };
    };

    networking.firewall.enable = false;
    networking.nftables = {
      enable = true;
      tables = {
        filter = {
          family = "inet";
          content = ''
                        define private_v4 = { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 }

                      chain input {
                        type filter hook input priority 0; policy drop;

                        iifname "lo" accept
                        ct state established,related accept
                        ct state invalid drop

                        ip protocol icmp accept
                        ip6 nexthdr icmpv6 accept

                        udp sport 67 udp dport 68 accept

                        tcp dport 22 accept
                        tcp dport 9100 ip saddr $private_v4 accept
                        udp dport 53 ip saddr $private_v4 accept
                        tcp dport 53 ip saddr $private_v4 accept
            ${lib.concatMapStringsSep "\n" (rule: "            ${rule}") cfg.firewall.extraInputRules}
                      }

                      chain forward {
                        type filter hook forward priority 0; policy drop;

                        ct state established,related accept
                        iifname "podman*" accept
                        oifname "podman*" accept
                        iifname "cni-podman0" accept
                        oifname "cni-podman0" accept
            ${lib.concatMapStringsSep "\n" (rule: "            ${rule}") cfg.firewall.extraForwardRules}
                      }

                      chain output {
                        type filter hook output priority 0; policy accept;
                      }
          '';
        };
      }
      // lib.optionalAttrs (cfg.firewall.extraNatRules != [ ]) {
        nat = {
          family = "ip";
          content = ''
                        chain postrouting {
                          type nat hook postrouting priority srcnat; policy accept;

            ${lib.concatMapStringsSep "\n" (rule: "              ${rule}") cfg.firewall.extraNatRules}
                        }
          '';
        };
      };
    };

    services.prometheus.exporters.node = {
      enable = true;
      enabledCollectors = [
        "processes"
        "systemd"
      ];
      openFirewall = false;
    };

    systemd.tmpfiles.rules = [ "d /data 0755 root root -" ];
    systemd.services.mount-data-drives = {
      description = "Mount USB external data drives under /data";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = mountDataDrives;
      };
      wantedBy = [ "multi-user.target" ];
    };
    systemd.timers.mount-data-drives = lib.mkIf cfg.storage.periodicScan {
      description = "Periodically check for USB external data drives";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = "5min";
        Unit = "mount-data-drives.service";
      };
    };

    services.udev.extraRules = ''
      ACTION=="add|change", SUBSYSTEM=="block", ENV{ID_BUS}=="usb", TAG+="systemd", ENV{SYSTEMD_WANTS}+="mount-data-drives.service"
    '';
  };
}
