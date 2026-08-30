# Evaluates modules/nixcreative.nix and verifies catalogue wiring for daw/vector/raster/3d selections.
{ pkgs, lib ? pkgs.lib }:
let
  evalWith = selection: (lib.evalModules {
    modules = [ ../modules/nixcreative.nix { nixcreative = selection; } ];
  }).config.nixcreative;

  fullDaw = evalWith { daw = [ "qtractor" ]; };
  fullVector = evalWith { vector = [ "inkscape" ]; };
  fullRaster = evalWith { raster = [ "krita" ]; };
  full3d = evalWith { "3d" = [ "blender" ]; };
  blenderMcp = evalWith {
    "3d" = [ "blender" ];
    blender.mcp.enable = true;
  };
  all = evalWith {
    daw = [ "qtractor" ];
    vector = [ "inkscape" ];
    raster = [ "krita" ];
    "3d" = [ "blender" ];
  };

  has = list: item: lib.elem item list;

  results = {
    "empty selection resolves to no selected tool" =
      (evalWith { }).selected == [ ];

    "daw selection resolves the exact name, no AUR" =
      fullDaw.archPackages == [ "qtractor" ] && fullDaw.aurPackages == [ ];

    "daw group + availability summary looks right" =
      fullDaw.nixosPackages == [ "qtractor" ]
      && fullDaw.unavailableOnNixos == [ ];

    "vector selection resolves the exact name" =
      fullVector.archPackages == [ "inkscape" ]
      && fullVector.unavailableOnNixos == [ ];

    "raster selection resolves the exact name" =
      fullRaster.archPackages == [ "krita" ]
      && fullRaster.unavailableOnNixos == [ ];

    "3d selection resolves the exact name" =
      full3d.archPackages == [ "blender" ]
      && full3d.unavailableOnNixos == [ ];

    "blender alone does not pull MCP runtime packages" =
      full3d.archPackages == [ "blender" ];

    "official Blender MCP adds its Arch runtime dependency" =
      blenderMcp.archPackages == [ "blender" "python-cattrs" ]
      && blenderMcp.aurPackages == [ ];

    "groups compose into one selected list" =
      lib.length all.selected == 4;

    "arch and aur lists never overlap" =
      lib.intersectLists all.archPackages all.aurPackages == [ ];

    "bad daw name is rejected at eval time" =
      (builtins.tryEval (builtins.deepSeq (evalWith { daw = [ "ardour" ]; }).daw true)).success == false;

    "bad vector name is rejected at eval time" =
      (builtins.tryEval (builtins.deepSeq (evalWith { vector = [ "gimp" ]; }).vector true)).success == false;

    "bad raster name is rejected at eval time" =
      (builtins.tryEval (builtins.deepSeq (evalWith { raster = [ "photoshop" ]; }).raster true)).success == false;

    "bad 3d name is rejected at eval time" =
      (builtins.tryEval (builtins.deepSeq (evalWith { "3d" = [ "cinema4d" ]; })."3d" true)).success == false;
  };

  failed = lib.attrNames (lib.filterAttrs (_: passed: !passed) results);
in
if failed == [ ] then
  pkgs.emptyFile
else
  throw ''
    nixcreative: catalogue-eval check failed:
    ${lib.concatMapStringsSep "\n" (f: "  - ${f}") failed}
  ''
