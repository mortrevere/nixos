{ pkgs, ... }:

{
  systemd.services.move-completed-films = {
    description = "Archive completed Transmission films after 24 hours";
    after = [ "mount-data-drives.service" ];
    wants = [ "mount-data-drives.service" ];
    unitConfig.ConditionPathIsDirectory = "/data/Extreme_SSD/archives/films";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${./move-completed-films.sh}";
    };
    path = with pkgs; [
      coreutils
      findutils
      gnugrep
    ];
  };

  systemd.timers.move-completed-films = {
    description = "Periodically archive completed Transmission films";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "10min";
      OnUnitActiveSec = "1h";
      Persistent = true;
    };
  };
}
