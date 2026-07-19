{
  pkgs,
  username,
  ...
}:

{
  home = {
    username = username;
    homeDirectory = "/home/${username}";
    stateVersion = "25.11";
    packages = [
      pkgs.firefox
      pkgs.iosevka-bin
    ];
  };

  programs.home-manager.enable = true;

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;
    settings = {
      monitor = [ ",preferred,auto,1" ];
      animations.enabled = false;
      decoration = {
        rounding = 0;
        shadow.enabled = false;
      };
      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
      };
    };
  };

  systemd.user.services.kiosk-firefox = {
    Unit = {
      Description = "Firefox panel kiosk";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.firefox}/bin/firefox --kiosk http://nabu.house/panel.html";
      Environment = [ "MOZ_ENABLE_WAYLAND=1" ];
      Restart = "always";
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
