{
  lib,
  pkgs,
  hostname,
  username,
  ...
}:

let
  homeLan = import ../home-lan.nix;
  version = "v0.1";
  identityFile = "/etc/nixos/secrets/autobackup_ed25519";
  logFile = "/var/log/autobackup/opt.log";

  autobackupPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC1eVhdTmHYdkNbrShRw7AhYySvIlLwXRxiYCjgka8P8 autobackup";

  autobackup = pkgs.stdenvNoCC.mkDerivation {
    pname = "autobackup";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/mortrevere/autobackup/releases/download/${version}/autobackup";
      hash = "sha256-WG+FSiTXHdpVAnX+W5kjZxhdIFKEM2RmSpVdlUWqY8Y=";
    };

    dontUnpack = true;

    installPhase = ''
      install -Dm0755 "$src" "$out/bin/autobackup"
    '';
  };

  schedules = {
    red = {
      minute = "17";
      hour = "2";
    };
    blue = {
      minute = "17";
      hour = "3";
    };
    black = {
      minute = "17";
      hour = "4";
    };
  };

  schedule =
    schedules.${hostname} or {
      minute = "17";
      hour = "3";
    };

  configFile = (pkgs.formats.json { }).generate "autobackup-${hostname}.json" {
    jobs = 8;
    destination = {
      host = homeLan.addresses.black;
      inherit username;
      base-path = "/data/LeoBackup1/autobackup-${hostname}-opt";
      identity-file = identityFile;
    };
    tools = {
      rsync = "${pkgs.rsync}/bin/rsync";
      ssh = "${pkgs.openssh}/bin/ssh";
    };
    quiet = false;
    windows-path-style = "auto";
    locations = [
      (
        {
          source = "/opt";
          destination = ".";
          verification = "audit";
          exclude-prefixes = [ ];
          exclude-strings = [ ];
          delete = false;
        }
        // lib.optionalAttrs (hostname == "blue") {
          exclude-strings = [
            "downloads/"
            "media"
          ];
        }
      )
    ];
  };
in
{
  services.cron.enable = true;
  services.cron.systemCronJobs = [
    "${schedule.minute} ${schedule.hour} * * * root if [ -r ${identityFile} ]; then ${autobackup}/bin/autobackup -config ${configFile} > ${logFile} 2>&1; else echo 'missing autobackup identity file: ${identityFile}' > ${logFile}; exit 1; fi"
  ];

  systemd.tmpfiles.rules = [
    "d /var/log/autobackup 0755 root root -"
  ]
  ++ lib.optionals (hostname == "black") [
    "d /data/LeoBackup1 0755 ${username} ${username} -"
  ];

  users.users.${username}.openssh.authorizedKeys.keys = lib.optionals (hostname == "black") [
    autobackupPublicKey
  ];

  environment.systemPackages = [
    autobackup
  ];
}
