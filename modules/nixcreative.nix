# SPDX-License-Identifier: MIT OR Apache-2.0
#
# nixcreative — creator tooling, declared by intention:
# audio editors, image editors, video editors, and studio extras.
#
# This module is platform-neutral and only computes what a host wants.
# NixOS/system-manager backends consume the computed lists.
#
{ config, lib, ... }:
let
  cfg = config.nixcreative;
  cat = import ../lib/creative.nix { };
  blenderMcp = import ../lib/blender-mcp.nix;

  mkGroup = name: table: lib.mkOption {
    type = lib.types.listOf (lib.types.enum (lib.attrNames table));
    default = [ ];
    description = "Which ${name}. Available: ${lib.concatStringsSep ", " (lib.attrNames table)}.";
  };

  selected = lib.flatten [
    (map (k: cat.daw.${k}) cfg.daw)
    (map (k: cat.vector.${k}) cfg.vector)
    (map (k: cat.raster.${k}) cfg.raster)
    (map (k: cat."3d".${k}) cfg."3d")
  ];
in
{
  imports = [ ./blender-mcp-options.nix ];

  options.nixcreative = {
    daw = mkGroup "digital audio workstation tools" cat.daw;
    vector = mkGroup "vector illustration tools" cat.vector;
    raster = mkGroup "raster/painting tools" cat.raster;
    "3d" = mkGroup "3D creation tools" cat."3d";

    selected = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      readOnly = true;
      internal = true;
      description = "Resolved catalogue entries for every selected audio/image/video tool.";
    };

    archPackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = ''
        Host-facing package names for pacman.

        Pair with:

          nixarch.packages.pacman = config.nixcreative.archPackages;

        AUR-only entries (if any) stay out of this list and go in `aurPackages`.
      '';
    };

    aurPackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = ''
        Host-facing package names that live in AUR.
        Wire to:

          nixarch.packages.aur = config.nixcreative.aurPackages;

        With no aur reconciler configured for AUR, these are a warning-only gap.
      '';
    };

    nixosPackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = ''
        Dotted nixpkgs names for declarative visibility; consumers should not assume this list
        is fully installable without resolution.
      '';
    };

    unavailableOnNixos = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = "Selected tools with no nixpkgs equivalent.";
    };
  };

  config = {
    nixcreative.selected = selected;
    nixcreative.archPackages = lib.unique (
      (map (t: t.arch) (lib.filter (t: !(t.aur or false)) selected))
      ++ lib.optionals cfg.blender.mcp.enable blenderMcp.archRuntimePackages
    );
    nixcreative.aurPackages = lib.unique (map (t: t.arch) (lib.filter (t: t.aur or false) selected));
    nixcreative.nixosPackages = lib.unique (map (t: t.nixpkgs) (lib.filter (t: t.nixpkgs != null) selected));
    nixcreative.unavailableOnNixos = lib.unique (map (t: t.arch) (lib.filter (t: t.nixpkgs == null) selected));
  };
}
