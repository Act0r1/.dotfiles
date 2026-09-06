{
  config,
  lib,
  pkgs,
  ...
}:
let
  gabarito = pkgs.google-fonts.override { fonts = [ "Gabarito" ]; };
  appearanceFiles = {
    darkly = ../desktop-support/.local/share/color-schemes/Darkly.colors;
    darklyrc = ../desktop-support/.config/darklyrc;
    gtk3Css = ../desktop-support/.config/gtk-3.0/gtk.css;
    gtk3Settings = ../desktop-support/.config/gtk-3.0/settings.ini;
    gtk4Css = ../desktop-support/.config/gtk-4.0/gtk.css;
    gtk4Settings = ../desktop-support/.config/gtk-4.0/settings.ini;
    kdeglobals = ../desktop-support/.config/kdeglobals;
  };
in
{
  home.packages = with pkgs; [
    adw-gtk3
    capitaine-cursors
    gabarito
    kdePackages.ocean-sound-theme
    roboto-flex
    whitesur-icon-theme
  ];

  xdg.configFile = {
    "gtk-4.0/assets".source = "${pkgs.adw-gtk3}/share/themes/adw-gtk3-dark/gtk-4.0/assets";
    "gtk-4.0/gtk-dark.css".source = "${pkgs.adw-gtk3}/share/themes/adw-gtk3-dark/gtk-4.0/gtk-dark.css";
  };

  home.file.".local/share/icons/capitaine-cursors-light".source =
    "${pkgs.capitaine-cursors}/share/icons/capitaine-cursors-white";

  home.activation.seedAppearance = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    seed_file() {
      source_file="$1"
      target_file="$2"

      if [[ ! -e "$target_file" ]]; then
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$target_file")"
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 0600 "$source_file" "$target_file"
      fi
    }

    seed_file ${appearanceFiles.kdeglobals} "${config.xdg.configHome}/kdeglobals"
    seed_file ${appearanceFiles.darklyrc} "${config.xdg.configHome}/darklyrc"
    seed_file ${appearanceFiles.gtk3Settings} "${config.xdg.configHome}/gtk-3.0/settings.ini"
    seed_file ${appearanceFiles.gtk3Css} "${config.xdg.configHome}/gtk-3.0/gtk.css"
    seed_file ${appearanceFiles.gtk4Settings} "${config.xdg.configHome}/gtk-4.0/settings.ini"
    seed_file ${appearanceFiles.gtk4Css} "${config.xdg.configHome}/gtk-4.0/gtk.css"
    seed_file ${appearanceFiles.darkly} \
      "${config.xdg.dataHome}/color-schemes/Darkly.colors"
  '';
}
