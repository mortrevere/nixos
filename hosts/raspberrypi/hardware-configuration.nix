_: {
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };

  fileSystems."/boot/firmware" = {
    device = "/dev/disk/by-label/FIRMWARE";
    fsType = "vfat";
    options = [ "umask=0077" ];
  };

  hardware.raspberry-pi.config.all.options = {
    hdmi_force_hotplug = {
      enable = true;
      value = true;
    };
    hdmi_group = {
      enable = true;
      value = 1;
    };
    hdmi_mode = {
      enable = true;
      value = 31;
    };
  };
}
