{ pkgs, ... }:

{
  imports = [
    ./configs/copilot-container.nix
    ./configs/kubernetes.nix
    ./configs/shell-laptop.nix
    ./configs/emacs.nix
    ./configs/prompt-laptop.nix
    ./configs/scripts.nix
    ./configs/packages.nix
    ./configs/kitty.nix
    ./configs/rofi.nix
    ./configs/mako.nix
    ./configs/waybar.nix
    ./configs/hyprland.nix
    ./configs/firefox.nix
    ./configs/paste-horizon.nix
  ];

  programs.copilot-container.enable = true;

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "image/jpeg" = "org.xfce.ristretto.desktop";
      "image/png" = "org.xfce.ristretto.desktop";
      "image/gif" = "org.xfce.ristretto.desktop";
      "image/bmp" = "org.xfce.ristretto.desktop";
      "image/webp" = "org.xfce.ristretto.desktop";
      "image/tiff" = "org.xfce.ristretto.desktop";
      "image/svg+xml" = "org.xfce.ristretto.desktop";
    };
  };

  xdg.configFile."mimeapps.list".force = true;

  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };

  home.pointerCursor = {
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  qt = {
    enable = true;
    platformTheme.name = "gtk3";
    style.name = "adwaita-dark";
  };

  home.sessionVariables = {
    GTK_THEME = "Adwaita:dark";
    QT_STYLE_OVERRIDE = "adwaita-dark";
  };
}
