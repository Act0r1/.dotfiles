{
  config,
  inputs,
  pkgs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  hyprlandPackages = inputs.hyprland.packages.${system};
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  link = config.lib.file.mkOutOfStoreSymlink;
in
{
  imports = [ ./noctalia.nix ];

  home.packages = [
    hyprlandPackages.hyprland
    hyprlandPackages.xdg-desktop-portal-hyprland
  ]
  ++ (with pkgs; [
    hypridle
    hyprlock
    hyprpaper
    hyprpicker
    hyprsunset
  ]);

  xdg.configFile."hypr".source = link "${dotfiles}/hypr/.config/hypr";
}
