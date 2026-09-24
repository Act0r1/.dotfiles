{
  config,
  inputs,
  pkgs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  link = config.lib.file.mkOutOfStoreSymlink;
in
{
  home.packages = [
    inputs.noctalia-v4.packages.${system}.default
    inputs.noctalia-v5.packages.${system}.default
  ];

  xdg.configFile."noctalia".source = link "${dotfiles}/noctalia/.config/noctalia";
}
