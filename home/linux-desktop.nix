{
  config,
  lib,
  pkgs,
  ...
}:
let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  link = config.lib.file.mkOutOfStoreSymlink;
  handySource = builtins.fromJSON (builtins.readFile ../desktop-support/handy-source.json);
  handy = pkgs.appimageTools.wrapType2 {
    pname = "handy";
    version = handySource.version;
    src = pkgs.fetchurl {
      url = handySource.url;
      hash = handySource.sri;
    };
  };
  polkitAgent = pkgs.kdePackages.polkit-kde-agent-1;
in
{
  home.packages =
    (with pkgs; [
      brave
      brightnessctl
      cliphist
      ddcutil
      kdePackages.dolphin
      grim
      imagemagick
      kdePackages.polkit-kde-agent-1
      libnotify
      pavucontrol
      playerctl
      pwvucontrol
      satty
      slurp
      solaar
      swappy
      telegram-desktop
      uwsm
      vscodium
      wayfreeze
      wf-recorder
      wl-clip-persist
      wl-clipboard
      wlr-randr
      wlsunset
      wofi
      xdg-utils
    ])
    ++ lib.optional (pkgs.stdenv.hostPlatform.system == "x86_64-linux") handy;

  home.file = {
    ".local/bin/polkit-kde-authentication-agent-1" = {
      source = "${polkitAgent}/libexec/polkit-kde-authentication-agent-1";
      executable = true;
    };
    ".local/bin/clx" = {
      source = link "${dotfiles}/linux-bin/.local/bin/clx";
      executable = true;
    };
    ".local/bin/screenshot" = {
      source = link "${dotfiles}/linux-bin/.local/bin/screenshot";
      executable = true;
    };
    ".local/bin/screenrecord" = {
      source = link "${dotfiles}/linux-bin/.local/bin/screenrecord";
      executable = true;
    };
    ".local/bin/whisper-live" = {
      source = link "${dotfiles}/linux-bin/.local/bin/whisper-live";
      executable = true;
    };
  };
}
