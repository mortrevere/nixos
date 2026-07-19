# NixOS Flake — Context for AI Sessions

Warning: you (the agent) are running in a docker container without access to the underlying NixOS system. nix commands cannot be called and you can't interact directly with the OS defined by this NixOS Flake.

## Build & Apply

```bash
# Rebuild and switch (uses the `rebuild` alias)
sudo nixos-rebuild switch --flake '.#nixos'

# Dry-run to check for errors without applying
sudo nixos-rebuild dry-activate --flake '.#nixos'

# Build only (no switch, useful to catch eval errors)
nix build '.#nixosConfigurations.nixos.config.system.build.toplevel'

# Build the first server host
nix build '.#nixosConfigurations.red.config.system.build.toplevel'

# Format all nix/shell/js files
nix fmt
```

There are no tests. The closest equivalent is `dry-activate` or `nix build` above.

## Architecture

This is a multi-host-ready NixOS flake. The current host is the work laptop
`nixos`; every host uses user `leo`.

```
flake.nix                          ← entry point; declares hosts and passes username/hostname as specialArgs
modules/base.nix                   ← shared NixOS base for all machines
modules/laptop.nix                 ← graphical laptop/workstation NixOS profile
modules/server.nix                 ← headless server NixOS profile for future hosts
modules/features/                  ← optional reusable features (k3s, tailscale, yubikey, keyd)
hosts/<hostname>/configuration.nix ← host-specific system composition and overrides
hosts/<hostname>/hardware-configuration.nix ← auto-generated hardware config; do not edit manually
hosts/red/                       ← first server host profile
home/leo/base.nix                  ← shared Home Manager base for user `leo`
home/leo/laptop.nix                ← graphical laptop Home Manager profile
home/leo/server.nix                ← server Home Manager profile for future hosts
home/leo/configs/                  ← reusable Home Manager config modules
home/leo/files/                    ← managed non-Nix files sourced by Home Manager modules
home/leo/configs/packages.nix      ← laptop home.packages
home/leo/configs/hyprland.nix      ← Hyprland WM, hyprlock, hypridle, hypr helper scripts
home/leo/configs/waybar.nix        ← waybar config, style.css, reload activation hook
home/leo/configs/rofi.nix          ← rofi launcher config (config.rasi)
home/leo/configs/mako.nix          ← mako notification daemon config
home/leo/configs/kitty.nix         ← kitty terminal config (theme, keybindings, splits)
home/leo/configs/shell.nix         ← programs.bash: all aliases, shell functions, fzf, history, PS1
home/leo/configs/emacs.nix         ← programs.emacs + services.emacs + nix-managed emacs packages
home/leo/configs/scripts.nix       ← generic ~/.local/bin/* scripts as home.file entries
home/leo/files/emacs-init.el       ← emacs config (sourced via home.file); no package management here
home/leo/files/kgb.py              ← seeded password generator script (referenced by scripts.nix)
home/leo/files/secret-mgr.py       ← ecryptfs secret vault script (referenced by scripts.nix)
home/leo/files/paste-horizon.py    ← paste-horizon implementation
home/leo/files/touchpad-hscroll.py ← touchpad horizontal scroll helper
home/leo/configs/firefox.nix       ← Firefox profile and preferences
home/leo/configs/kubernetes.nix    ← kubectl/kubectx/stern shell helpers and config (generic, public)
home/leo/configs/copilot-container.nix ← containerized GitHub Copilot CLI wrapper
home/leo/configs/paste-horizon.nix ← paste-horizon helper integration
```

**Local overrides:** `hosts/<hostname>/private.nix` is ignored by Git and imported
when present. Keep credentials and private integrations in those files. The public
configuration must remain usable when no override file exists.

**How home-manager is wired in:** it runs as a NixOS module (not standalone). `useGlobalPkgs = true` and `useUserPackages = true` are set, so packages declared in `home.packages` land in the user profile and share the system's nixpkgs instance.

**`specialArgs` flow:** `username` is global (`leo`) and `hostname` comes from
the selected host in `flake.nix`. Both are forwarded to NixOS modules and
home-manager via `extraSpecialArgs`; they are available as function arguments in
any module file.

## Key Conventions

### Adding a new package

- **Common system-wide**: `modules/base.nix` → `environment.systemPackages`
- **Laptop system-wide**: `modules/laptop.nix` → `environment.systemPackages`
- **Server system-wide**: `modules/server.nix` → `environment.systemPackages`
- **Host-specific**: `hosts/<hostname>/configuration.nix`
- **Common user-only**: `home/leo/base.nix` or modules it imports
- **Laptop user-only**: `home/leo/laptop.nix` or modules it imports
- **Server user-only**: `home/leo/server.nix`
- **Required by a shell function**: add it to `home/leo/configs/shell.nix` alongside the function

### Adding a shell alias or function

Put it in `home/leo/configs/shell.nix`:

- Simple alias → `programs.bash.shellAliases`
- Multi-line function → `programs.bash.bashrcExtra`

### Adding a script to `~/.local/bin/`

Add a `home.file.".local/bin/<name>"` entry in `home/leo/configs/scripts.nix`.

- For **bash scripts**: use `text = ''...''` with `executable = true`
- For **Python scripts** (or any script containing `''`): put the script in `home/leo/files/` and use `source = ../files/<file>; executable = true` from a config module — **do not inline Python in nix strings** because `''` closes the nix multiline string

### Clipboard

- `setclip` / `getclip` are `~/.local/bin` wrappers around `wl-copy` / `wl-paste` (Wayland)
- Never use `xclip` or `xsel` — this is a pure Wayland setup

### Emacs packages

Declare them in `home/leo/configs/emacs.nix` under `programs.emacs.extraPackages`. Do **not** add `(package-install ...)` or MELPA config to `emacs-init.el` — `(server-start)` is also absent since the daemon is managed by `services.emacs`.

### k3s

The k3s service is disabled by default. Use the shell aliases `k3s-on` / `k3s-off` (defined in `modules/features/k3s-local.nix`) to toggle it at runtime without a rebuild.

### Formatting

`nix fmt` runs `nixfmt` (nix), `shfmt` (shell), `prettier` (other), `deadnix` + `statix` (linters). Config is in `treefmt.nix`.

## Color Scheme

All UI customizations (rofi, mako, login screen, dropdown terminal, etc.) should use this palette:

| Role                | Hex       | Description        |
| ------------------- | --------- | ------------------ |
| Background          | `#1f1626` | Dark purple        |
| Foreground / text   | `#d9faff` | Light cyan         |
| Selected            | `#883cdc` | Purple             |
| Selected foreground | `#fff8dd` | Cream / warm white |
| Border / accent     | `#d94085` | Magenta / pink     |
| Urgent              | `#d94085` | Magenta / pink     |
| Active / success    | `#2ab250` | Green              |

When adding transparency, append an alpha suffix (e.g. `#1f1626ee`). Use this palette for any new UI component to keep a consistent look across the system.

**Font:** Use `Iosevka Term` everywhere when theming (rofi, mako, terminals, etc.).

## Locale / Layout

- Keyboard: French AZERTY (`fr` xkb layout)
- Workspace keys in Hyprland use AZERTY symbols: `&`, `é`, `"`, `'`, `(`
- Timezone: `Europe/Paris`, locale: `fr_FR.UTF-8`
