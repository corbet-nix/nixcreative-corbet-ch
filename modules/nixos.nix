# SPDX-License-Identifier: MIT OR Apache-2.0
#
# NixOS backend for nixcreative. Installs resolved creators through
# `environment.systemPackages` while surfacing stale mappings as warnings.
#
{ config, lib, pkgs, ... }:
let
  cfg = config.nixcreative;

  selected = lib.filter (t: t.nixpkgs != null) cfg.selected;
  evaluated = map
    (t: {
      inherit t;
      try = builtins.tryEval (builtins.seq (lib.getAttrFromPath (lib.splitString "." t.nixpkgs) pkgs) true);
    })
    selected;

  installable = map (r: r.t) (lib.filter (r: r.try.success) evaluated);
  staleMappings = map
    (r: "nixcreative: nixpkgs attribute \"${r.t.nixpkgs}\" (catalogue arch name \"${r.t.arch}\") no longer resolves -- lib/creative.nix is stale")
    (lib.filter (r: !r.try.success) evaluated);
in
{
  imports = [ ./nixcreative.nix ];

  config = {
    environment.systemPackages = lib.unique (map
      (t: lib.getAttrFromPath (lib.splitString "." t.nixpkgs) pkgs)
      installable);

    warnings =
      lib.optional (cfg.unavailableOnNixos != [ ])
        "nixcreative: no nixpkgs equivalent for: ${lib.concatStringsSep ", " cfg.unavailableOnNixos}"
      ++ staleMappings;
  };
}
