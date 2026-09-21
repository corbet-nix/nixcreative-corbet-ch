# SPDX-License-Identifier: MIT OR Apache-2.0
#
# Arch backend — exports package-name lists only.
# Host wiring:
#   nixarch.packages.pacman = config.nixcreative.archPackages;
#   nixarch.packages.aur    = config.nixcreative.aurPackages;
#
{ ... }:
{
  imports = [ ./nixcreative.nix ];
}
