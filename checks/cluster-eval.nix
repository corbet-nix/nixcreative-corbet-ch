# SPDX-License-Identifier: MIT OR Apache-2.0
# Proves the cluster module resolves what it claims and REFUSES what it claims to refuse, both
# directions, through the real renderer and the real app grammar.
#
# Both halves matter and neither is enough alone. A guard nobody has watched fire is a comment; a
# guard that fires on everything is a wall. So every case below is a complete, otherwise-valid
# surface with exactly one thing wrong, and the `control` case is the same shape with nothing wrong
# and MUST render -- without it, a typo in the shared base would make every other case "pass" for
# the wrong reason.
#
# SOME OF THE REFUSALS ARE NOT GUARDS AT ALL. Naming an application the catalogue does not hold,
# saying a workload needs the card, and saying where inside the container a directory lives all fail
# as a type error or an unknown option -- not as assertions. That is the
# stronger kind: a boundary nobody has to remember, because it is unwritable rather than refused.
# `tryEval` cannot tell those apart from a guard, so the ones that ARE guards additionally have
# their message asserted by content.
{ pkgs, lib, nixidy, appsModule, clusterModule, values }:

let
  base = import values;
  voices = (import ../lib/voices.nix { }).voices;

  mkEnv = v: nixidy.lib.mkEnv {
    inherit pkgs;
    modules = [ appsModule clusterModule v ];
  };

  # `tryEval` alone forces only WHNF. Forcing the derivation path is what actually runs the module
  # system's type checks and the assertions underneath.
  renders = v: (builtins.tryEval (builtins.seq (mkEnv v).environmentPackage.drvPath true)).success;

  # An assertion fired, AND it is the one meant: a refusal that happens for an unrelated reason is
  # a false pass, which is exactly the failure this repository's checks exist to make impossible.
  failsWith = infix: v:
    let
      r = builtins.tryEval (lib.any
        (a: !a.assertion && lib.hasInfix infix a.message)
        (mkEnv v).config.nixidy.assertions);
    in
    r.success && r.value;

  warnsWith = infix: v:
    let
      r = builtins.tryEval (lib.any
        (w: w.when && lib.hasInfix infix w.message)
        (mkEnv v).config.nixidy.warnings);
    in
    r.success && r.value;

  # A surface with nothing declared at all, to prove the module is inert until something asks --
  # including that a platform whose namespace and project are REQUIRED does not have to be filled
  # in by a consumer who declares no workload.
  emptyCfg = (mkEnv {
    nixidy.target.repository = "https://example.com/example-org/example-gitops.git";
    nixidy.target.branch = "main";
  }).config;

  goodCfg = (mkEnv base).config;

  with' = f: lib.recursiveUpdate base f;

  results = {
    # ── The control, and the floor ────────────────────────────────────────────────────────────
    "the example surface renders -- without this every refusal below could pass for the wrong reason" =
      renders base;

    "an undeclared surface renders no apps at all, rather than a default one" =
      emptyCfg.nixk3s.apps == { };

    "every declared workload reaches the grammar" =
      lib.sort (a: b: a < b) (lib.attrNames goodCfg.nixk3s.apps)
      == [ "example-cloning" "example-graphs" "example-narration" "example-studio" ];

    "the established slot report is preserved by the shared factory" =
      goodCfg.nixcreative.clusterSlots == {
        example-cloning = 15;
        example-graphs = 12;
        example-narration = 14;
        example-studio = 13;
      };

    "the catalogue supplies the port, and the declaration never states one" =
      goodCfg.nixk3s.apps.example-graphs.ports.http.number == 8188
      && goodCfg.nixk3s.apps.example-studio.ports.http.number == 8188;

    "a version becomes the tag, and a whole reference overrides it" =
      goodCfg.nixk3s.apps.example-graphs.image == "yanwk/comfyui-boot:0.0.0"
      && lib.hasInfix "@sha256:" goodCfg.nixk3s.apps.example-studio.image;

    "the catalogue supplies WHERE a directory lives and the declaration supplies WHAT BACKS IT" =
      goodCfg.nixk3s.apps.example-graphs.state.models.mountPath == "/root/ComfyUI/models"
      && goodCfg.nixk3s.apps.example-graphs.state.models.hostPath == "/example/weights"
      && goodCfg.nixk3s.apps.example-studio.state.models.mountPath == "/root/ComfyUI/models"
      && goodCfg.nixk3s.apps.example-studio.state.models.claim == "example-weights";

    # THE CATALOGUE'S OWN SHAPE, asserted where the translator reads it. Every entry answers every
    # question this module asks, including the ones whose honest answer is "none" -- an entry that
    # simply omitted `hook` would not be a workload without a hook point, it would be an attribute
    # error thrown from inside the renderer, on a path nobody was looking at.
    "every catalogued application answers every question the translator asks of it" =
      let
        catalogue = (import ../lib/applications.nix { }).applications;
        asked = [
          "image"
          "ports"
          "primaryPort"
          "gpu"
          "state"
          "mustExist"
          "outputState"
          "hook"
          "serves"
          "authenticates"
          "env"
          "args"
          "readiness"
          "note"
        ];
      in
      lib.all (e: lib.all (f: e ? ${f}) asked) (lib.attrValues catalogue);

    # ── The hook point, built out of both halves ──────────────────────────────────────────────
    #
    # NEITHER SIDE COULD HAVE WRITTEN THIS CONTAINER. The catalogue holds the path, the directory it
    # lives in and the reason a projection cannot be mounted there, and holds no object name and no
    # image; the declaration holds an object name and an image, and holds no path. What comes out is
    # a container and a volume, and every string in it is derived rather than restated.
    "the hook's container is named off the catalogue's one word, and never spelled by a declaration" =
      let init = goodCfg.nixk3s.apps.example-graphs.init; in
      lib.length init == 1 && (lib.head init).name == "pre-start-install";

    "its image is the declaration's, and nothing here picks one" =
      (lib.head goodCfg.nixk3s.apps.example-graphs.init).image
      == "busybox:stable@sha256:2222222222222222222222222222222222222222222222222222222222222222";

    "it copies the catalogue's path and makes it executable, because a projection cannot be chmodded" =
      (lib.head goodCfg.nixk3s.apps.example-graphs.init).command == [
        "sh"
        "-c"
        ("mkdir -p /root/user-scripts && cp /pre-start-src/pre-start.sh /root/user-scripts/pre-start.sh"
        + " && chmod +x /root/user-scripts/pre-start.sh")
      ];

    "and it writes onto the durable directory the catalogue named, at the catalogue's own path" =
      # Read as paths rather than as whole mount records: the grammar's mount type carries defaults
      # this module never states, and comparing against them would be asserting its schema, not ours.
      lib.mapAttrs (_: ms: map (m: m.mountPath) ms)
        (lib.head goodCfg.nixk3s.apps.example-graphs.init).mounts == {
        home = [ "/root" ];
        pre-start = [ "/pre-start-src" ];
      };

    "the ConfigMap is NAMED and never carried, on a volume no application container reads" =
      goodCfg.nixk3s.apps.example-graphs.state.pre-start.configMap == "example-pre-start"
      && goodCfg.nixk3s.apps.example-graphs.state.pre-start.mountPath == null;

    "a workload that plants no hook renders no container for one, rather than an empty list of them" =
      goodCfg.nixk3s.apps.example-studio.init == [ ]
      && !(goodCfg.nixk3s.apps.example-studio.state ? pre-start);

    # ── The manifest-name seam ────────────────────────────────────────────────────────────────
    "a rename reaches the manifest and stops there: the path inside the container is still the catalogue's" =
      goodCfg.nixk3s.apps.example-studio.state ? example-renders
      && goodCfg.nixk3s.apps.example-studio.state.example-renders.mountPath == "/images-out"
      && !(goodCfg.nixk3s.apps.example-studio.state ? output);

    "and a workload that renames nothing carries the catalogue's names unchanged" =
      lib.sort (a: b: a < b) (lib.attrNames goodCfg.nixk3s.apps.example-graphs.state)
      == [ "home" "models" "output" "pre-start" ];

    "needing the card is a catalogue fact, and it reaches the grammar as one" =
      goodCfg.nixk3s.apps.example-graphs.gpu
      && goodCfg.nixk3s.apps.example-studio.gpu;

    # THE ONE PROPERTY THE TIER IS SPLIT FOR. Three of the four workloads burn the card and one
    # does not, and the list has to say so -- a repository that treated "creative workload" as a
    # synonym for "device tenant" would hand the arbiter underneath a name it must never scale for
    # VRAM, and would leave the cheap half of the voice tier competing for a resource it does not
    # use.
    "the module knows which of its workloads hold a device, without deciding anything about one" =
      lib.sort (a: b: a < b) goodCfg.nixcreative.clusterDeviceTenants
      == [ "example-cloning" "example-graphs" "example-studio" ];

    "and the half that does not burn the card is absent from that list rather than merely last" =
      !(lib.elem "example-narration" goodCfg.nixcreative.clusterDeviceTenants);

    "the catalogue supplies each voice port, and neither declaration states one" =
      goodCfg.nixk3s.apps.example-narration.ports.http.number == 8880
      && goodCfg.nixk3s.apps.example-cloning.ports.http.number == 8004;

    # ── The model half ────────────────────────────────────────────────────────────────────────
    "which model a workload serves reaches the consumer, keyed into the voice catalogue" =
      goodCfg.nixcreative.clusterVoices == {
        example-narration = [ "kokoro-82m" ];
        example-cloning = [ "chatterbox" ];
      };

    "a workload whose model set is CONTENT names no model at all, rather than an empty guess" =
      !(goodCfg.nixcreative.clusterVoices ? example-graphs);

    "every model a declared workload serves is one the voice catalogue actually holds" =
      lib.all (m: voices ? ${m}) (lib.flatten (lib.attrValues goodCfg.nixcreative.clusterVoices));

    "a declaration cannot choose which model a workload serves -- that is what the image IS" =
      !renders (with' { nixcreative.applications.example-narration.serves = [ "chatterbox" ]; });

    # THE LICENCE POSITION, published from the catalogue rather than from what is declared: it is
    # read BEFORE a workload exists, by whoever is choosing what to serve.
    "the licence review names every catalogued model whose licence is not plainly commercial" =
      lib.sort (a: b: a < b) (lib.attrNames goodCfg.nixcreative.voiceLicenceReview)
      == lib.sort (a: b: a < b)
        (lib.attrNames (lib.filterAttrs (_: v: v.licence.commercialUse != "yes") voices));

    "and it is not empty, because two of the catalogued models carry non-commercial weights" =
      goodCfg.nixcreative.voiceLicenceReview != { };

    "no declared workload serves weights whose licence forbids commercial use" =
      !(warnsWith "does not clearly permit commercial use" base);

    "the parent directory sorts before the one nested inside it, so no mount covers another" =
      let keys = lib.attrNames goodCfg.nixk3s.apps.example-graphs.state; in
      lib.take 2 keys == [ "home" "models" ];

    "a Secret is named and never carried" =
      goodCfg.nixk3s.apps.example-graphs.secrets ? example-graphs-env
      && goodCfg.nixk3s.apps.example-graphs.secrets.example-graphs-env.envFrom;

    "a deployment's own numbers reach the container, and the catalogue supplies none of them" =
      goodCfg.nixk3s.apps.example-graphs.resources.limits.memory == "2Gi"
      && goodCfg.nixk3s.apps.example-studio.resources.limits == { };

    # ── Unwritable, not merely refused ────────────────────────────────────────────────────────
    "an application the catalogue does not hold is not a value this option has" =
      !renders (with' { nixcreative.applications.example-graphs.app = "nonesuch"; });

    "a declaration cannot say that a workload needs the card -- that is not one of its options" =
      !renders (with' { nixcreative.applications.example-graphs.gpu = false; });

    "a declaration cannot say where inside the container a directory lives" =
      !renders (with' { nixcreative.applications.example-graphs.state.models.mountPath = "/elsewhere"; });

    # ── The guards, each with its message asserted ────────────────────────────────────────────
    # A VERSION AND A WHOLE REFERENCE ARE TWO WAYS TO SAY ONE THING, and saying neither is the
    # mistake. It is a guard rather than a required option because for a workload pinned by digest,
    # and for one whose catalogue entry publishes no repository at all, a version has nothing to
    # hang on -- so demanding one there would be demanding a value nobody can supply honestly.
    "a workload with neither a version nor a whole reference is refused" =
      failsWith "states neither a version nor a whole image reference"
        (lib.recursiveUpdate base { nixcreative.applications.example-graphs.version = lib.mkForce null; });

    "and a whole reference alone renders, with nothing invented to stand in for a version" =
      goodCfg.nixk3s.apps.example-studio.image
      == "registry.example.com/example-org/example-graphs:0.0.0@sha256:0000000000000000000000000000000000000000000000000000000000000000";

    "backing a directory the application does not use is refused" =
      failsWith "must back every directory it uses"
        (with' { nixcreative.applications.example-studio.state.nowhere.hostPath = "/example/nope"; });

    "leaving a directory it DOES use unbacked is refused" =
      failsWith "must back every directory it uses"
        (lib.recursiveUpdate base { nixcreative.applications.example-studio.state = lib.mkForce { }; });

    "a directory backed by both a claim and a node path is refused" =
      failsWith "EITHER an existing claim OR a node path"
        (with' { nixcreative.applications.example-graphs.state.models.claim = "example-claim"; });

    "weights on a node path that is created when missing is refused, because empty is the failure" =
      failsWith "must already exist before the workload starts"
        (with' { nixcreative.applications.example-graphs.state.models.hostPathType = "DirectoryOrCreate"; });

    "an override that stops routing renders into the directory it backs is refused" =
      failsWith "nothing it is told mentions that path"
        (with' { nixcreative.applications.example-graphs.env.CLI_ARGS = "--listen 0.0.0.0"; });

    # AN APPLICATION NOBODY PUBLISHES AN IMAGE OF. The catalogue carries no repository for it --
    # upstream ships a build recipe written against one vendor's compute runtime, so the container a
    # cluster runs is one it built -- and a version with nothing to hang on is not an image.
    "a workload whose catalogue publishes no image is refused without a whole reference" =
      failsWith "has no image reference anybody publishes"
        (lib.recursiveUpdate base { nixcreative.applications.example-cloning.image = lib.mkForce null; });

    "and the same declaration renders as soon as it carries one" =
      renders base;

    "two workloads anchoring one namespace is refused" =
      failsWith "Exactly one workload may create a namespace"
        (with' { nixcreative.applications.example-studio.createNamespace = true; });

    "a second namespace is anchored independently, and anchoring it twice is refused too" =
      failsWith "is anchored by 2 applications"
        (with' { nixcreative.applications.example-cloning.createNamespace = true; });

    "two workloads on one slot is refused" =
      failsWith "is claimed by 2 applications"
        (with' { nixcreative.applications.example-studio.slot = 12; });

    "supplying a hook to an application whose image reads no such path is refused" =
      failsWith "has no hook point"
        (with' {
          nixcreative.applications.example-narration.hook = {
            configMap = "example-pre-start";
            installerImage = "busybox:stable@sha256:2222222222222222222222222222222222222222222222222222222222222222";
          };
        });

    "half a hook is refused, because one half alone starts the workload without it and says nothing" =
      failsWith "names only half of a hook"
        (with' { nixcreative.applications.example-studio.hook.configMap = "example-pre-start"; });

    "two directories renamed onto one manifest name is refused" =
      failsWith "more than one volume on the manifest name"
        (with' { nixcreative.applications.example-studio.state.home.volumeName = "example-renders"; });

    "a rename the API server would reject as a name is refused here rather than at apply" =
      failsWith "lowercase DNS label"
        (with' { nixcreative.applications.example-studio.state.home.volumeName = "Example_Renders"; });

    # ── The warnings that are not refusals ────────────────────────────────────────────────────
    # Both of these are real mistakes and neither is an eval error, for the same reason: what makes
    # them mistakes is something one deployment can see and this repository cannot.
    "scale-to-zero with no wake front warns rather than refuses" =
      warnsWith "nothing brings it back"
        (with' { nixcreative.applications.example-graphs.wake = lib.mkForce null; });

    "exposing an application that authenticates nobody warns rather than refuses" =
      let v = with' { nixcreative.applications.example-studio.exposure = "public"; }; in
      warnsWith "authenticates nobody" v && renders v;

    # THE CATALOGUE'S NAMES CARRY A CONSTRAINT, not just a vocabulary: a parent sorts before the
    # directory nested inside it, because a shallower mount emitted last covers the deeper one. A
    # rename is allowed to break that -- a live object's names were not chosen with it in mind --
    # and is not allowed to break it quietly.
    "a rename that puts a directory before the one it lives inside warns" =
      warnsWith "now sorts before"
        (with' { nixcreative.applications.example-graphs.state.home.volumeName = "root"; });

    "and neither warning fires on the example surface itself" =
      !(warnsWith "nothing brings it back" base)
      && !(warnsWith "authenticates nobody" base)
      && !(warnsWith "now sorts before" base);
  };

  failed = lib.filter (n: !results.${n}) (lib.attrNames results);
in
pkgs.runCommand "nixcreative-cluster-eval" { } (
  if failed == [ ]
  then ''
    echo "nixcreative: all ${toString (lib.length (lib.attrNames results))} cluster-eval properties hold"
    touch $out
  ''
  else ''
    # A QUOTED HEREDOC, not a series of `echo` calls: a property name is prose, prose contains
    # backticks, and a backtick inside a double-quoted shell string is command substitution.
    echo "nixcreative cluster-eval FAILED (${toString (lib.length failed)}/${toString (lib.length (lib.attrNames results))}):" >&2
    cat >&2 <<'PROPERTIES'
    ${lib.concatMapStringsSep "\n" (n: "  - " + n) failed}
    PROPERTIES
    exit 1
  ''
)
