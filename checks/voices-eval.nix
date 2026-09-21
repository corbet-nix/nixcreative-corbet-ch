# SPDX-License-Identifier: MIT OR Apache-2.0
# Proves the voice-model catalogue obeys its own evidence rule, and that the two catalogues in
# `lib/` agree with each other.
#
# THIS CHECKS DATA, NOT A MODULE, and that is the right shape for what it protects. Nothing about a
# model's parameter count, its licence or its repository id depends on a declaration, so there is
# no surface to render and no consumer to imagine: the failure mode being defended against is
# somebody adding an entry from memory, or half-updating one, and both of those are visible in the
# data alone.
#
# THE RULE IT ENFORCES IS THE ONE THE CATALOGUE OPENS WITH. Every fact came off a primary source;
# where a source does not establish a fact the field is `null` and the entry names it in
# `unverified` with what would have to be fetched. Both directions are checked, because only one
# direction is a rule you can satisfy by deleting something: an unnamed `null` is a fact quietly
# dropped, and a named field that is NOT null is an entry somebody filled in without removing the
# note saying it was unknown -- which is how a stale "we never checked this" outlives the checking.
#
# AND IT REFUSES A PATH. `lib/voices.nix` says which model a workload serves and never where a
# weight file lives; an absolute path anywhere in that data is one deployment's disk layout
# arriving in a public catalogue, so it fails here rather than being noticed in review.
{ pkgs, lib ? pkgs.lib }:

