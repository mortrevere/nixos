nix shell nixpkgs#nixos-rebuild -c nixos-rebuild switch \
  --flake '.?submodules=1#red' \
  --target-host leo@red.house.leo.surf \
  --build-host leo@red.house.leo.surf \
  --sudo
