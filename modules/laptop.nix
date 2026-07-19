{
  lib,
  pkgs,
  inputs,
  username,
  ...
}:

{
  imports = [
    inputs.hyprland.nixosModules.default
    ./features/tailscale.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;

  fonts.packages = with pkgs; [
    font-awesome
    iosevka
    nerd-fonts.symbols-only
    noto-fonts
    noto-fonts-color-emoji
  ];

  users.users.${username}.extraGroups = [
    "networkmanager"
    "input"
    "uinput"
    "ydotool"
  ];

  # ydotool provides uinput-level keystroke injection for paste-horizon.
  programs.ydotool.enable = true;
  hardware.uinput.enable = true;

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    EDITOR = "emacsclient -c -a emacs";
    TERMINAL = "kitty";
    BROWSER = "firefox";
    LIBVA_DRIVER_NAME = "iHD";
  };

  services.greetd = {
    enable = true;
    settings.default_session.command = builtins.concatStringsSep " " [
      "${pkgs.tuigreet}/bin/tuigreet"
      "--cmd Hyprland"
      "--time"
      "--greeting 'NixOS'"
      "--asterisks"
      "--window-padding 2"
      "--container-padding 2"
      "--theme 'container=black;border=magenta;title=blue;text=cyan;greet=blue;prompt=magenta;input=yellow;time=blue;action=cyan;button=magenta'"
    ];
  };

  hardware.firmware = with pkgs; [
    ivsc-firmware
  ];
  hardware.enableRedistributableFirmware = true;

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      libvdpau-va-gl
    ];
  };

  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
    audio.enable = true;
    jack.enable = true;
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General.Experimental = true;
  };

  services.blueman.enable = true;

  services.pipewire.wireplumber.extraConfig."10-bluez" = {
    "monitor.bluez.properties" = {
      "bluez5.enable-msbc" = true;
      "bluez5.enable-hw-volume" = true;
      "bluez5.roles" = [
        "hsp_hs"
        "hsp_ag"
        "hfp_hf"
        "hfp_ag"
      ];
    };
  };

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
  };

  programs.dconf.enable = true;

  # Keep sshd available on laptops, but do not start it automatically.
  systemd.services.sshd.wantedBy = lib.mkForce [ ];

  environment.systemPackages = with pkgs; [
    kitty
    firefox
    chromium
    dive
    emacs-pgtk
    gum
    openstackclient
    terraform
    vault
    waybar
    wofi
    networkmanagerapplet
    pavucontrol
    wl-clipboard
    grim
    tailscale
    wev
    vlc
    libcamera
    intel-gpu-tools
  ];
}
