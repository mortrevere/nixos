{
  pkgs,
  ...
}:

{
  # ydotool: uinput-level key injection tool used by paste-horizon.
  # See programs.ydotool in modules/laptop.nix for the required
  # ydotoold service/group.
  home.packages = with pkgs; [
    ydotool
  ];

  # paste-horizon: autotypes the content of a file after a short delay.
  # Usage: paste-horizon <file>
  # Useful for sending passwords to remote VMs (e.g. paste-horizon ~/secret/mypass).
  # Edit files/paste-horizon.py to configure character remapping for VMs with a
  # different keyboard layout.
  home.file.".local/bin/paste-horizon" = {
    executable = true;
    source = ../files/paste-horizon.py;
  };
}
