# SPDX-License-Identifier: MIT OR Apache-2.0
#
# nixcreative's cluster surface: declare which generative-media applications run in the cluster,
# and render them.
#
# ── THIS MODULE DOES NOT IMPLEMENT KUBERNETES, AND THAT IS THE DESIGN ──────────────────────────
#
# A sibling repository's whole subject is the app grammar: a workload declares WHAT IT NEEDS -- an
# image, ports, an exposure class, whether it may sleep, whether it needs a graphics device, which
# directories it reads and writes and what backs them -- and that grammar renders the Argo CD
# Application, the Namespace, the Deployment and the Service. Everything expressible in those terms
# is expressed in them: this module DEFINES INTO `nixk3s.apps` and renders no Kubernetes object of
# its own.
#
# So it is a translator. What it adds is the one thing the grammar cannot know: what these
# particular applications ARE. Which directory holds weights and is therefore useless empty; which
# argument routes the product of the work somewhere durable; how patient a probe has to be before
# it is calling a fifteen-minute start a failure; whether anybody has to log in.
#
# IMPORT THE GRAMMAR ALONGSIDE IT. `nixk3s.apps` is declared there, not here, and a render that
# composes this module without it fails with "the option `nixk3s.apps' does not exist".
#
# ── THE KNOWLEDGE/VALUE SPLIT, ENFORCED RATHER THAN TRUSTED ────────────────────────────────────
#
# `lib/applications.nix` holds what is true of the software anywhere. A declaration holds what is
# true of one cluster. The two cannot supply each other's half, and the guards below are what makes
# that a rule rather than a habit: the catalogue says WHERE inside the container a directory lives
# and only a declaration can say WHAT BACKS IT, so a workload whose weights live on a node path is
# refused when nothing backs it rather than quietly rendered onto a pod's ephemeral filesystem.
#
# TWO TERMS THAT LOOK LIKE THEY CROSS THE LINE AND DO NOT. `hook` is one need split across both
# halves: an image reads a script off a path before it starts (knowledge -- the path, the directory
# it lives in, and why a read-only projection mounted there aborts startup), and a deployment names
# the object holding the script and the image that copies it (values -- an object name and a
# registry reference, neither of which is a fact about the software). What this module builds out of
# the two is a volume and an init container; neither side wrote a pod spec, and neither could have.
#
# `state.<name>.volumeName` is the other, and it is narrower than it looks: it renames a volume IN
# THE MANIFEST and nothing else. Where the directory lives inside the container stays the
# catalogue's, so this cannot become a second vocabulary for the same directories -- it exists
# because a volume name is a manifest identifier rather than a fact, and renaming one on a live
# workload rewrites the pod template for the sake of a word. The catalogue still chooses names so
# that a parent sorts before the directory nested inside it, and a rename that inverts such a pair
# is warned about rather than quietly taken.
#
# THE DEVICE IS THE SHARPEST CASE OF THE SPLIT. The catalogue says the process puts work on a
# graphics device. It does not say what the cluster calls that device, how many exist, or who
# yields it -- those are four fleet facts, they live wherever the fleet is described, and the
# grammar underneath refuses to render a device request until the site has named its own.
#
# ── THE MODEL HALF ─────────────────────────────────────────────────────────────────────────────
#
# `lib/voices.nix` says WHICH speech model an application serves, where the model is the thing the
# image was built around rather than content loaded into it. This module does three things with
# that and no more: it refuses a catalogue entry that names a model nobody catalogued, it publishes
# what the declared workloads serve so a consumer does not have to re-derive it, and it warns when
# a declared workload serves weights whose licence does not clearly permit commercial use. The last
# one warns rather than refuses for the usual reason -- non-commercial use is perfectly legitimate
# and whether THIS deployment is commercial is not a fact this repository can see -- but it is not
# silent either, because a licence read wrong is the expensive kind of mistake.
{ mkConsumerModule }:
{ config, lib, ... }:

