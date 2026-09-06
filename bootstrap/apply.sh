#!/usr/bin/env bash
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
if ! command -v nix >/dev/null 2>&1; then
    printf 'Install Nix for your distribution, open a new terminal, and run this script again.\n' >&2
    exit 1
fi
if [[ ! -d "$HOME/.dotfiles" || "$repo" != "$(cd -- "$HOME/.dotfiles" && pwd -P)" ]]; then
    printf 'This configuration expects the repository at %s/.dotfiles.\n' "$HOME" >&2
    exit 1
fi
if [[ ! -f "$repo/flake.lock" ]]; then
    printf 'The pinned flake.lock is missing; restore it from Git before applying.\n' >&2
    exit 1
fi
export NIX_CONFIG="${NIX_CONFIG-}"$'\nextra-experimental-features = nix-command flakes'
exec nix run "$repo" -- "$@"
