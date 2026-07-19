{
  lib,
  pkgs,
  username,
  hostname,
  ...
}:

{
  boot.tmp.cleanOnBoot = true;
  boot.consoleLogLevel = 3;

  nixpkgs.config.allowUnfree = true;

  networking.hostName = hostname;

  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "fr_FR.UTF-8";

  services.xserver.xkb = {
    layout = "fr";
    variant = "";
  };

  console = {
    earlySetup = true;
    useXkbConfig = true;
    colors = [
      "1f1626" # 0  black        -> background (dark purple)
      "d94085" # 1  red          -> accent (magenta/pink)
      "2ab250" # 2  green        -> active/success
      "fff8dd" # 3  yellow       -> cream / warm white
      "883cdc" # 4  blue         -> selected (purple)
      "d94085" # 5  magenta      -> accent (magenta/pink)
      "d9faff" # 6  cyan         -> foreground (light cyan)
      "d9faff" # 7  white        -> foreground (light cyan)
      "352a3d" # 8  bright black -> slightly lighter bg
      "e8609a" # 9  bright red   -> lighter pink
      "3fd26b" # 10 bright green -> lighter green
      "fff8dd" # 11 bright yellow-> cream
      "a66ce0" # 12 bright blue  -> lighter purple
      "e8609a" # 13 bright mag.  -> lighter pink
      "e8ffff" # 14 bright cyan  -> brighter cyan
      "ffffff" # 15 bright white -> pure white
    ];
  };

  users.users.${username} = {
    isNormalUser = true;
    description = username;
    extraGroups = [ "wheel" ];
    shell = pkgs.bash;
  };

  programs.bash.enable = true;

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = lib.mkDefault true;
    };
  };

  programs.nix-ld.enable = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  system.stateVersion = "25.11";
}