let
  cfg = config.nixcreative;
  platform = cfg.clusterPlatform;
  catalogue = (import ../lib/applications.nix { }).applications;
  # The shared factory can enforce an unauthenticated-exposure policy from catalogue knowledge,
  # but nixcreative's established contract deliberately WARNS instead of refusing and has a more
  # specific sentence about the operator session at stake. Keep that decision in the domain tail:
  # the factory sees this normalized view while every report and warning below reads the original.
  factoryCatalogue = lib.mapAttrs (_: entry: entry // { authenticates = true; }) catalogue;
  voices = (import ../lib/voices.nix { }).voices;

  declared = lib.filterAttrs (_: w: w.enable) cfg.applications;
  workloads = lib.mapAttrsToList (name: w: { inherit name w; entry = catalogue.${w.app}; }) declared;

  # A catalogue reason is written as a paragraph and quoted back inside a one-line message.
  oneLine = s: lib.concatStringsSep " " (lib.filter (x: x != "") (lib.splitString "\n" s));

  # WHAT A VOLUME IS CALLED IN THE MANIFEST, which is not the same question as what the directory
  # IS. The catalogue's key is the name and the default; a declaration overrides it for exactly one
  # reason -- a live object already carries a different one, and a rename is a rollout. It reaches
  # the manifest and nothing else: the path inside the container stays the catalogue's, so this
  # cannot become a second, competing vocabulary for the same directories.
  volumeNameOf = key: backing: if backing.volumeName != null then backing.volumeName else key;

  # ── The hook point ────────────────────────────────────────────────────────────────────────────
  #
  # The catalogue says an image reads a script off a path before it starts, which of the
  # application's own directories that path lives in, and why a read-only projection mounted there
  # aborts startup instead of working. A declaration says which object holds the script and which
  # image copies it. What comes out is a VOLUME and a CONTAINER this module builds -- neither side
  # wrote a pod spec, and neither could have: the catalogue has no object names and the declaration
  # has no paths.
  #
  # The catalogue's one word names all three things a manifest needs a name for, so a declaration
  # never spells a container, a volume or a scratch mount path.
  hookOf = entry: w:
    if entry.hook == null || w.hook.configMap == null then null
    else
      let
        h = entry.hook;
        source = "/${h.name}-src";
        key = baseNameOf h.path;
      in
      rec {
        volume = h.name;
        installer = "${h.name}-install";
        inherit source key;

        # COPIED AND MADE EXECUTABLE, which is the whole reason a container exists here rather than
        # a mount: the image runs `chmod +x` on this file before sourcing it, and that is what fails
        # on the read-only projection the ConfigMap would otherwise be.
        command = lib.concatStringsSep " && " [
          "mkdir -p ${builtins.dirOf h.path}"
          "cp ${source}/${key} ${h.path}"
          "chmod +x ${h.path}"
        ];

        # The durable volume it writes onto, under whatever name this deployment's manifest calls
        # it, mounted at the catalogue's own path for that directory.
        onto = {
          name =
            if w.state ? ${h.state}
            then volumeNameOf h.state w.state.${h.state}
            else h.state;
          mountPath = entry.state.${h.state} or null;
        };
      };

  hookVolumeOf = entry: w:
    let h = hookOf entry w; in
    lib.optionalAttrs (h != null) {
      # NAMED, never carried: the ConfigMap's content is a file's text, and nothing in this
      # repository can hold one. Nothing here creates the object either.
      ${h.volume}.configMap = w.hook.configMap;
    };

  hookInitOf = entry: w:
    let h = hookOf entry w; in
    lib.optional (h != null) {
      name = h.installer;
      image = w.hook.installerImage;
      command = [ "sh" "-c" h.command ];
      mounts = {
        ${h.onto.name} = [{ mountPath = h.onto.mountPath; }];
        ${h.volume} = [{ mountPath = h.source; }];
      };
    };

  # Whole Secrets, loaded wholesale. Nothing here can carry a secret's CONTENT, which is what makes
  # a declaration written against this module safe to publish.
  secretsOf = w:
    lib.listToAttrs (map (s: lib.nameValuePair s { secret = s; envFrom = true; }) w.envFromSecrets);

  envOf = entry: w: entry.env // w.env;
  argsOf = entry: w: entry.args ++ w.args;

  # Everything the process is TOLD, as one list of strings: the environment it is handed and the
  # command line it is given. What the output guard reads.
  toldOf = entry: w: lib.attrValues (envOf entry w) ++ argsOf entry w;

  # The factory owns the common catalogue projection. This tail carries only the three established
  # declaration shapes that are intentionally outside its common surface: whole-Secret imports,
  # the legacy nested resource record, and the catalogue/declaration split hook recipe above.
  extendApp = { app, entry, w, ... }:
    app
    // {
      # The hook's volume is one this module builds, not one a declaration backs, so it is added
      # AFTER the shared state guard has compared the declaration with the catalogue.
      state = app.state // hookVolumeOf entry w;
      secrets = secretsOf w;
      resources = w.resources;
    }
    # A LIST, and it stays one: the kubelet runs init containers in written order, so for them the
    # order is the semantics. One entry today, and anything this module ever adds below it runs
    # after it.
    // lib.optionalAttrs (hookInitOf entry w != [ ]) { init = hookInitOf entry w; };

  # ── Assertions ────────────────────────────────────────────────────────────────────────────────

  stateAssertions = lib.concatMap
    (x:
      let inherit (x) name w entry; in
      [
        {
          assertion = lib.attrNames w.state == lib.attrNames entry.state;
          message =
            "nixcreative: application `${name}` must back every directory it uses, and backs "
            + (if w.state == { } then "none" else lib.concatMapStringsSep ", " (k: "`${k}`") (lib.attrNames w.state))
            + ". It uses: "
            + (if entry.state == { } then "nothing"
            else lib.concatStringsSep ", " (lib.mapAttrsToList (k: p: "`${k}` at ${p}") entry.state))
            + ".";
        }
        {
          assertion = lib.all
            (backing: (backing.claim == null) != (backing.hostPath == null))
            (lib.attrValues w.state);
          message =
            "nixcreative: application `${name}` must back each directory with EITHER an existing claim OR a "
            + "node path, never both and never neither. A directory with no backing is a pod's own "
            + "filesystem, which is discarded on every restart -- and a workload that sleeps restarts "
            + "every time somebody wakes it.";
        }
      ])
    workloads;

  # THE GUARD FOR AN EMPTY DIRECTORY THAT IS NOT AN ERROR ANYWHERE ELSE. A node path created on
  # demand is a directory with nothing in it, and nothing in Kubernetes, in the kubelet or in the
  # application treats that as a failure -- so the catalogue names the directories where empty is
  # the whole problem, and this refuses the backing that produces one. It reads the reason out of
  # the catalogue rather than restating it, so there is exactly one copy of why.
  #
  # A CLAIM IS NOT CHECKED, and that is the honest boundary rather than an omission: whether a
  # volume already holds weights is a fact about storage this repository cannot see. `hostPathType`
  # is a fact it can.
  existenceAssertions = lib.concatMap
    (x:
      let inherit (x) name w entry; in
      lib.mapAttrsToList
        (key: reason: {
          assertion =
            let backing = w.state.${key} or null; in
            backing == null
            || backing.hostPath == null
            || !(lib.hasSuffix "OrCreate" backing.hostPathType);
          message =
            "nixcreative: application `${name}` backs `${key}` with a node path that is created when it is "
            + "missing, and `${key}` must already exist before the workload starts: "
            + oneLine reason
            + ". Use a `hostPathType` that refuses to start on a missing path.";
        })
        entry.mustExist)
    workloads;

  # THE GUARD FOR WORK THAT LANDS NOWHERE. The catalogue routes the product of the work into one of
  # the directories it declares, by telling the process a path -- and the environment a declaration
  # supplies is merged OVER the catalogue's, so an override of the wrong variable silently unhooks
  # the two. Nothing fails when that happens: renders are produced, reported, and written onto the
  # container's own filesystem, where they survive exactly until the pod restarts.
  outputAssertions = lib.concatMap
    (x:
      let
        inherit (x) name w entry;
        key = entry.outputState;
        path = entry.state.${key} or null;
      in
      lib.optional (key != null) {
        assertion = path != null && lib.any (t: lib.hasInfix path t) (toldOf entry w);
        message =
          "nixcreative: application `${name}` writes its output into `${key}` at ${toString path}, and "
          + "nothing it is told mentions that path. The catalogue points the process at that directory "
          + "with an argument; a declaration whose `env` or `args` replaces that argument without "
          + "repeating the path leaves every render on the pod's own filesystem, discarded at the next "
          + "restart.";
      })
    workloads;

  # THE GUARD FOR AN APPLICATION NOBODY PUBLISHES AN IMAGE OF. Most of what runs here has a
  # community container somebody maintains, and for those the catalogue names the repository and a
  # declaration names the version. For the rest there is no reference that is true of the software
  # anywhere -- upstream ships a build recipe written against one vendor's compute runtime, and the
  # image a cluster actually runs was built by whoever runs it. `image = null` in the catalogue is
  # that fact, and this is what stops it becoming a silent hole: a version with nothing to hang it
  # on is not an image.
  imageAssertions = lib.concatMap
    (x:
      let inherit (x) name w entry; in
      lib.optional (entry.image != null)
        {
          assertion = w.image != null || w.version != null;
          message =
            "nixcreative: application `${name}` states neither a version nor a whole image reference. The "
            + "catalogue publishes the repository and never a tag -- which version to run is a deployment's "
            + "choice and there is no default anybody could pick, because a moving tag on a workload this "
            + "slow to start is two syncs of one tree running different code.";
        }
      ++ lib.optional (entry.image == null) {
        assertion = w.image != null;
        message =
          "nixcreative: application `${name}` has no image reference anybody publishes -- upstream ships a "
          + "build recipe rather than a container, so every cluster runs one it built -- and this "
          + "declaration supplies none. Give it a whole `image` reference; a `version` alone has no "
          + "repository to hang on. Pin it by digest if you can: a cold start here is measured in minutes, "
          + "so a moving tag is a debugging session nobody can reproduce.";
      })
    workloads;

  # THE GUARD FOR A MODEL NOBODY CATALOGUED. `serves` is the seam between the two catalogues in
  # `lib/`, and a seam nothing checks is a typo waiting to be read as a fact. This one cannot fire
  # on a declaration -- which model an application serves is knowledge, not a value -- so what it
  # protects is an edit to `lib/applications.nix` that names a model `lib/voices.nix` does not
  # hold, which would otherwise surface as an attribute error from inside the renderer or, worse,
  # as nothing at all.
  servesAssertions = lib.concatMap
    (x:
      let inherit (x) name entry; in
      map
        (m: {
          assertion = voices ? ${m};
          message =
            "nixcreative: application `${name}` serves `${m}`, which is not in the voice catalogue. "
            + "Catalogued models: " + lib.concatStringsSep ", " (lib.attrNames voices) + ".";
        })
        entry.serves)
    workloads;

  # THE GUARD FOR TWO DIRECTORIES ON ONE MANIFEST NAME. Renaming a volume is how a declaration
  # matches a live object, and two renames that land on one word is not a merge: the later one
  # silently replaces the earlier, and the application comes up with a directory mounted where
  # another one belongs. The hook's own volume is counted here too, because it is a name in the
  # same space even though no declaration wrote it.
  volumeNameAssertions = lib.concatMap
    (x:
      let
        inherit (x) name w entry;
        h = hookOf entry w;
        names = lib.mapAttrsToList volumeNameOf w.state
          ++ lib.optional (h != null) h.volume;
        duplicated = lib.unique (lib.filter (n: lib.count (m: m == n) names > 1) names);
      in
      [
        {
          assertion = duplicated == [ ];
          message =
            "nixcreative: application `${name}` puts more than one volume on the manifest name "
            + lib.concatMapStringsSep ", " (n: "`${n}`") duplicated
            + ". A volume name is a key: the second definition replaces the first rather than joining "
            + "it, so one of the directories is mounted where another one belongs.";
        }
        {
          # A volume name is an RFC 1123 label to Kubernetes. A value that is not one is not
          # refused by anything between here and the API server, so a rename typed to match a live
          # object would render happily and be rejected at apply.
          assertion = lib.all (n: builtins.match "[a-z0-9]([-a-z0-9]*[a-z0-9])?" n != null) names;
          message =
            "nixcreative: application `${name}` renames a volume to something Kubernetes will not accept "
            + "as a name. A volume name is a lowercase DNS label -- letters, digits and dashes, starting "
            + "and ending with a letter or a digit. Nothing between here and the API server refuses it, "
            + "so the manifest renders and the apply fails.";
        }
      ])
    workloads;

  # THE GUARD FOR A HOOK NOBODY ASKED FOR, AND FOR HALF OF ONE. The catalogue decides whether an
  # application HAS a hook point -- an image either reads a path before it starts or it does not --
  # so a deployment that names a ConfigMap for an application with none is describing something that
  # would be copied onto a path nothing ever reads. And a hook is two values or it is none: a script
  # with nothing to copy it, or a copier with nothing to copy, renders a container that does nothing
  # or no container at all, silently either way.
  hookAssertions = lib.concatMap
    (x:
      let inherit (x) name w entry;h = w.hook; in
      [
        {
          assertion = (h.configMap == null) == (h.installerImage == null);
          message =
            "nixcreative: application `${name}` names only half of a hook -- "
            + (if h.configMap == null then "an installer image with no ConfigMap to copy from"
            else "a ConfigMap with no image to copy it")
            + ". Both or neither: one alone renders a workload that starts without the hook and says "
            + "nothing about it.";
        }
        {
          assertion = h.configMap == null || entry.hook != null;
          message =
            "nixcreative: application `${name}` supplies a hook, and its catalogue entry has no hook "
            + "point -- nothing in that image reads a script off a path before it starts, so the file "
            + "would be copied onto a path nobody looks at. Whether an image has such a point is "
            + "knowledge and lives in `lib/applications.nix`.";
        }
      ])
    workloads;

  # A namespace outlives every workload in it, so exactly one thing may own it. Two anchors is not a
  # merge, it is two Namespace objects Argo will fight over.
  anchorAssertions =
    let
      anchors = lib.filter (x: x.w.createNamespace) workloads;
      byNs = lib.groupBy (x: x.w.namespace) anchors;
    in
    lib.mapAttrsToList
      (ns: xs: {
        assertion = lib.length xs == 1;
        message =
          "nixcreative: namespace `${ns}` is anchored by ${toString (lib.length xs)} applications ("
          + lib.concatMapStringsSep ", " (x: "`${x.name}`") xs
          + "). Exactly one workload may create a namespace.";
      })
      byNs;

  slotAssertions =
    let
      claimed = lib.filter (x: x.w.slot != null) workloads;
      bySlot = lib.groupBy (x: toString x.w.slot) claimed;
    in
    lib.mapAttrsToList
      (slot: xs: {
        assertion = lib.length xs == 1;
        message =
          "nixcreative: slot ${slot} is claimed by ${toString (lib.length xs)} applications ("
          + lib.concatMapStringsSep ", " (x: "`${x.name}`") xs
          + "). A slot is one identity in several address spaces at once; two workloads on one number "
          + "is two workloads on one address.";
      })
      bySlot;

  # A warning is `{ when; message; }` -- the renderer decides whether to print it, so the condition
  # travels with the text rather than being applied here.
  # A workload's licence position, which is a property of the WEIGHTS it serves and not of the
  # software serving them. Warned rather than refused, and the reason is not squeamishness: running
  # a non-commercial model for non-commercial work is exactly what its licence is for, and whether
  # this deployment is commercial is not visible from here. What is visible is which weights are
  # about to be served, so the render says so out loud rather than leaving it to whoever reads the
  # model card next.
  licenceWarnings = lib.concatMap
    (x:
      let inherit (x) name entry; in
      lib.concatMap
        (m:
          let v = voices.${m} or null; in
          lib.optional (v != null && v.licence.commercialUse != "yes") {
            when = true;
            message =
              "nixcreative: application `${name}` serves ${v.name} (${v.hfRepo}), whose licence "
              + "(${v.licence.name}) does not clearly permit commercial use: "
              + oneLine (toString v.licence.caveat)
              + " This warns rather than refuses -- non-commercial use is what such a licence is for, and "
              + "whether this deployment is commercial is not something this repository can see.";
          })
        entry.serves)
    workloads;

  warnings = lib.concatMap
    (x:
      let inherit (x) name w entry; in
      [
        {
          when = w.scaling == "scale-to-zero" && w.wake == null;
          message =
            "nixcreative: application `${name}` is declared scale-to-zero with no wake front, so nothing "
            + "brings it back. At zero replicas that is not an idle workload, it is an unreachable one.";
        }
        {
          when = !entry.authenticates && w.exposure == "public";
          message =
            "nixcreative: application `${name}` authenticates nobody and is declared `public`. Every "
            + "visitor gets the operator's own session, on a workload that executes graphs beside the "
            + "weights and the output directory. This warns rather than refuses because whether an "
            + "authenticating front sits between it and the world is something a deployment can see and "
            + "this repository cannot -- if there is none, close it.";
        }
      ])
    workloads;

  commonOptions = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to render this workload. Declaring the attribute is declaring the workload, so this
        defaults to true; set false to park a declaration without rendering it.
      '';
    };

    namespace = lib.mkOption {
      type = lib.types.str;
      default = platform.namespace;
      defaultText = lib.literalExpression "config.nixcreative.clusterPlatform.namespace";
      description = "Namespace this workload lands in.";
    };

    createNamespace = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether this workload anchors its namespace. Defaults to false, because these applications
        share one namespace by default and exactly one of them may own it.
      '';
    };

    project = lib.mkOption {
      type = lib.types.str;
      default = platform.project;
      defaultText = lib.literalExpression "config.nixcreative.clusterPlatform.project";
      description = "Delivery project this workload's Application belongs to.";
    };

    slot = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.unsigned;
      default = null;
      description = ''
        THE POSITION this workload holds in the fleet's ordered identity space. Not an address --
        the layers underneath map it into however many address spaces the fleet keeps, which is
        why nothing here moves one. The VALUE is a fleet fact and belongs to the consumer.
      '';
    };

    exposure = lib.mkOption {
      type = lib.types.enum [ "internal" "nb" "public" ];
      default = "internal";
      description = ''
        Who can reach it, as a CLASS rather than an address. Defaults to the closed answer, and for
        an application the catalogue marks as authenticating nobody that default is the only one
        that is safe without something else in front of it.
      '';
    };

    scaling = lib.mkOption {
      type = lib.types.enum [ "always" "scale-to-zero" ];
      default = "always";
      description = ''
        Whether the workload may idle to zero replicas.

        The catalogue records whether sleeping is SAFE for a given application -- whether anything
        fires on a timer or watches a directory, which is what makes zero replicas lossy rather
        than merely cold. Whether it is WANTED is a deployment's call, because the wake path is one
        cluster's routing and this repository cannot see whether that path is healthy.

        For a workload that holds a graphics device the case for sleeping is stronger than idle
        capacity: a pod at zero replicas is a card another tenant can have.
      '';
    };

    wake = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "keda" "sablier" ]);
      default = null;
      description = ''
        Which front wakes it from zero. Meaningless unless `scaling = "scale-to-zero"`, and its
        absence there is warned about: nothing brings the workload back.

        FOR AN APPLICATION THAT HOLDS THE DEVICE the choice is not free, and the grammar underneath
        is where that is enforced: the first request has to be held until the pod actually holds the
        card and be answered by the application itself, because a front that admits it earlier turns
        "the device is busy" into an error at the edge.
      '';
    };

    adopt = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether this workload is TAKING OVER an object that already runs in the cluster, rather
        than creating one. Renders the Application with server-side apply and server-side diff.

        A DECLARATION'S TERM AND NOT THE CATALOGUE'S, for a reason worth stating: whether a
        Deployment of this application already exists is that cluster's history, not a fact about
        the software. The same application adopted on one cluster and created fresh on another
        differs here and in nothing else, so the catalogue has nothing to say about it.

        WHY IT MATTERS MORE HERE THAN ELSEWHERE. A rendered spec is never byte-identical to the
        YAML it replaces, the delivery layer sees that difference and acts on it, and for these
        applications acting on it is not a pod restart: durable directories force `Recreate`, so
        the old pod stops before the new one starts, and a workload holding one non-shareable
        device then re-runs a cold start measured in minutes. Server-side apply and diff shrink
        the diff to what genuinely changed instead of a client-side reconstruction of it, which is
        what makes an in-place adoption possible at all.

        It does not make the diff zero. Before pointing this at a running workload, render it,
        diff it against what the cluster is serving, and decide knowingly -- which is what
        `studies/adopting-a-running-workload.md` records having done.
      '';
    };

    state = lib.mkOption {
      default = { };
      description = ''
        What backs each directory the catalogue says this application uses, keyed by the SAME names.
        Backing a directory it does not use, or leaving one it does use unbacked, is an eval error
        rather than a surprise at runtime.
      '';
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          claim = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "An existing PersistentVolumeClaim, by name. Nothing here creates one.";
          };
          hostPath = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "A directory on the node. Pins the workload to whichever node holds it.";
          };
          hostPathType = lib.mkOption {
            type = lib.types.str;
            default = "Directory";
            description = ''
              The hostPath type, when a node path is what backs it. Defaults to the form that
              REFUSES to start on a missing path, because for most of what these applications read
              -- weights above all -- an auto-created empty directory is a workload that comes up
              healthy and can do nothing. A directory the application populates itself is the
              exception and says so by asking for one of the `OrCreate` forms; on a directory the
              catalogue marks as needing to exist, asking for one is refused.
            '';
          };
          readOnly = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              Whether the mount is read-only. A real choice for a shared model store: read-only
              costs the in-app installers that write into it and buys a workload that cannot alter
              weights other tenants read.
            '';
          };

          volumeName = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "legacy-volume-name";
            description = ''
              WHAT THIS VOLUME IS CALLED IN THE RENDERED MANIFEST, when that has to be something
              other than the name above. Defaults to the catalogue's key, which is the vocabulary
              and the right answer for anything rendered for the first time.

              IT EXISTS FOR ONE CASE: an object that is already running. A volume name is a manifest
              identifier rather than a fact about the software, and renaming one on a live workload
              rewrites the pod template -- which for an application that holds a device and takes
              minutes to start is a real outage, in exchange for a word. So a deployment adopting an
              existing object states the name that object has, and everything else about the
              directory still comes from the catalogue: the path inside the container is not
              overridable here, and cannot become a second vocabulary for the same directories.

              THE NAMES ARE NOT ONLY LABELS. The catalogue chooses them so that a parent directory
              sorts before a directory nested inside it; a rename that inverts such a pair is
              warned about rather than silently accepted.
            '';
          };
        };
      });
    };

    resources = lib.mkOption {
      default = { };
      description = ''
        What the scheduler must find for this workload and what it may not exceed. Purely a
        deployment's half -- a number here is measured on one box, against one card, with one
        model library, and nothing about it is true of the software anywhere else, which is why the
        catalogue carries none.

        A MEMORY LIMIT IS A KILL THRESHOLD and a CPU LIMIT IS A THROTTLE, and for this class of
        workload those pull opposite ways: a ceiling on memory stops a runaway model load from
        taking the node down, while a ceiling on CPU makes a bursty load slow rather than the box
        quiet.
      '';
      type = lib.types.submodule {
        options = {
          requests = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = { };
            example = { memory = "4Gi"; };
            description = "Compute the scheduler must find before it will place the pod.";
          };
          limits = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = { };
            example = { memory = "24Gi"; };
            description = "Ceilings for the workload's own container. The device is never named here.";
          };
        };
      };
    };

    env = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Environment this deployment adds, merged over whatever the catalogue sets. Values only --
        anything secret belongs in a Secret and arrives through `envFromSecrets`.

        THIS IS WHERE A CARD'S OWN QUIRKS ARRIVE. A runtime told to report a different hardware
        target is a fact about one piece of silicon, so the catalogue cannot hold it and this can.
        Overriding a variable the catalogue already sets REPLACES it, which is why the output guard
        exists: an override that drops the argument routing renders into their directory is refused
        rather than discovered later.
      '';
    };

    envFromSecrets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Secrets loaded wholesale, by name. Named rather than carried: nothing in this repository
        can hold a secret's contents, which is what makes a declaration written here publishable.
      '';
    };

    args = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Arguments appended to whatever the catalogue sets.";
    };

    hook = lib.mkOption {
      default = { };
      description = ''
        WHAT FILLS THE HOOK POINT the catalogue describes, for an application that has one -- a path
        its image reads a script off before it starts.

        TWO VALUES AND NO THIRD, and the pair is the whole term: the object that holds the script,
        and the image that copies it into place. Both are one deployment's facts. Which ConfigMap a
        cluster keeps a start-up script in is that cluster's object; which small image an operator
        trusts to run `cp` in their own pod is that operator's choice, and a public repository
        picking one would be choosing what runs in somebody else's cluster.

        NEITHER IS CONTENT. A name is not a payload: nothing here carries the script's text, which
        is what keeps a declaration written against this module publishable, and nothing here
        creates the ConfigMap either -- render it beside the application, where the consumer's own
        resources are.

        WHAT COMES OUT is a volume and an init container, both named off the one word the catalogue
        gives the hook. A declaration spells no container name, no scratch mount path and no copy
        command, because none of those are its half.

        Leaving it out plants no hook, which is a legitimate deployment: these applications start
        without one, and the catalogue says what that costs.
      '';
      type = lib.types.submodule {
        options = {
          configMap = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "example-pre-start";
            description = ''
              NAME of an existing ConfigMap holding the script under the hook file's own name.
              Nothing here creates it and nothing here can carry what is in it.
            '';
          };

          installerImage = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "busybox:stable@sha256:0000000000000000000000000000000000000000000000000000000000000000";
            description = ''
              The image that copies the script out of the projection onto the durable directory and
              makes it executable. A shell and nothing else, and WHICH shell is a deployment's.

              Pin it by digest, for a sharper reason than usual: this container runs before an
              application whose cold start is measured in minutes, so a moving tag here is a
              failure that happens once, on a wake nobody was watching.
            '';
          };
        };
      };
    };

    image = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        A whole image reference, overriding the catalogue's repository and this workload's version.
        This is where a digest pin goes, and pinning by digest is what makes two syncs of an
        identical rendered tree run identical code -- which matters more here than almost anywhere:
        a cold start of this class of workload is measured in minutes, so a moving tag is a
        debugging session nobody can reproduce.
      '';
    };
  };

  versionOption = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = ''
      Which version this workload runs, used as the tag on the catalogue's repository. Defaulted
      NOWHERE -- a floating tag is not a version anybody picked, and on a workload whose cold
      start is measured in minutes it is a debugging session nobody can reproduce.

      `null` is not "whatever is latest": it is the statement that this workload's image does
      not come from a repository plus a tag. It is the right value in exactly two cases, and
      both are refused if the declaration does not then carry a whole `image` reference -- one
      where the deployment pins by digest, and one where the catalogue publishes no repository
      at all because nobody ships a runnable container of that application.
    '';
  };

  reportOptions = {
    clusterDeviceTenants = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      default = map (x: x.name) (lib.filter (x: x.entry.gpu) workloads);
      defaultText = lib.literalExpression "every declared workload whose catalogue entry needs a graphics device";
      description = ''
        Which of the declared workloads put work on a graphics device, by declaration name. Nothing is
        rendered from it: whether the device they name is one card or eight, and what happens when two
        of them want it at once, is decided by whoever owns the hardware. This is the list that layer
        reads so it does not have to re-derive it from the catalogue and get a different answer.
      '';
    };

    clusterVoices = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      readOnly = true;
      default = lib.listToAttrs
        (map (x: lib.nameValuePair x.name x.entry.serves)
          (lib.filter (x: x.entry.serves != [ ]) workloads));
      defaultText = lib.literalExpression "every declared workload that serves a named model";
      description = ''
        workload -> the models it serves, by key into `lib/voices.nix`. Nothing is rendered from it:
        which model an application serves is baked into the image it runs, so there is no manifest
        field for it. This exists so that a consumer can answer "what voices does this cluster
        actually serve, and under what licences" from the configuration rather than by opening a
        container.

        A workload whose model set is CONTENT -- a graph editor running whatever checkpoints a
        deployment installed -- appears nowhere in here, which is the honest answer rather than an
        empty one.
      '';
    };

    voiceLicenceReview = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      default = lib.mapAttrs (_: v: v.licence.caveat)
        (lib.filterAttrs (_: v: v.licence.commercialUse != "yes") voices);
      defaultText = lib.literalExpression "every catalogued voice model whose licence is not plainly commercial-friendly";
      description = ''
        model -> what its licence restricts, for every model in the catalogue whose licence does not
        clearly permit commercial use. Derived from the catalogue and NOT from what is declared, on
        purpose: the question it answers is asked before a workload exists, by whoever is choosing
        which model to serve.

        It is a list of restrictions rather than a list of refusals. Two of the entries carry
        permissive CODE and non-commercial WEIGHTS, which is the shape that gets read wrong -- and
        one of those carries no licence tag at all, so anything that keys on the tag records it as
        unlicensed and moves on.
      '';
    };
  };

  factoryModule = mkConsumerModule {
    namespace = "nixcreative";

    roots.applications = {
      catalogue = factoryCatalogue;
      selector = "app";

      # Preserve the exact established declaration vocabulary. State is an enabled common term
      # refined to nixcreative's claim-or-hostPath subtype, so the factory still owns its renderer,
      # volume identity, mount ordering, and central guards. Resources, image, and wake retain their
      # legacy public shapes without acquiring the factory's generic resource/image/wake warnings.
      # Slot stays common so the factory is the single missing-origin warning authority.
      enabledOptions = [
        "namespace"
        "createNamespace"
        "project"
        "slot"
        "exposure"
        "scaling"
        "adopt"
        "state"
        "env"
        "args"
      ];

      extraOptions = commonOptions // { version = versionOption; };
      extend = extendApp;

      # Keep the established domain sentences executable. The shared factory now also owns the
      # structural state, image, namespace-anchor, slot, volume-name, and collision invariants;
      # these assertions retain nixcreative's sharper reasons and protect its unique hook/output
      # semantics without weakening either layer.
      assertions = _contexts:
        stateAssertions ++ existenceAssertions ++ outputAssertions ++ imageAssertions
        ++ servesAssertions ++ anchorAssertions ++ slotAssertions
        ++ volumeNameAssertions ++ hookAssertions;

      # Mount-order warnings are now factory-owned and use the same resolved volume names as the
      # renderer. These retain the two domain warnings and the voice-model licence review.
      warnings = _contexts: warnings ++ licenceWarnings;

      description = ''
        The generative-media applications that run in the cluster, keyed by a name of your choosing.

        THE ENUM IS THE PLACEMENT RULE. It is built from `lib/applications.nix`, so an application
        this repository does not catalogue is not a refused value here -- it is not a value. What
        belongs in that catalogue is what this repository's gates already decide: a tool whose output
        records judgements only its operator made, with a display mode of its own, whose working set
        is model weights. A model server that answers an API and authors nothing fails the second
        gate no matter what it is made of, and has an owner elsewhere.
      '';

      example = lib.literalExpression ''
        {
          example-graphs = {
            app = "comfyui";
            version = "0.0.0";
            exposure = "nb";
            slot = 42;
            scaling = "scale-to-zero";
            wake = "sablier";
            state.models.hostPath = "/example/weights";
            state.home = { hostPath = "/example/state/graphs"; hostPathType = "DirectoryOrCreate"; };
            state.output.hostPath = "/example/renders";
            env.HSA_OVERRIDE_GFX_VERSION = "0.0.0";
            hook = {
              configMap = "example-pre-start";
              installerImage = "busybox:stable@sha256:0000...";
            };
          };
        }
      '';
    };

    # clusterSlots is the factory's identical built-in report. The three subject-specific reports
    # retain their established names, types, defaults, ordering, and read-only contract here.
    extraNamespaceOptions = reportOptions;
  };
in
{
  imports = [ factoryModule ];
}
