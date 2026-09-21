#!/usr/bin/env bash
# SPDX-License-Identifier: MIT OR Apache-2.0
#
# Re-verify the package catalogue against a real pacman database and a real nixpkgs revision.
#
# WHAT THIS IS FOR. `lib/creative.nix` maps one tool to a pacman name and a nixpkgs attribute path,
# and both halves are somebody else's namespace: a package gets renamed, an attribute becomes an
# alias, an entry moves to the AUR. None of that fails an evaluation of this repository, because
# nothing here resolves either name -- the module publishes lists and the host installs from them.
# This is where the names are actually resolved.
#
# THE NIXPKGS HALF FORCES THE ATTRIBUTE, and that is the whole point of doing it this way. A
# renamed attribute in nixpkgs becomes a THROWING ALIAS: `nixpkgs ? oldname` is true, and reading
# anything off it raises. An existence check therefore passes on exactly the entries that are
# broken, which is the worst possible direction for a check to be wrong in. Forcing `.name` is what
# tells the two apart.
#
# THE PACMAN HALF NEEDS A PACMAN. Run it on the Arch-family host whose reconciler consumes
# `archPackages`; anywhere else it says so and skips that half rather than pretending. An AUR entry
# is skipped there too and reported: `pacman -Si` cannot see the AUR, and a failure to find one
# would be a false negative, not a finding.
#
#   ./experiments/verify-packages.sh
#
# EXIT STATUS: 0 when every name that COULD be checked resolved, 1 otherwise. A skip is not a
# failure and is never counted as a pass.
set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

command -v jq >/dev/null || { echo "needs jq" >&2; exit 2; }
command -v nix >/dev/null || { echo "needs nix" >&2; exit 2; }

catalogue=$(nix eval --json "$root#lib.catalogue") || exit 2

have_pacman=0
command -v pacman >/dev/null && have_pacman=1
[ "$have_pacman" -eq 1 ] || echo "note: no pacman on this host -- the pacman half is SKIPPED, not passed"

fail=0
note() { printf '  %-10s %s\n' "$1" "$2"; }

for group in $(jq -r 'keys[]' <<<"$catalogue"); do
  for entry in $(jq -r --arg g "$group" '.[$g] | keys[]' <<<"$catalogue"); do
    e=$(jq -r --arg g "$group" --arg e "$entry" '.[$g][$e]' <<<"$catalogue")
    arch=$(jq -r '.arch' <<<"$e")
    attr=$(jq -r '.nixpkgs // ""' <<<"$e")
    aur=$(jq -r '.aur // false' <<<"$e")

    echo "== $group/$entry"

    if [ "$aur" = "true" ]; then
      note "pacman" "$arch is an AUR name -- outside the sync databases, skipped"
    elif [ "$have_pacman" -eq 1 ]; then
      if out=$(pacman -Si "$arch" 2>&1); then
        note "pacman" "$arch -> $(awk -F': +' '/^Repository/{r=$2} /^Version/{v=$2} END{print r" "v}' <<<"$out")"
      else
        note "PACMAN" "$arch does not resolve: $(head -1 <<<"$out")"; fail=1
      fi
    else
      note "pacman" "$arch -- skipped, no pacman here"
    fi

    if [ -z "$attr" ]; then
      note "nixpkgs" "no attribute claimed for this entry"
    # FORCING, not `?`. See the header: a throwing alias satisfies an existence check.
    #
    # RESOLVED AGAINST THIS FLAKE'S OWN LOCKED NIXPKGS, through `getFlake` rather than through a
    # flake output reference: `#inputs...` is not an output, so that form looks for a package by
    # that name and reports a missing attribute whatever the input holds.
    elif out=$(nix eval --impure --raw --expr \
      "(builtins.getFlake \"$root\").inputs.nixpkgs.legacyPackages.\${builtins.currentSystem}.$attr.name" 2>/dev/null); then
      note "nixpkgs" "$attr -> $out"
    else
      # Re-run for the message alone. `nix` writes its diagnostics to stderr, and folding those
      # into the success path would have printed a channel warning as if it were a package name.
      err=$(nix eval --impure --raw --expr \
        "(builtins.getFlake \"$root\").inputs.nixpkgs.legacyPackages.\${builtins.currentSystem}.$attr.name" 2>&1 >/dev/null)
      note "NIXPKGS" "$attr does not force: $(grep -m1 -E 'error|renamed|removed' <<<"$err")"; fail=1
    fi
  done
done

if [ "$fail" -ne 0 ]; then
  echo
  echo "at least one catalogued package name no longer resolves -- read the lines in capitals" >&2
  exit 1
fi
echo
echo "every package name that could be checked on this host resolves"
