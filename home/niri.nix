{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  link = config.lib.file.mkOutOfStoreSymlink;
  inirSource = pkgs.runCommand "inir-2.30.0-source" { } ''
    cp -R --no-preserve=mode,ownership ${inputs.inir}/. "$out"
    chmod -R u+w "$out"
    cp -R --no-preserve=mode,ownership ${../inir/source-overrides}/. "$out"
  '';
  inirPython = import ./inir-python.nix { inherit pkgs; };
  inirPackage =
    (pkgs.callPackage "${inputs.inir}/nix/package.nix" { pkgs = inirPython.packageSet; }).overrideAttrs
      (old: {
        src = inirSource;
        postFixup = (old.postFixup or "") + ''
          find "$out/share/quickshell/inir" -type f \
            \( -name '*.qml' -o -name '*.js' -o -name '*.sh' -o -name '*.py' -o -name '*.fish' -o -name inir \) \
            -exec sed -i '1!s#/usr/bin/##g' {} +

          wrapProgram "$out/bin/inir" \
            --set INIR_VENV "${inirPython.runtime}" \
            --set ILLOGICAL_IMPULSE_VIRTUAL_ENV "${inirPython.runtime}" \
            --prefix GI_TYPELIB_PATH : "${inirPython.typelibPath}" \
            --prefix XDG_DATA_DIRS : "${inirPython.dataPath}" \
            --prefix QT_PLUGIN_PATH : "${lib.makeSearchPath "lib/qt-6/plugins" [ pkgs.darkly pkgs.kdePackages.plasma-integration ]}"
        '';
      });
  wallpaperSource = builtins.fromJSON (builtins.readFile ../desktop-support/wallpaper-source.json);
  wallpaper = pkgs.fetchurl {
    url = wallpaperSource.url;
    hash = wallpaperSource.sri;
  };
  codeCommand = pkgs.writeShellScriptBin "code" ''
    exec ${pkgs.vscodium}/bin/codium "$@"
  '';
in
{
  imports = [ inputs.inir.homeManagerModules.inir ];

  qt = {
    enable = true;
    platformTheme.name = "kde";
    style = {
      name = "Darkly";
      package = pkgs.darkly;
    };
  };

  home.packages = with pkgs; [
    firefox
    kitty
    nautilus
    niri
    swaylock
    xdg-desktop-portal
    xdg-desktop-portal-gnome
    xdg-desktop-portal-gtk
    xwayland-satellite
    kdePackages.kservice
    codeCommand
  ];

  programs.inir = {
    enable = true;
    package = inirPackage;
    configSymlink.enable = true;
  };

  systemd.user.services.inir.Service.Environment = lib.mkAfter [
    "INIR_VENV=${inirPython.runtime}"
    "ILLOGICAL_IMPULSE_VIRTUAL_ENV=${inirPython.runtime}"
  ];

  xdg.configFile = {
    "illogical-impulse".source = link "${config.xdg.configHome}/inir";
    "niri".source = link "${dotfiles}/niri/.config/niri";
    "xdg-desktop-portal/niri-portals.conf".source = link "${dotfiles}/desktop-support/.config/xdg-desktop-portal/niri-portals.conf";
  };

  home.activation.seedInirConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    inir_config=${lib.escapeShellArg "${config.xdg.configHome}/inir"}
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$inir_config"
    for name in config.json migrations.json version; do
      if [[ ! -e "$inir_config/$name" ]]; then
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 0600 \
          ${../inir/.config/inir}/"$name" "$inir_config/$name"
      fi
    done
  '';

  home.file = {
    "Pictures/Wallpapers/wallhaven-qrp9d7.jpg".source = wallpaper;
  };
}
