# NixOS Configuration

NixOS + Hyprland setup inspired by an XFCE/Xubuntu workflow, with headless
server hosts.

## Structure

- **flake.nix** - Entry point. Declares hosts (`nixos`, `red`, `black`, `blue`)
  and wires their system/home modules; also exposes the `treefmt` formatter.
- **modules/base.nix** - Shared NixOS base for every machine: user `leo`, locale,
  Nix settings, SSH, Podman, CLI basics.
- **modules/laptop.nix** - Graphical laptop/workstation profile: Hyprland, greetd,
  audio, Bluetooth, NetworkManager, Tailscale, GUI packages.
- **modules/server.nix** - Headless server profile and common container reverse proxy.
- **modules/features/home-server.nix** - Shared server Wi-Fi, nftables, CoreDNS,
  node exporter, and USB data-drive mounting; hosts provide only their deltas.
- **modules/features/** - Optional reusable system features: `k3s-local.nix` /
  `k3s-control-plane.nix` (single-node vs. control-plane k3s), `keyd-external75.nix`
  / `keyd-cherry.nix` (per-keyboard remaps), `home-dns.nix`, `tailscale.nix`,
  `yubikey.nix`.
- **hosts/nixos/** - Work laptop: imports `base` + `laptop` + `k3s-local` +
  both keyd remaps + `yubikey`, plus its `hardware-configuration.nix`.
- **hosts/red/** - Home gateway and monitoring server: DHCP/NordVPN plus
  Grafana, Prometheus, links, Hyperion, and Nabu containers.
- **hosts/black/** - Registry and backup server, deployed at `10.0.0.29`.
- **hosts/blue/** - Media server with Transmission and Jellyfin, deployed at
  `10.0.0.30`.
- **home/leo/base.nix** - Shared Home Manager base for user `leo`.
- **home/leo/laptop.nix** - Laptop Home Manager profile: Hyprland, Firefox,
  Waybar, Rofi, Mako, theming, scripts.
- **home/leo/server.nix** - Server Home Manager profile.
- **home/leo/configs/** - Reusable Home Manager config modules (Hyprland, Waybar,
  Rofi, Mako, Kitty, shell aliases/functions, Emacs, Kubernetes tooling, Firefox,
  scripts, per-host bash prompts, containerized Copilot CLI wrapper, paste-horizon).
- **home/leo/files/** - Managed non-Nix files sourced by Home Manager modules
  (Emacs init, standalone Python scripts, etc.).
- **treefmt.nix** - Formatter config (`nixfmt`, `shfmt`, `prettier`, `deadnix`,
  `statix`), run via `nix fmt`.
- **hacks/red.sh**, **hacks/black.sh**, **hacks/blue.sh** - Remote deploy
  helpers for server hosts over SSH.
- **gen-config.sh** - Wrapper around `nixos-generate-config` to (re)generate a
  host's `hardware-configuration.nix`.
- **setup-secret-dir.sh** - One-time setup of the gocryptfs-based `~/secret`
  encrypted directory.
- **BLUETOOTH.md** - Notes on the Bluetooth stack.

## Key Features

### Window Manager

- **Hyprland** - Wayland compositor with XFCE-inspired workflow
- Minimalist aesthetics (no animations, no blur, no rounding)
- Alt+drag window management like XFCE

### Applications

- **Emacs** (PGTK) - Default editor, managed as a daemon via `services.emacs`
- **Firefox** - Web browser
- **Kitty** - Terminal emulator

### Desktop Environment

- **Waybar** - Top bar with system information
- **Rofi** - Application launcher and runner
- **Mako** - Notification daemon
- **Hyprlock/Hypridle** - Screen locking and idle management

### Utilities

- Clipboard history (cliphist)
- Screenshots (hyprshot)
- Brightness control (brightnessctl)
- Audio control (pipewire/wireplumber)
- Network management (NetworkManager)
- Bluetooth (see `BLUETOOTH.md`)
- YubiKey (GPG/SSH via `modules/features/yubikey.nix`)
- Per-keyboard remaps via `keyd` (`keyd-external75.nix`, `keyd-cherry.nix`)
- gocryptfs-encrypted secret vault (`setup-secret-dir.sh`, `secret-mgr.py`)

### Development Tools

- Kubernetes tooling: `kubectl`, `kubectx`, `kubectl-neat`, `kubectl-node-shell`,
  `kubectl-cnpg`, `stern`, `pinniped`, `kubernetes-helm`, `argocd`
- k3s, toggled at runtime with the `k3s-on` / `k3s-off` aliases
- `ripgrep`, `dyff`, `python3`
- GitHub Copilot CLI, exposed through the `copilot` wrapper in
  `home/leo/configs/copilot-container.nix`
- Kubectl context/namespace shown in the shell prompt on the laptop
  (`home/leo/configs/prompt-laptop.nix`); a simpler prompt on servers
  (`prompt-server.nix`)

## Locale Settings

- **Keyboard:** French (AZERTY)
- **Timezone:** Europe/Paris
- **Locale:** fr_FR.UTF-8

## Usage

### Rebuild System

```bash
rebuild          # alias for: sudo nixos-rebuild switch --flake '.#'$(hostname)
os-update        # updates flake inputs, then rebuilds
```

Both aliases are defined in `home/leo/configs/shell.nix`.

To target a specific host explicitly (e.g. from another machine):

```bash
sudo nixos-rebuild switch --flake '.#nixos'
sudo nixos-rebuild switch --flake '.#red'
sudo nixos-rebuild switch --flake '.#black'
sudo nixos-rebuild switch --flake '.#blue'
```

`red.sh`, `black.sh`, and `blue.sh` deploy to their server hosts remotely over
SSH.

### Formatting

```bash
nix fmt
```

### Key Bindings

#### Applications

- `Super + Return` - Terminal (Kitty)
- `Super + B` - Browser (Firefox)
- `Super + D` - Application launcher (Rofi)
- `Super + R` - Run command (Rofi)
- `Super + C` - Clipboard history

#### Session

- `Super + Shift + Q` or `Alt + F4` - Close window
- `Super + Shift + E` - Exit Hyprland
- `Super + L` - Lock screen
- `Super + F` - Fullscreen
- `Super + V` - Toggle floating

#### Focus

- `Alt + Tab` - Cycle windows
- `Super + Arrow keys` - Move focus

#### Move Windows

- `Super + Shift + Arrow keys` - Move window

#### Workspaces (AZERTY)

- `Super + &` - Workspace 1
- `Super + é` - Workspace 2
- `Super + "` - Workspace 3
- `Super + '` - Workspace 4
- `Super + (` - Workspace 5

Add `Shift` to move window to workspace.

#### Screenshots

- `Print` - Full screen
- `Shift + Print` - Region select
- `Ctrl + Print` - Current window

#### Media Keys

- `XF86AudioRaiseVolume/LowerVolume` - Volume control
- `XF86AudioMute` - Mute toggle
- `XF86AudioPlay/Pause/Next/Prev` - Media playback
- `XF86MonBrightnessUp/Down` - Brightness control

#### Mouse (XFCE-like)

- `Alt + Left Click` - Move window
- `Alt + Right Click` - Resize window

## Customization

### Monitor Configuration

Edit the `monitor` section in `home/leo/configs/hyprland.nix`:

```nix
monitor = [
  "eDP-1,1920x1080,0x0,1"
  "HDMI-A-1,2560x1440,1920x0,1"
];
```

Use `hyprctl monitors` to see your monitor names.

### Git Configuration

This flake does not set a Git identity. Configure `programs.git` in your own
Home Manager module if you want the repo to manage `user.name` and
`user.email`.

## System Information

- **NixOS Version:** 25.11
- **System:** x86_64-linux
- **Username:** `leo`
- **Hosts:** `nixos` (work laptop), `red`, `black`, `blue` (headless servers)

## Adding Hosts

Add a new entry to the `hosts` attrset in `flake.nix`.

- Laptop: import `./hosts/<hostname>/configuration.nix`; inside that host file
  import `../../modules/base.nix`, `../../modules/laptop.nix`, and
  `./hardware-configuration.nix`. Add `./home/leo/base.nix` and
  `./home/leo/laptop.nix` to the host's `homeModules`.
- Server: same pattern, but use `../../modules/server.nix` and
  `./home/leo/server.nix`.
- Keep machine-specific credentials and private integrations in an ignored
  `hosts/<hostname>/private.nix` overlay.
