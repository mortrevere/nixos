{
  pkgs,
  ...
}:

let
  pythonWithEvdev = pkgs.python3.withPackages (ps: [ ps.evdev ]);
in
{
  # Clipboard utilities (Wayland)
  home.file.".local/bin/setclip" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      if [ "$#" -gt 0 ]; then
        printf '%s' "$*" | wl-copy
      else
        wl-copy
      fi
    '';
  };

  home.file.".local/bin/getclip" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      wl-paste --no-newline
    '';
  };

  home.file.".local/bin/screenshot-gimp" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      mkdir -p ~/Pictures
      filename=~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png
      grim "$filename" && gimp "$filename"
    '';
  };

  # Seeded deterministic password generator.
  # Usage: kgb <length> <seed> [ns|mayhem]
  home.file.".local/bin/kgb" = {
    executable = true;
    source = ../files/kgb.py;
  };

  # Encrypted secret manager using ecryptfs.
  # Requires ecryptfs support (already in configuration.nix) and must be run as root (sudo secret-mgr).
  # Mounts ~/secret/ and auto-locks after 1 minute.
  home.file.".local/bin/secret-mgr" = {
    executable = true;
    source = ../files/secret-mgr.py;
  };

  # Battery low: escalating notifications from 10% (1 notif) down to 1% (10 notifs).
  home.file.".local/bin/battery-notify" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      PREV_LEVEL=""
      while true; do
        bat_path=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1)
        if [[ -z "$bat_path" ]]; then
          sleep 60
          continue
        fi

        capacity=$(cat "$bat_path/capacity")
        status=$(cat "$bat_path/status")

        if [[ "$status" != "Charging" && "$status" != "Full" \
              && "$capacity" -le 10 && "$capacity" != "$PREV_LEVEL" ]]; then
          count=$((11 - capacity))
          for ((i = 0; i < count; i++)); do
            ${pkgs.libnotify}/bin/notify-send -u critical "Battery low !"
          done
          PREV_LEVEL="$capacity"
        fi

        # Reset when charging so notifications fire again after re-unplug
        if [[ "$status" == "Charging" || "$status" == "Full" ]]; then
          PREV_LEVEL=""
        fi

        sleep 60
      done
    '';
  };

  # 3-finger touchpad swipe → horizontal scroll.
  # Adjust SCROLL_DIVISOR in the .py file for sensitivity.
  home.file.".local/bin/touchpad-hscroll" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      exec ${pythonWithEvdev}/bin/python3 ${../files/touchpad-hscroll.py} "$@"
    '';
  };

  # Keybind cheatsheet: dynamically list all Hyprland binds in rofi.
  home.file.".local/bin/keybind-cheatsheet" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      hyprctl binds -j | ${pkgs.jq}/bin/jq -r '
        # readable modifier flags
        def mod_names:
          [ if . % 2 == 1           then "SUPER" else empty end,
            if (. / 4 | floor) % 2 == 1 then "ALT"   else empty end,
            if (. / 2 | floor) % 2 == 1 then "SHIFT" else empty end,
            if (. / 8 | floor) % 2 == 1 then "CTRL"  else empty end
          ] | join(" + ");

        .[] |
        (.modmask | mod_names) as $mods |
        (if $mods == "" then .key else "\($mods) + \(.key)" end) as $combo |
        (.dispatcher) as $action |
        (.arg // "") as $arg |
        if $arg != "" then "\($combo)  →  \($action) \($arg)"
        else "\($combo)  →  \($action)" end
      ' | sort -u | ${pkgs.rofi}/bin/rofi -dmenu -i -p "Keybinds" -no-custom
    '';
  };

  # Toggle mako Do Not Disturb mode and signal waybar to refresh.
  home.file.".local/bin/toggle-notifications" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      makoctl reload
      makoctl mode -t do-not-disturb
      pkill -SIGRTMIN+8 waybar
    '';
  };

  # Output DND icon for waybar when notifications are silenced.
  home.file.".local/bin/dnd-status" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      if makoctl mode | grep -q do-not-disturb; then
        echo '{"text": "󰂛", "class": "active"}'
      else
        echo '{"text": "", "class": ""}'
      fi
    '';
  };
}
