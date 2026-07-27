{ config, lib, ... }:

{
  options.hardware.backlight.bootBrightnessPercent = lib.mkOption {
    type = lib.types.ints.between 1 100;
    default = 1;
    description = "Backlight brightness percentage to apply at boot.";
  };

  config = {
    systemd.services.backlight-boot-brightness = {
      description = "Set laptop backlight brightness at boot";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-udev-settle.service" ];
      wants = [ "systemd-udev-settle.service" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        percent=${toString config.hardware.backlight.bootBrightnessPercent}

        for device in /sys/class/backlight/*; do
          [ -e "$device/brightness" ] || continue
          [ -r "$device/max_brightness" ] || continue
          [ -w "$device/brightness" ] || continue

          max="$(cat "$device/max_brightness")"
          case "$max" in
            "" | *[!0-9]*)
              continue
              ;;
          esac

          target=$(( (max * percent + 99) / 100 ))
          [ "$target" -ge 1 ] || target=1

          echo "$target" > "$device/brightness"
        done
      '';
    };
  };
}
