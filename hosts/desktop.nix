{ username, ... }:
{
  imports = [
    ../home/appearance.nix
    ../home/linux-desktop.nix
    ../home/niri.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "26.05";

  home.sessionVariables.DOTFILES_HOST = "desktop";
}
