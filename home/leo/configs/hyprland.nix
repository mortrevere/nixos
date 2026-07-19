{
  pkgs,
  lib,
  ...
}:

let
  terminal = "${pkgs.kitty}/bin/kitty";
  browser = "${pkgs.firefox}/bin/firefox";
  rofiCmd = "${pkgs.rofi}/bin/rofi";
  launcherCmd = "${rofiCmd} -show drun -show-icons";
in
{
  # Reload Hyprland after home-manager activation
  home.activation.reloadHyprland = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [[ -v HYPRLAND_INSTANCE_SIGNATURE ]]; then
      $DRY_RUN_CMD ${pkgs.hyprland}/bin/hyprctl reload || true
    fi
  '';

  xdg.configFile."hypr/hyprlock.conf".text = ''
    general {
      hide_cursor = true
      no_fade_in = false
    }

    background {
      monitor =
      color = rgb(31, 22, 38)
    }

    label {
      monitor =
      text = $TIME
      color = rgb(217, 250, 255)
      font_size = 72
      font_family = Noto Sans
      position = 0, 220
      halign = center
      valign = center
    }

    label {
      monitor =
      text = cmd[update:60000] echo "$(date '+%A %d %B %Y')"
      color = rgb(193, 184, 183)
      font_size = 20
      font_family = Noto Sans
      position = 0, 160
      halign = center
      valign = center
    }

    label {
      monitor =
      text = ──────
      color = rgb(218, 107, 171)
      font_size = 20
      font_family = Noto Sans
      position = 0, 120
      halign = center
      valign = center
    }

    input-field {
      monitor =
      size = 420, 56
      outline_thickness = 2

      dots_size = 0.22
      dots_spacing = 0.18
      dots_center = true

      outer_color = rgb(136, 60, 220)
      inner_color = rgba(0, 5, 6, 0.82)
      font_color = rgb(193, 184, 183)
      font_family = Noto Sans

      check_color = rgba(42, 178, 80, 0.95)
      fail_color = rgba(217, 64, 133, 0.95)
      capslock_color = rgba(234, 192, 102, 0.95)

      fade_on_empty = false
      placeholder_text = Password...
      hide_input = false
      rounding = 14

      position = 0, -320
      halign = center
      valign = center
    }
  '';

  xdg.configFile."hypr/hypridle.conf".text = ''
    general {
      lock_cmd = pidof hyprlock || hyprlock
      before_sleep_cmd = loginctl lock-session
      after_sleep_cmd = hyprctl dispatch dpms on
      ignore_dbus_inhibit = false
    }

    # Lock after 5 min
    listener {
      timeout = 300
      on-timeout = loginctl lock-session
    }

    # Turn screen off shortly after locking
    listener {
      timeout = 360
      on-timeout = hyprctl dispatch dpms off
      on-resume = hyprctl dispatch dpms on
    }

    # Suspend after 30 min
    listener {
      timeout = 1800
      on-timeout = systemctl suspend
    }
  '';

  xdg.configFile."hypr/scripts/launcher.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      exec rofi -show drun -show-icons
    '';
  };

  xdg.configFile."hypr/scripts/cliphist-rofi.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      cliphist list | rofi -dmenu -p "Clipboard" | cliphist decode | wl-copy
    '';
  };

  xdg.configFile."hypr/scripts/journal-rofi.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      JOURNAL_FILE="$HOME/journal/$(date +%Y-%m-%d).md"
      touch "$JOURNAL_FILE"

      # Show journal content as list; -format f returns the typed filter text, not the selected item
      result=$(cat "$JOURNAL_FILE" | rofi -dmenu \
        -p "$(date '+%Y-%m-%d') >" \
        -format f \
        -no-sort \
        -theme-str 'window { width: 44%; } listview { lines: 12; }')

      if [[ -n "$result" ]]; then
        echo "$(date '+%H:%M') $result" >> "$JOURNAL_FILE"
      fi
    '';
  };

  xdg.configFile."hypr/scripts/rename-kitty-tab.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      title=$(rofi -dmenu -p "Tab title" < /dev/null)
      sock=$(ls /tmp/kitty-socket-* 2>/dev/null | head -1)
      [ -n "$title" ] && [ -n "$sock" ] && kitty @ --to "unix:$sock" set-tab-title "$title"
    '';
  };

  xdg.configFile."hypr/scripts/dropdown-terminal.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      # Guake-like dropdown terminal for Hyprland

      if hyprctl clients | grep -q "class: dropdown-terminal"; then
        hyprctl dispatch togglespecialworkspace dropdown
      else
        # Restart the dropdown terminal if it was closed
        # Unset HYPRLAND_INSTANCE_SIGNATURE to prevent children from inheriting special workspace
        env -u HYPRLAND_INSTANCE_SIGNATURE ${terminal} --class dropdown-terminal &
        sleep 0.2
        hyprctl dispatch togglespecialworkspace dropdown
      fi
    '';
  };

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;

    settings = {
      "$mod" = "SUPER";
      "$terminal" = terminal;
      "$browser" = browser;

      # Single-monitor fallback.
      # Replace these with your real outputs after `hyprctl monitors`.
      monitor = [
        ",preferred,auto,1"

        # Example dual-monitor layout:
        # "eDP-1,1920x1080,0x0,1"
        # "HDMI-A-1,2560x1440,1920x0,1"
      ];

      env = [
        "HYPRSHOT_DIR,$HOME/Pictures"
      ];

      exec-once = [
        "hyprctl setcursor Bibata-Modern-Classic 24"
        "nm-applet --indicator"
        "blueman-applet"
        "mako"
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
        "playerctld daemon"
        "hypridle"
        "[workspace special:dropdown silent] env -u HYPRLAND_INSTANCE_SIGNATURE ${terminal} --class dropdown-terminal"
        "swaybg -i $(find ~/nixos/wallpapers -name '*.jpg' | shuf -n 1) -m fill"
        "touchpad-hscroll"
        "battery-notify"
        "[workspace 1 silent] firefox"
        "[workspace 3 silent] emacsclient -c -a ''"
      ];

      input = {
        kb_layout = "fr";
        follow_mouse = 1;
        sensitivity = 0;
        resolve_binds_by_sym = 1;
        float_switch_override_focus = 2;
      };

      general = {
        gaps_in = 4;
        gaps_out = 6;
        border_size = 0;
        resize_on_border = false;
        allow_tearing = false;
        layout = "dwindle";
      };

      # Workspace rules - no gaps for dropdown terminal
      workspace = [
        "special:dropdown, gapsout:0, gapsin:0, border:false"
      ];

      decoration = {
        rounding = 0;
        active_opacity = 1.0;
        inactive_opacity = 1.0;
        shadow.enabled = false;
        blur.enabled = false;
      };

      animations.enabled = false;

      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };

      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
      };

      # XFCE-like mouse behavior
      bindm = [
        "ALT, mouse:272, movewindow"
        "ALT, mouse:273, resizewindow"
      ];

      bind = [
        # apps
        "$mod, RETURN, exec, $terminal"
        "$mod, B, exec, rfkill toggle bluetooth"
        "$mod, D, exec, ${launcherCmd}"
        "$mod, R, exec, ${rofiCmd} -show run"
        "$mod, A, exec, ~/.config/hypr/scripts/journal-rofi.sh"
        "$mod, C, exec, ~/.config/hypr/scripts/cliphist-rofi.sh"
        "$mod, T, exec, ~/.config/hypr/scripts/rename-kitty-tab.sh"
        "$mod, H, exec, ~/.local/bin/keybind-cheatsheet"
        "$mod, N, exec, ~/.local/bin/toggle-notifications"

        # session
        "$mod SHIFT, Q, killactive"
        "ALT, F4, killactive"
        "$mod SHIFT, E, exit"
        "$mod, L, exec, hyprlock"
        "$mod, F, fullscreen, 0"
        "$mod, V, togglefloating"
        "$mod, P, pseudo"
        "$mod, S, swapactiveworkspaces, 0 1"

        # focus
        "ALT, Tab, cyclenext, floating"
        "ALT, Tab, bringactivetotop"
        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"

        # move windows
        "$mod SHIFT, left, movewindow, l"
        "$mod SHIFT, right, movewindow, r"
        "$mod SHIFT, up, movewindow, u"
        "$mod SHIFT, down, movewindow, d"

        # workspaces on FR AZERTY
        "$mod, ampersand, workspace, 1"
        "$mod, eacute, workspace, 2"
        "$mod, quotedbl, workspace, 3"
        "$mod, apostrophe, workspace, 4"
        "$mod, parenleft, workspace, 5"

        # workspace navigation
        "CTRL ALT, code:113, workspace, e-1"
        "CTRL ALT, code:114, workspace, e+1"

        "$mod SHIFT, ampersand, movetoworkspace, 1"
        "$mod SHIFT, eacute, movetoworkspace, 2"
        "$mod SHIFT, quotedbl, movetoworkspace, 3"
        "$mod SHIFT, apostrophe, movetoworkspace, 4"
        "$mod SHIFT, parenleft, movetoworkspace, 5"

        # dropdown terminal
        ", twosuperior, exec, ~/.config/hypr/scripts/dropdown-terminal.sh"

        # screenshots
        ", Print, exec, hyprshot -m region"
        "SHIFT, Print, exec, ~/.local/bin/screenshot-gimp"
        "CTRL, Print, exec, hyprshot -m window"

        # media keys
        ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioPause, exec, playerctl pause"
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPrev, exec, playerctl previous"

        # brightness (minimum 4%)
        ", XF86MonBrightnessUp, exec, brightnessctl set +10%"
        ", XF86MonBrightnessDown, exec, brightnessctl set 10%- -n 4%"
      ];

      # Resize tiled windows (repeatable)
      binde = [
        "$mod ALT, left, resizeactive, -30 0"
        "$mod ALT, right, resizeactive, 30 0"
        "$mod ALT, up, resizeactive, 0 -30"
        "$mod ALT, down, resizeactive, 0 30"
      ];

      # Let a few binds work even while hyprlock is active.
      bindl = [
        ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPrev, exec, playerctl previous"
        ", XF86MonBrightnessUp, exec, brightnessctl set +10%"
        ", XF86MonBrightnessDown, exec, brightnessctl set 10%- -n 4%"
      ];

      windowrulev2 = [
        # Default for all windows: floating with margins (32px on all sides)
        "float, class:.*"
        "size 1888 1138, class:.*"
        "move 16 46, class:.*"

        # Keep the initial Firefox and Emacs windows tiled on launch.
        "tile, class:^(firefox)$"
        "tile, class:^(emacs)$"

        "workspace special:dropdown silent, class:dropdown-terminal"
        #"float, class:dropdown-terminal"
        #"size 100% 100%, class:dropdown-terminal"
        #"move 0 30, class:dropdown-terminal"
        # Dropdown terminal rules (Guake-like) - NOT floating
        #"workspace special:dropdown silent, class:dropdown-terminal"
        #"size 100% 100%, class:dropdown-terminal"
        #"move 0 30, class:dropdown-terminal"
        #"stayfocused, class:dropdown-terminal"

        # Override: dropdown terminal should NOT float
        "tile, class:dropdown-terminal"

        # Emacs always opens on workspace 3
        "workspace 3 silent, class:emacs"
      ];

    };
  };
}
