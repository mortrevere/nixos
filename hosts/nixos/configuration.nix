_:

{
  imports = [
    ../../modules/base.nix
    ../../modules/laptop.nix
    ../../modules/features/k3s-local.nix
    ../../modules/features/keyd-external75.nix
    ../../modules/features/keyd-cherry.nix
    ../../modules/features/yubikey.nix
    ./hardware-configuration.nix
  ]
  ++ (if builtins.pathExists ./private.nix then [ ./private.nix ] else [ ]);

  hardware.yubikey = {
    enable = true;
    enableGnupgScdaemonWorkaround = true;
  };
}
