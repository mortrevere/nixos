nix shell nixpkgs#nixos-rebuild -c nixos-rebuild switch \
  --flake '.?submodules=1#blue' \
  --target-host leo@blue.house.leo.surf \
  --build-host leo@blue.house.leo.surf \
  --sudo
