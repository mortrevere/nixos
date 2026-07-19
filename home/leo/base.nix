{
  config,
  username,
  ...
}:

{
  imports = [
    ./configs/shell.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  services.ssh-agent.enable = true;
  programs.fastfetch.enable = true;
  # Keep generated caches out of the persistent home directory.
  xdg.cacheHome = "/tmp/.cache-${config.home.username}";
}
