{
  pkgs,
  lib,
  ...
}:

let
  terminal = "${pkgs.kitty}/bin/kitty";
  rofiCmd = "${pkgs.rofi}/bin/rofi";
  launcherCmd = "${rofiCmd} -show drun -show-icons";
  lua = lib.generators.mkLuaInline;
  bindWith = key: action: flags: {
    _args = [
      key
      (lua action)
      ({ description = lib.replaceStrings [ "\n" ] [ " " ] action; } // flags)
    ];
  };
  bind = key: action: bindWith key action { };
  exec =
    key: command:
    bindWith key "hl.dsp.exec_cmd(${builtins.toJSON command})" {
      description = command;
    };
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
      after_sleep_cmd = hyprctl dispatch 'hl.dsp.dpms({ action = "on" })'
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
      on-timeout = hyprctl dispatch 'hl.dsp.dpms({ action = "off" })'
      on-resume = hyprctl dispatch 'hl.dsp.dpms({ action = "on" })'
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
      sock=$(ls /tmp/kitty-socket-* 2>/dev/null | sort -t- -k3 -n | head -1)
      [ -n "$title" ] && [ -n "$sock" ] && kitty @ --to "unix:$sock" set-tab-title "$title"
    '';
  };

  xdg.configFile."hypr/scripts/dropdown-terminal.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      # Guake-like dropdown terminal for Hyprland

      if hyprctl clients | grep -q "class: dropdown-terminal"; then
        hyprctl dispatch 'hl.dsp.workspace.toggle_special("dropdown")'
      else
        # Restart the dropdown terminal if it was closed
        # Unset HYPRLAND_INSTANCE_SIGNATURE to prevent children from inheriting special workspace
        env -u HYPRLAND_INSTANCE_SIGNATURE ${terminal} --class dropdown-terminal &
        sleep 0.2
        hyprctl dispatch 'hl.dsp.workspace.toggle_special("dropdown")'
      fi
    '';
  };

  # Replace the default Lua config generated by Hyprland during the upgrade.
  xdg.configFile."hypr/hyprland.lua".force = true;

  wayland.windowManager.hyprland = {
    enable = true;
    configType = "lua";
    systemd.enable = true;
    importantPrefixes = [
      "config"
      "env"
      "monitor"
    ];

    settings = {
      monitor = {
        output = "";
        mode = "preferred";
        position = "auto";
        scale = 1;
      };

      env._args = [
        "HYPRSHOT_DIR"
        (lua ''os.getenv("HOME") .. "/Pictures"'')
      ];

      config = {
        input = {
          kb_layout = "fr";
          follow_mouse = 1;
          sensitivity = 0;
          resolve_binds_by_sym = true;
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

        decoration = {
          rounding = 0;
          active_opacity = 1.0;
          inactive_opacity = 1.0;
          shadow.enabled = false;
          blur.enabled = false;
        };

        animations.enabled = false;
        dwindle.preserve_split = true;
        misc = {
          disable_hyprland_logo = true;
          disable_splash_rendering = true;
        };
      };

      workspace_rule = {
        workspace = "special:dropdown";
        gaps_out = 0;
        gaps_in = 0;
        no_border = true;
      };

      # The start event runs once per session, rather than on every config reload.
      on._args = [
        "hyprland.start"
        (lua ''
          function()
            hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 24")
            hl.exec_cmd("nm-applet --indicator")
            hl.exec_cmd("blueman-applet")
            hl.exec_cmd("mako")
            hl.exec_cmd("wl-paste --type text --watch cliphist store")
            hl.exec_cmd("wl-paste --type image --watch cliphist store")
            hl.exec_cmd("playerctld daemon")
            hl.exec_cmd("hypridle")
            hl.exec_cmd(${builtins.toJSON "env -u HYPRLAND_INSTANCE_SIGNATURE ${terminal} --class dropdown-terminal"}, { workspace = "special:dropdown silent" })
            hl.exec_cmd("swaybg -i $(find ~/nixos/wallpapers -name '*.jpg' | shuf -n 1) -m fill")
            hl.exec_cmd("touchpad-hscroll")
            hl.exec_cmd("battery-notify")
            hl.exec_cmd("firefox", { workspace = "1 silent" })
            hl.exec_cmd(${builtins.toJSON "emacsclient -c -a ''"}, { workspace = "3 silent" })
          end
        '')
      ];

      bind = [
        # Apps
        (exec "SUPER + RETURN" terminal)
        (exec "SUPER + B" "~/.local/bin/toggle-bluetooth")
        (exec "SUPER + D" launcherCmd)
        (exec "SUPER + R" "${rofiCmd} -show run")
        (exec "SUPER + A" "~/.config/hypr/scripts/journal-rofi.sh")
        (exec "SUPER + C" "~/.config/hypr/scripts/cliphist-rofi.sh")
        (exec "SUPER + T" "~/.config/hypr/scripts/rename-kitty-tab.sh")
        (exec "SUPER + H" "~/.local/bin/keybind-cheatsheet")
        (exec "SUPER + N" "~/.local/bin/toggle-notifications")

        # Session
        (bind "SUPER + SHIFT + Q" "hl.dsp.window.close()")
        (bind "ALT + F4" "hl.dsp.window.close()")
        (bind "SUPER + SHIFT + E" "hl.dsp.exit()")
        (exec "SUPER + L" "hyprlock")
        (bind "SUPER + F" ''hl.dsp.window.fullscreen({ mode = "fullscreen" })'')
        (bind "SUPER + V" "hl.dsp.window.float()")
        (bind "SUPER + P" "hl.dsp.window.pseudo()")
        (bind "SUPER + S" "hl.dsp.workspace.swap_monitors({ monitor1 = 0, monitor2 = 1 })")

        # Focus and move windows
        (bind "ALT + Tab" ''
          function()
                    hl.dispatch(hl.dsp.window.cycle_next({ floating = true }))
                    hl.dispatch(hl.dsp.window.bring_to_top())
                  end'')
        (bind "SUPER + left" ''hl.dsp.focus({ direction = "left" })'')
        (bind "SUPER + right" ''hl.dsp.focus({ direction = "right" })'')
        (bind "SUPER + up" ''hl.dsp.focus({ direction = "up" })'')
        (bind "SUPER + down" ''hl.dsp.focus({ direction = "down" })'')
        (bind "SUPER + SHIFT + left" ''hl.dsp.window.move({ direction = "left" })'')
        (bind "SUPER + SHIFT + right" ''hl.dsp.window.move({ direction = "right" })'')
        (bind "SUPER + SHIFT + up" ''hl.dsp.window.move({ direction = "up" })'')
        (bind "SUPER + SHIFT + down" ''hl.dsp.window.move({ direction = "down" })'')

        # Workspaces on French AZERTY
        (bind "SUPER + ampersand" "hl.dsp.focus({ workspace = 1 })")
        (bind "SUPER + eacute" "hl.dsp.focus({ workspace = 2 })")
        (bind "SUPER + quotedbl" "hl.dsp.focus({ workspace = 3 })")
        (bind "SUPER + apostrophe" "hl.dsp.focus({ workspace = 4 })")
        (bind "SUPER + parenleft" "hl.dsp.focus({ workspace = 5 })")
        (bind "CTRL + ALT + code:113" ''hl.dsp.focus({ workspace = "e-1" })'')
        (bind "CTRL + ALT + code:114" ''hl.dsp.focus({ workspace = "e+1" })'')
        (bind "SUPER + SHIFT + ampersand" "hl.dsp.window.move({ workspace = 1, follow = true })")
        (bind "SUPER + SHIFT + eacute" "hl.dsp.window.move({ workspace = 2, follow = true })")
        (bind "SUPER + SHIFT + quotedbl" "hl.dsp.window.move({ workspace = 3, follow = true })")
        (bind "SUPER + SHIFT + apostrophe" "hl.dsp.window.move({ workspace = 4, follow = true })")
        (bind "SUPER + SHIFT + parenleft" "hl.dsp.window.move({ workspace = 5, follow = true })")

        # Dropdown terminal and screenshots
        (bindWith "twosuperior" ''
          function()
                    if #hl.get_windows({ class = "dropdown-terminal" }) == 0 then
                      hl.exec_cmd(${builtins.toJSON "env -u HYPRLAND_INSTANCE_SIGNATURE ${terminal} --class dropdown-terminal"}, { workspace = "special:dropdown silent" })
                    end
                    hl.dispatch(hl.dsp.workspace.toggle_special("dropdown"))
                  end'' { description = "Toggle dropdown terminal"; })
        (exec "Print" "hyprshot -m region")
        (exec "SHIFT + Print" "~/.local/bin/screenshot-gimp")
        (exec "CTRL + Print" "hyprshot -m window")

        # Mouse and repeatable resize shortcuts
        (bindWith "ALT + mouse:272" "hl.dsp.window.drag()" { mouse = true; })
        (bindWith "ALT + mouse:273" "hl.dsp.window.resize()" { mouse = true; })
        (bindWith "SUPER + ALT + left" "hl.dsp.window.resize({ x = -30, y = 0, relative = true })" {
          repeating = true;
        })
        (bindWith "SUPER + ALT + right" "hl.dsp.window.resize({ x = 30, y = 0, relative = true })" {
          repeating = true;
        })
        (bindWith "SUPER + ALT + up" "hl.dsp.window.resize({ x = 0, y = -30, relative = true })" {
          repeating = true;
        })
        (bindWith "SUPER + ALT + down" "hl.dsp.window.resize({ x = 0, y = 30, relative = true })" {
          repeating = true;
        })
      ]
      ++
        map
          (
            entry:
            bindWith entry.key "hl.dsp.exec_cmd(${builtins.toJSON entry.command})" (
              { description = entry.command; } // entry.flags
            )
          )
          [
            {
              key = "XF86AudioRaiseVolume";
              command = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
              flags.locked = true;
            }
            {
              key = "XF86AudioLowerVolume";
              command = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
              flags = { };
            }
            {
              key = "XF86AudioMute";
              command = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
              flags.locked = true;
            }
            {
              key = "XF86AudioMicMute";
              command = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
              flags = { };
            }
            {
              key = "XF86AudioPlay";
              command = "playerctl play-pause";
              flags.locked = true;
            }
            {
              key = "XF86AudioPause";
              command = "playerctl pause";
              flags = { };
            }
            {
              key = "XF86AudioNext";
              command = "playerctl next";
              flags.locked = true;
            }
            {
              key = "XF86AudioPrev";
              command = "playerctl previous";
              flags.locked = true;
            }
            {
              key = "XF86MonBrightnessUp";
              command = "brightnessctl set +10%";
              flags.locked = true;
            }
            {
              key = "XF86MonBrightnessDown";
              command = "brightnessctl set 10%- -n 4%";
              flags.locked = true;
            }
          ];

      window_rule = [
        {
          name = "default-floating";
          match.class = ".*";
          float = true;
          size = "1888 1138";
          move = "16 46";
        }
        {
          name = "firefox-tiled";
          match.class = "^(firefox)$";
          tile = true;
        }
        {
          name = "emacs-tiled";
          match.class = "^(emacs)$";
          tile = true;
          workspace = "3 silent";
        }
        {
          name = "dropdown-terminal";
          match.class = "dropdown-terminal";
          tile = true;
          workspace = "special:dropdown silent";
        }
      ];
    };
  };
}
