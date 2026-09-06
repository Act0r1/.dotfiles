{ lib, pkgs, ... }:
{
  imports = [
    ./files.nix
    ./git.nix
    ./packages.nix
  ];

  programs.home-manager.enable = true;
  xdg.enable = true;
  fonts.fontconfig.enable = pkgs.stdenv.isLinux;

  targets.genericLinux.enable = pkgs.stdenv.isLinux;

  home.sessionVariables = {
    EDITOR = "nvim";
    LANG = "en_US.UTF-8";
    STARSHIP_CONFIG = "$HOME/.config/starship/starship.toml";
    PNPM_HOME = if pkgs.stdenv.isDarwin then "$HOME/Library/pnpm" else "$HOME/.local/share/pnpm";
  };

  home.sessionPath =
    let
      pnpmHome = if pkgs.stdenv.isDarwin then "$HOME/Library/pnpm" else "$HOME/.local/share/pnpm";
    in
    [
      "$HOME/.local/bin"
      "$HOME/.bun/bin"
      pnpmHome
      "${pnpmHome}/bin"
    ];
}
