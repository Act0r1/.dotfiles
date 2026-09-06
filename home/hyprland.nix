{
  config,
  pkgs,
  ...
}:
let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  link = config.lib.file.mkOutOfStoreSymlink;
in
{
  imports = [ ./noctalia.nix ];

  home.packages = with pkgs; [
    hypridle
    hyprland
    hyprlock
    hyprpaper
    hyprpicker
    hyprsunset
    xdg-desktop-portal-hyprland
  ];

  xdg.configFile."hypr".source = link "${dotfiles}/hypr/.config/hypr";
}
