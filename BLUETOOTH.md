# Bluetooth Setup

## What's Implemented

I've added a complete Bluetooth stack to your NixOS Hyprland setup:

### System Level (`modules/laptop.nix`)

- **hardware.bluetooth**: Bluetooth hardware support enabled
  - Powers on automatically at boot
  - Experimental features enabled for better compatibility
  - All audio profiles enabled (A2DP, HSP/HFP)
- **services.blueman**: Blueman daemon for device management

### User Level (`home/leo/laptop.nix`)

- **blueman**: GUI package for Bluetooth management
- **blueman-applet**: System tray applet (auto-starts in Hyprland)
- **Waybar module**: Bluetooth status widget in your panel

## Usage

### Via Waybar (Recommended)

Click the Bluetooth icon (󰂯/󰂲) in Waybar to open **blueman-manager**:

- Search for devices
- Pair and connect devices
- Switch audio profiles (A2DP, HSP, HFP)
- Manage trusted devices
- View battery levels (when supported)

### Via System Tray

The blueman-applet icon in your tray provides quick access to:

- Connected devices
- Quick connect/disconnect
- Device settings

### Waybar Widget Features

- Shows connection status
- Displays connected device name
- Shows device battery percentage (when available)
- Different icons for on/off/connected states
- Tooltip shows all connected devices

## Applying Changes

```bash
sudo nixos-rebuild switch --flake '.?submodules=1#nixos'
```

Or use the `rebuild` alias from `home/leo/configs/shell.nix`:

```bash
rebuild
```

After rebuild, log out and back in (or restart Hyprland) to ensure everything starts properly.

## Troubleshooting

### Bluetooth not working

```bash
# Check Bluetooth status
systemctl status bluetooth

# Restart Bluetooth service
sudo systemctl restart bluetooth
```

### Applet not showing

```bash
# Manually start blueman-applet
blueman-applet &

# Or restart Waybar
pkill waybar
waybar &
```

### Device won't connect

- Open blueman-manager (click Waybar icon)
- Right-click device → "Pair" then "Trust"
- For audio: Right-click → "Audio Profile" → Select appropriate profile

## Audio Profiles

- **A2DP Sink**: High quality stereo (music/media)
- **HSP/HFP**: Lower quality with microphone (calls/headset)
- Switch profiles in blueman-manager by right-clicking the device

## Why Blueman?

Blueman is the most reliable Bluetooth solution for Wayland/Hyprland:

- Native GTK UI (matches your Adwaita-dark theme)
- Full D-Bus integration with BlueZ
- Comprehensive device management
- Excellent audio profile support
- System tray integration
- Works perfectly with Waybar
