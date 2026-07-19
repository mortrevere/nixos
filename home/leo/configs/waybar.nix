{
  pkgs,
  lib,
  ...
}:

{
  # Reload waybar after home-manager activation
  home.activation.reloadWaybar = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD pkill waybar || true
    $DRY_RUN_CMD ${pkgs.systemd}/bin/systemctl --user restart waybar.service || true
  '';

  programs.waybar = {
    enable = true;
    systemd.enable = true;
  };

  xdg.configFile."waybar/config".text = ''
      {
        "layer": "top",
        "position": "top",
        "height": 30,
        "spacing": 4,

        "modules-left": ["custom/start", "hyprland/workspaces"],
        "modules-center": ["wlr/taskbar"],
        "modules-right": ["custom/dnd", "custom/weather", "cpu", "temperature", "memory", "backlight", "pulseaudio", "bluetooth", "network", "battery", "tray", "clock"],

        "custom/start": {
          "format": "🍉 Menu",
          "tooltip": false,
          "on-click": "~/.config/hypr/scripts/launcher.sh"
        },

    "hyprland/workspaces": {
      "active-only": true,
      "all-outputs": false,
      "format": "{name}",
      "show-special": false,
      "sort-by": "id",
      "workspace-taskbar": {
        "enable": true,
        "icon-size": 18,
        "icon-theme": "Papirus-Dark",
        "spacing": 2,
        "update-active-window": true
      }
    },

        "wlr/taskbar": {
          "format": "{icon}",
          "icon-size": 18,
          "icon-theme": "Papirus-Dark",
          "tooltip-format": "{title}",
          "on-click": "activate",
          "on-click-middle": "close",
          "ignore-list": [
            "dropdown-terminal"
          ]
        },

        "hyprland/window": {
          "format": "{}",
          "separate-outputs": true,
          "max-length": 90
        },

        "custom/dnd": {
          "exec": "~/.local/bin/dnd-status",
          "return-type": "json",
          "interval": 5,
          "signal": 8,
          "on-click": "~/.local/bin/toggle-notifications"
        },

        "cpu": {
          "format": "󰍛 {usage}%"
        },

        "temperature": {
          "hwmon-path-abs": "/sys/devices/platform/coretemp.0/hwmon",
          "input-filename": "temp1_input",
          "format": "󰔏 {temperatureC}°C",
          "critical-threshold": 80,
          "format-critical": "󱃂 {temperatureC}°C",
          "tooltip": true
        },

        "memory": {
          "format": "󰘚 {}%"
        },

        "backlight": {
          "format": "󰃠 {percent}%"
        },

        "pulseaudio": {
          "format": "󰕾 {volume}%",
          "format-muted": "󰖁 muted",
          "on-click": "pavucontrol"
        },

        "bluetooth": {
          "format": "󰂯 {status}",
          "format-connected": "󰂯 {device_alias}",
          "format-connected-battery": "󰂯 {device_alias} {device_battery_percentage}%",
          "format-disabled": "󰂲 off",
          "format-off": "󰂲 off",
          "tooltip-format": "{controller_alias}\t{controller_address}\n\n{num_connections} connected",
          "tooltip-format-connected": "{controller_alias}\t{controller_address}\n\n{num_connections} connected\n\n{device_enumerate}",
          "tooltip-format-enumerate-connected": "{device_alias}\t{device_address}",
          "tooltip-format-enumerate-connected-battery": "{device_alias}\t{device_address}\t{device_battery_percentage}%",
          "on-click": "blueman-manager"
        },

        "custom/weather": {
          "exec": "${pkgs.curl}/bin/curl -sf 'https://api.open-meteo.com/v1/forecast?latitude=48.1173&longitude=-1.6778&current_weather=true' | ${pkgs.jq}/bin/jq -r '\"󰖐 \" + (.current_weather.temperature | tostring) + \"°C\"'",
          "interval": 300,
          "tooltip": false
        },

        "network": {
          "format-wifi": "󰖩 {essid}",
          "format-ethernet": "󰈀 ethernet",
          "format-disconnected": "󰖪 offline",
          "on-click": "nm-connection-editor"
        },

        "battery": {
          "format": "󰁹 {capacity}%",
          "format-charging": "󰂄 {capacity}%"
        },

        "tray": {
          "spacing": 8
        },

        "clock": {
          "interval": 1,
          "format": "{:%d-%m-%Y %H:%M:%S}"
        }
      }
  '';

  xdg.configFile."waybar/style.css".text = ''
    * {
      border: none;
      border-radius: 0;
      font-family: "Iosevka Term", "Symbols Nerd Font", "Font Awesome 6 Free", sans-serif;
      font-size: 13px;
      min-height: 0;
    }

    window#waybar {
      background: #1f1626;
      color: #d9faff;
    }

    #custom-start {
      padding: 0 12px;
      background: #d94085;
      color: #fff8dd;
      font-weight: 600;
    }

    #workspaces button {
      padding: 0 8px;
      color: #d9faff;
    }

    #workspaces button.active {
      background: #883cdc;
      color: #fff8dd;
    }

    #window,
    #clock,
    #cpu,
    #temperature,
    #memory,
    #backlight,
    #bluetooth,
    #network,
    #pulseaudio,
    #battery,
    #tray,
    #custom-weather {
      padding: 0 10px;
    }

    #temperature.critical {
      color: #d94085;
    }

    #custom-dnd {
      padding: 0 10px;
      color: #d94085;
    }

    #custom-dnd.active {
      color: #d94085;
    }
  '';
}
