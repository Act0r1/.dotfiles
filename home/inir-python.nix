{ pkgs }:
let
  pythonPackages = pkgs.python3Packages;
  materialColorUtilities = pythonPackages.buildPythonPackage rec {
    pname = "material-color-utilities";
    version = "0.2.6";
    pyproject = true;

    src = pkgs.fetchPypi {
      pname = "material_color_utilities";
      inherit version;
      hash = "sha256-QIQDh4F+6jrDpfX7mShYP/W8/QcMgwl+/l53ti4JgQI=";
    };

    dontUseCmakeConfigure = true;

    build-system = with pythonPackages; [
      cmake
      ninja
      pybind11
      scikit-build-core
    ];

    dependencies = with pythonPackages; [
      numpy
      pillow
    ];

    pythonImportsCheck = [ "material_color_utilities" ];
  };
  extraPackages = ps: with ps; [
    click
    evdev
    kde-material-you-colors
    loguru
    materialColorUtilities
    materialyoucolor
    numpy
    opencv-contrib-python
    pillow
    psutil
    pycairo
    pygobject3
    tqdm
    websockets
  ];
  runtime = pkgs.python3.withPackages (
    ps:
    [
      ps.ytmusicapi
      ps.yt-dlp
      ps.secretstorage
    ]
    ++ extraPackages ps
  );
  packageSet = pkgs // {
    python3 = pkgs.python3 // {
      withPackages = selector: pkgs.python3.withPackages (ps: selector ps ++ extraPackages ps);
    };
  };
  dataPath = pkgs.lib.makeSearchPath "share" [
    pkgs.gsettings-desktop-schemas
    pkgs.shared-mime-info
  ];
  typelibPath = pkgs.lib.makeSearchPath "lib/girepository-1.0" [
    (pkgs.lib.getLib pkgs.glib)
    pkgs.gdk-pixbuf
    pkgs.gnome-desktop
    pkgs.gobject-introspection
  ];
in
{
  inherit dataPath packageSet runtime typelibPath;
}
