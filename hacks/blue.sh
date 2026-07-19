nix shell nixpkgs#nixos-rebuild -c nixos-rebuild switch \
  --flake '.?submodules=1#blue' \
  --target-host leo@10.0.0.30 \
  --build-host leo@10.0.0.30 \
  --sudo
