{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hardware.yubikey;

  # ykcs11 is shipped as part of yubico-piv-tool.
  ykcs11Module = "${pkgs.yubico-piv-tool}/lib/libykcs11.so";

  basePackages = with pkgs; [
    yubikey-manager # ykman
    yubico-piv-tool # piv tool + libykcs11
    opensc # pkcs11-tool, useful for inspection/testing
    pcsclite # pcsc_scan and client libs
  ];
in
{
  options.hardware.yubikey = {
    enable = lib.mkEnableOption "YubiKey userspace tooling and PC/SC support";

    installPackages = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install common YubiKey CLI tools into systemPackages.";
    };

    exposePkcs11Env = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose environment variables pointing at libykcs11.so.";
    };

    enableGnupgScdaemonWorkaround = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        If enabled, configures GnuPG scdaemon to use PC/SC instead of its
        internal CCID driver by setting disable-ccid. This helps on systems
        where pcscd should be the sole smartcard backend.
      '';
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Extra packages to install alongside the standard YubiKey toolset.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Smart-card daemon
    services.pcscd.enable = true;
    services.pcscd.plugins = [ pkgs.ccid ];

    # Useful CLI tools
    environment.systemPackages = lib.mkIf cfg.installPackages (basePackages ++ cfg.extraPackages);

    # Make the PKCS#11 module path easy to consume from shells and apps.
    environment.sessionVariables = lib.mkIf cfg.exposePkcs11Env {
      YKCS11_MODULE = ykcs11Module;
      PKCS11_MODULE_PATH = ykcs11Module;
    };

    # Optional: have gpg/scdaemon talk to the token via pcscd.
    #programs.gnupg.agent.enable = true;
    #programs.gnupg.agent.enableSSHSupport = true;

    environment.etc."gnupg/scdaemon.conf".text = lib.mkIf cfg.enableGnupgScdaemonWorkaround ''
      disable-ccid
    '';

    # A few shell conveniences for discovery/debugging.
    environment.shellAliases = {
      ykcs11-path = "echo ${lib.escapeShellArg ykcs11Module}";
      yk-piv-info = "pkcs11-tool --module ${lib.escapeShellArg ykcs11Module} --show-info";
      yk-piv-slots = "pkcs11-tool --module ${lib.escapeShellArg ykcs11Module} -O";
    };
  };
}
