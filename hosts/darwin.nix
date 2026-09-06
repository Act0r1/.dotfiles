{ pkgs, username, ... }:
{
  home.username = username;
  home.homeDirectory = "/Users/${username}";
  home.stateVersion = "26.05";

  home.sessionVariables.DOTFILES_HOST = pkgs.stdenv.hostPlatform.system;
}
