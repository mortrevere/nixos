{
  pkgs,
  ...
}:

{
  programs.emacs = {
    enable = true;
    package = pkgs.emacs-pgtk;
    extraPackages =
      epkgs: with epkgs; [
        terraform-mode
        dockerfile-mode
        go-mode
        markdown-mode
        yaml-mode
        nix-mode
        json-mode
      ];
  };

  services.emacs = {
    enable = true;
    client.enable = true;
    defaultEditor = true;
  };

  # init.el is managed here; packages are provided by extraPackages above.
  # server-start and package management have been removed from init.el since
  # the daemon is handled by services.emacs and packages are handled by nix.
  home.file.".emacs.d/init.el" = {
    source = ../files/emacs-init.el;
  };
}
