nix shell nixpkgs#nixos-rebuild -c nixos-rebuild switch \
  --flake '.?submodules=1#black' \
  --target-host leo@black.house.leo.surf \
  --build-host leo@black.house.leo.surf \
  --sudo
