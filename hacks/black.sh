nix shell nixpkgs#nixos-rebuild -c nixos-rebuild switch \
  --flake '.?submodules=1#black' \
  --target-host leo@10.0.0.29 \
  --build-host leo@10.0.0.29 \
  --sudo