let
  voices = (import ../lib/voices.nix { }).voices;
  applications = (import ../lib/applications.nix { }).applications;

  # The facts a source may fail to establish. Everything else is either always known (a repository
  # id, a licence) or is this repository's own vocabulary (a note).
  factFields = [ "parameters" "needsGpu" "voiceCloning" ];

  entryFields = [
    "name"
    "hfRepo"
    "upstream"
    "parameters"
    "needsGpu"
    "voiceCloning"
    "licence"
    "gated"
    "unverified"
    "sources"
    "note"
  ];

  licenceFields = [ "name" "spdx" "commercialUse" "caveat" ];

  sorted = xs: lib.sort (a: b: a < b) xs;

  # A path-shaped TOKEN, not merely a string that starts with one. The naive form -- does this
  # string begin with a slash -- passes on a note that mentions a path halfway through a sentence,
  # which is exactly how one would arrive: in prose, as an aside, next to the model it belongs to.
  # Splitting on whitespace and brackets first is what makes the rule read the way a person would.
  tokensOf = s: lib.filter builtins.isString (builtins.split "[][ \t\n(){}\",'`]+" s);
  hasPathToken = s: lib.any (t: lib.hasPrefix "/" t) (tokensOf s);

  # Every string anywhere in a value, however deeply nested.
  allStrings = v:
    if builtins.isString v then [ v ]
    else if builtins.isList v then lib.concatMap allStrings v
    else if builtins.isAttrs v then lib.concatMap allStrings (lib.attrValues v)
    else [ ];

  entries = lib.attrValues voices;
  names = lib.attrNames voices;

  all = f: lib.all f entries;

  isUrl = s: lib.hasPrefix "https://" s;

  nonEmpty = s: builtins.isString s && lib.stringLength (lib.replaceStrings [ " " "\n" ] [ "" "" ] s) > 0;

  # A repository id is `owner/name`: no scheme, no leading slash, exactly one separator. A URL
  # written into this field would still LOOK right in a rendered document and would be wrong
  # everywhere a tool used it.
  isRepoId = s:
    let parts = lib.splitString "/" s; in
    lib.length parts == 2 && lib.all (p: p != "" && !(lib.hasInfix ":" p)) parts;

  nullFactsOf = e: lib.filter (f: e.${f} == null) factFields;

  results = {
    # ── The schema, so that a missing field is a failure rather than a silence ─────────────────
    "every model carries exactly the catalogue's fields, no more and no fewer" =
      all (e: sorted (lib.attrNames e) == sorted entryFields);

    "every licence carries exactly its four fields" =
      all (e: sorted (lib.attrNames e.licence) == sorted licenceFields);

    "every model has a display name, and no two share one" =
      all (e: nonEmpty e.name)
      && lib.length (lib.unique (map (e: e.name) entries)) == lib.length entries;

    "every model has a note saying why it is in the catalogue at all" =
      all (e: nonEmpty e.note);

    # ── The evidence rule ─────────────────────────────────────────────────────────────────────
    "every model records at least one primary source, and every source is a fetchable URL" =
      all (e: e.sources != [ ] && lib.all isUrl e.sources);

    "a repository id is an id and never a URL" =
      all (e: isRepoId e.hfRepo);

    "upstream is a URL" =
      all (e: isUrl e.upstream);

    "every unestablished fact is null AND named in `unverified`" =
      all (e: sorted (nullFactsOf e) == sorted (lib.attrNames e.unverified));

    "nothing is named in `unverified` that the catalogue actually states" =
      all (e: lib.all (f: lib.elem f factFields && e.${f} == null) (lib.attrNames e.unverified));

    "every `unverified` entry says what would have to be established, not merely that it is unknown" =
      all (e: lib.all (f: nonEmpty e.unverified.${f}) (lib.attrNames e.unverified));

    # ── The licence rule, which is the expensive one to get wrong ──────────────────────────────
    "commercial use is a judgement with three values and never a guess" =
      all (e: lib.elem e.licence.commercialUse [ "yes" "no" "conditional" ]);

    "a licence that does not clearly permit commercial use MUST say what it restricts" =
      all (e: e.licence.commercialUse == "yes" || nonEmpty (toString e.licence.caveat));

    "every licence is named, whether or not it has an identifier" =
      all (e: nonEmpty e.licence.name);

    "an identifier, where there is one, is the licence's whole name -- a stack of two gets none" =
      all (e: e.licence.spdx == null || e.licence.spdx == e.licence.name);

    "the catalogue holds models nobody may sell the output of, and says so" =
      lib.length (lib.filter (e: e.licence.commercialUse != "yes") entries) > 0;

    # ── No weights, no paths ──────────────────────────────────────────────────────────────────
    # This repository says WHICH model a workload serves. Where the file lives is a value, and a
    # value that leaked in here would be published.
    "no absolute path appears anywhere in the voice catalogue, prose included" =
      lib.all (s: !(hasPathToken s)) (allStrings voices);

    # ── The seam between the two catalogues ───────────────────────────────────────────────────
    "every model an application serves is one this catalogue holds" =
      lib.all (a: lib.all (m: voices ? ${m}) a.serves) (lib.attrValues applications);

    "an application that serves a model requiring a device says it burns one" =
      lib.all
        (a: lib.all (m: voices.${m}.needsGpu != true || a.gpu) a.serves)
        (lib.attrValues applications);

    # A workload whose model set is content names none, and that is the shape of the split rather
    # than an omission: one application here runs whatever a deployment installed into it.
    "an application may serve no named model, and at least one does not" =
      lib.any (a: a.serves == [ ]) (lib.attrValues applications);

    "and at least one does, or the second catalogue is reachable by nobody" =
      lib.any (a: a.serves != [ ]) (lib.attrValues applications);
  };

  failed = lib.filter (n: !results.${n}) (lib.attrNames results);
in
pkgs.runCommand "nixcreative-voices-eval" { } (
  if failed == [ ]
  then ''
    echo "nixcreative: all ${toString (lib.length (lib.attrNames results))} voice-catalogue properties hold across ${toString (lib.length names)} models"
    touch $out
  ''
  else ''
    # A QUOTED HEREDOC, not a series of `echo` calls. A property name is prose written by whoever
    # added the property, and prose contains backticks -- which inside a double-quoted shell string
    # are command substitution. The naive form silently ate every name it was supposed to print.
    echo "nixcreative voices-eval FAILED (${toString (lib.length failed)}/${toString (lib.length (lib.attrNames results))}):" >&2
    cat >&2 <<'PROPERTIES'
    ${lib.concatMapStringsSep "\n" (n: "  - " + n) failed}
    PROPERTIES
    exit 1
  ''
)
