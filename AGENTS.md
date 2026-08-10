# NixOS Flake - Automation Notes

This repository defines a multi-host NixOS flake for laptop, server, and kiosk
profiles. It is designed for host `nixos` plus server hosts `red`, `blue`, and
`black`; every host uses user `leo`.

## Build and Apply

```bash
# Rebuild and switch the laptop host
sudo nixos-rebuild switch --flake '.?submodules=1#nixos'

# Dry-run activation
sudo nixos-rebuild dry-activate --flake '.?submodules=1#nixos'

# Build only
nix build '.?submodules=1#nixosConfigurations.nixos.config.system.build.toplevel'

# Build the first server host
nix build '.?submodules=1#nixosConfigurations.red.config.system.build.toplevel'

# Format all configured file types
nix fmt
```

The closest validation target is `dry-activate` or `nix build`; there are no
separate tests.

## Architecture

```text
flake.nix                          - entry point; declares hosts and specialArgs
modules/base.nix                   - shared NixOS base
modules/laptop.nix                 - graphical laptop/workstation profile
modules/server.nix                 - headless server profile
modules/features/                  - optional reusable features
hosts/<hostname>/configuration.nix - host-specific system composition
hosts/<hostname>/hardware-configuration.nix - generated hardware config
home/leo/base.nix                  - shared Home Manager base
home/leo/laptop.nix                - laptop Home Manager profile
home/leo/server.nix                - server Home Manager profile
home/leo/configs/                  - reusable Home Manager config modules
home/leo/files/                    - managed non-Nix files
private/                           - private submodule for local integrations
```

Private configuration belongs in the `private/` submodule or ignored
`hosts/<hostname>/private.nix` overlays. Do not store credentials in tracked
files.

Home Manager is wired as a NixOS module with `useGlobalPkgs = true` and
`useUserPackages = true`. The `username` and `hostname` special args are
forwarded to both NixOS and Home Manager modules.

## Conventions

Add packages in the narrowest suitable place:

- Common system-wide: `modules/base.nix`
- Laptop system-wide: `modules/laptop.nix`
- Server system-wide: `modules/server.nix`
- Host-specific: `hosts/<hostname>/configuration.nix`
- Common user-only: `home/leo/base.nix`
- Laptop user-only: `home/leo/laptop.nix`
- Server user-only: `home/leo/server.nix`

Add shell aliases and functions in `home/leo/configs/shell.nix`. Add scripts to
`~/.local/bin` through `home.file` entries in `home/leo/configs/scripts.nix`.
For Python scripts, keep the source under `home/leo/files/` and reference it
with `source = ../files/<file>; executable = true`.

Use the Wayland clipboard wrappers `setclip` and `getclip`; this setup does not
use `xclip` or `xsel`.

Declare Emacs packages in `home/leo/configs/emacs.nix` under
`programs.emacs.extraPackages`. The Emacs daemon is managed by
`services.emacs`.

The k3s service is disabled by default and toggled with `k3s-on` / `k3s-off`.

## Formatting

`nix fmt` runs the formatters and linters configured in `treefmt.nix`.

## Color Scheme

All UI customizations should use this palette:

| Role                | Hex       |
| ------------------- | --------- |
| Background          | `#1f1626` |
| Foreground / text   | `#d9faff` |
| Selected            | `#883cdc` |
| Selected foreground | `#fff8dd` |
| Border / accent     | `#d94085` |
| Urgent              | `#d94085` |
| Active / success    | `#2ab250` |

Use `Iosevka Term` when theming rofi, mako, terminals, and similar UI.

## Locale

- Keyboard: French AZERTY (`fr` xkb layout)
- Workspace keys in Hyprland use AZERTY symbols: `&`, `é`, `"`, `'`, `(`
- Timezone: `Europe/Paris`
- Locale: `fr_FR.UTF-8`
