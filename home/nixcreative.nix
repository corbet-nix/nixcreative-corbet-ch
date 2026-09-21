# SPDX-License-Identifier: MIT OR Apache-2.0
# Home-manager backend — installs resolved creator tools to `home.packages` while surfacing stale
# mappings as warnings rather than hard failures.
{ config, lib, pkgs, ... }:
let
  cfg = config.nixcreative;

  # Filter directly from the platform-neutral selection, not from `nixosPackages`/arch package lists:
  # the catalogued list is the authoritative intent; platform-specific lists are backend-facing
  # derived values and can differ in shape even when intent is the same.
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
  imports = [ ../modules/nixcreative.nix ];

  config = {
    home.packages = lib.unique (map
      (t: lib.getAttrFromPath (lib.splitString "." t.nixpkgs) pkgs)
      installable);

    warnings =
      lib.optional (cfg.unavailableOnNixos != [ ])
        "nixcreative: no nixpkgs equivalent for: ${lib.concatStringsSep ", " cfg.unavailableOnNixos}"
      ++ staleMappings;
  };
}
