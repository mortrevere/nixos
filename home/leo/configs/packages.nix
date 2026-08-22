{
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    kitty
    firefox
    iosevka-bin

    # bar / launcher / notifications
    rofi
    mako
    libnotify

    # audio / network / bluetooth / tray
    networkmanagerapplet
    pavucontrol
    playerctl
    blueman

    # clipboard / screenshots / brightness
    wl-clipboard
    cliphist
    hyprshot
    brightnessctl

    # lock / idle
    hyprlock
    hypridle

    # file manager
    xfce.thunar
    xfce.tumbler # thumbnail generator for thunar

    # graphics
    xfce.ristretto # lightweight image viewer
    gimp

    # theming
    papirus-icon-theme
    bibata-cursors
    gnome-themes-extra # Adwaita dark theme

    # helper
    wev
    swaybg
    jq
    dig
    ripgrep
    dyff

    # cloud
    incus
    scaleway-cli
    redis
    awscli2
    google-cloud-sdk
    (linode-cli.overrideAttrs (old: {
      # the `obj` (Object Storage) plugin requires boto3 at runtime
      propagatedBuildInputs = (old.propagatedBuildInputs or [ ]) ++ [ python3Packages.boto3 ];
    }))
    (callPackage ../files/pkgs/cosign.nix { }) # pinned to 2.6.1
  ];
}
