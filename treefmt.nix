_: {
  projectRootFile = "flake.nix";

  programs.nixfmt.enable = true;

  # Optional but recommended once you want broader repo coverage:
  programs.shfmt.enable = true;
  programs.prettier.enable = true;
  programs.deadnix.enable = true;
  programs.statix.enable = true;

  settings.global.excludes = [
    ".direnv"
    "result"
    "result-*"
  ];
}
