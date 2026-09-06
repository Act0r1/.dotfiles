# Portable Home Manager dotfiles

One user environment for Linux and macOS. The operating system remains native;
Nix and standalone Home Manager provide the same terminal, development tools,
fonts, packages, and editable configuration wherever those packages are
supported.

## Apply

Install Nix, clone this repository to the expected path, and run the flake:

```bash
git clone --branch feat/portable-dotfiles https://github.com/Act0r1/.dotfiles.git ~/.dotfiles
cd ~/.dotfiles
bash bootstrap/apply.sh
```

The bootstrap enables Nix command/flakes support for its invocation and runs
the pinned Home Manager from `flake.lock`; a separate global
Home Manager installation is not required. Nix selects the default app for the
current platform and applies the matching profile with conflicting files backed
up using the `hm-backup` suffix.

Supported profiles:

| Platform | Home Manager profile | Scope |
| --- | --- | --- |
| `x86_64-linux` | `desktop` | Shared environment plus Niri and iNiR (default) |
| `x86_64-linux` | `desktop-hyprland` | Existing Hyprland and Noctalia setup |
| `aarch64-linux` | `linux-aarch64` | Shared environment plus Niri and iNiR; no amd64 Handy |
| `aarch64-darwin` | `darwin-aarch64` | Shared terminal and development environment |
| `x86_64-darwin` | `darwin-x86_64` | Shared environment pinned to the final supported Intel Darwin release |

The repository must stay at `~/.dotfiles`. Home Manager creates out-of-store
links to it, so edits remain live and the Git working tree stays the source of
truth.

The profiles currently target user `yeager`. For a different account, change
the `username` default in `flake.nix` first. To update later, run
`git pull --ff-only` followed by `bash bootstrap/apply.sh`. Select the optional
profile with `bash bootstrap/apply.sh desktop-hyprland`. Existing conflicts get
an `hm-backup` suffix; preserve an existing backup before retrying a conflict.

## What is shared

The common Home Manager layer includes Zsh and its plugins, Fish, Tmux, Neovim,
Starship, Git, language runtimes, formatters, language servers, CLI tools, fonts,
and the configuration for Ghostty and Zed.

Linux additionally installs Niri, pinned iNiR with the local runtime changes,
Wayland utilities, desktop applications, and local screenshot helpers.
Kernel, drivers, networking, audio, system services, and other host-level
components remain managed by the Linux distribution.

The Linux profiles also reproduce the current Darkly/GTK appearance, WhiteSur
icons, Capitaine cursor, Roboto Flex and Gabarito fonts, and Ocean sounds.
Existing mutable GTK and KDE settings are preserved; Home Manager seeds the
captured defaults only when their target files do not exist.

Neovim is pinned to 0.12.5 for the current UI API. Plugin revisions, including
the initial Lazy.nvim checkout, are pinned in `lazy-lock.json`; local plugins
are included. Under `NVIM_NIX_MANAGED=1`, Nix provides LSP/formatter binaries
and Mason does not download a second toolchain. Plugins need network access
on first installation.

Rustup remains the Rust compiler and Cargo toolchain manager; install and select
the desired toolchain with `rustup default stable` on a fresh account.
The standalone Nix `rust-analyzer` and `rustfmt` binaries take precedence over
Rustup's component proxies so editor support is available independently.

The iNiR application is pinned in `flake.lock`; `inir/source-overrides` holds
the 14 local panel, OCR, recording and notification changes. Nix owns this
application code, so update it through the flake instead of its self-updater.
Its Python helpers run in a pinned Nix environment instead of a mutable local
virtual environment. The packaged shell receives the image, OCR, recording and
desktop libraries used by the local helpers.
The cleaned `inir/.config/inir` files seed missing private runtime files under
`~/.config/inir` only on first use. Subsequent applies preserve those files.
Passwords entered later stay outside Git. The three agent instruction files
are linked individually, without account state or credentials.

Stow is installed and its package layout is retained. Choose either Stow or
Home Manager for each target; do not let both manage the same file. GRUB assets
remain optional host-level files. Bootstrap does not change the login shell.

Fedora must provide a working Niri login session, native graphics/audio/network
services, and `/etc/pam.d/swaylock` for the lock screen. The profile includes
GNOME/GTK portal preferences. GPU-accelerated Nix programs on non-NixOS require
the [Home Manager GPU setup](https://nix-community.github.io/home-manager/usage/gpu-non-nixos.html),
with NVIDIA userspace matching the host driver. A build does not test a real
graphical session or configure these system components.

Nixpkgs currently does not provide the Ghostty or Zed packages for Darwin. Home
Manager still links their shared configuration, but the macOS applications must
be installed natively. `Brewfile` is retained as an optional fallback and is not
used by `nix run .`.

## Noctalia v4 and v5

The optional Hyprland profile uses the official Hyprland 0.56.2 flake package
and its matching portal. It retains both Linux-only Noctalia releases with
separate formats in the shared `noctalia/.config/noctalia` directory:

- v4: `settings.json`, `colors.json`, `plugins.json`.
- v5: `config.toml`.

Use `Ctrl+Shift+}` to switch releases. The switcher records the selected version
under `${XDG_STATE_HOME:-$HOME/.local/state}/noctalia-shell-version`, reloads
Hyprland, stops the active shell, and starts the other release. Runtime
clipboard, notification, and GUI state are not committed.

## Development and rollback

```bash
just check
just build desktop
just apply
```

Update inputs intentionally with `nix flake update`, evaluate or build the
affected profiles, and commit `flake.lock` only after validation. Home Manager
keeps previous generations; editable configuration is rolled back through Git.

## Private data

Do not commit `.env`, private shell fragments, local agent settings, clipboard
history, notification history, tokens, or credentials. Put shell secrets in
`~/.zsh_private`; the shared Zsh config loads it when present.

SSH, private settings, browser sessions, projects, containers and local databases
need separate backups. The Git-filtered flake source excludes ignored files
from the readable Nix store. Review the staged changes and run Gitleaks before
publishing; the checked-in allowlist covers one exact QML variable reference,
not credential values. Never copy runtime iNiR settings back without sanitizing.
