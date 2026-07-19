nix shell nixpkgs#nixos-rebuild -c nixos-rebuild switch \
  --flake '.?submodules=1#red' \
  --target-host leo@10.0.0.19 \
  --build-host leo@10.0.0.19 \
  --sudo
