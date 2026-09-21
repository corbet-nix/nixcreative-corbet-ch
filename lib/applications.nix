# SPDX-License-Identifier: MIT OR Apache-2.0
#
# The cluster catalogue: what nixcreative's cluster-side applications ARE.
#
# WHY THIS FILE EXISTS AT ALL, and it is the repository's own gate 2 finally landing somewhere.
# The placement rule says a tool whose working set includes model weights is not a package here:
# a package manager can finish installing a raster editor and it cannot finish installing a model.
# That sends the tool to the cluster. It never sent it to another SUBJECT -- generative media is
# this repository's subject on both planes -- so the cluster half belongs here, in a vocabulary
# that describes a workload instead of a workstation.
#
# WHAT BELONGS HERE. The same three gates, with gate 2 answered the other way round: the thing
# still authors a file whose contents only its operator decided (gate 1), it still has a display
# mode (gate 0), and it needs weights (gate 2) -- so it runs as a workload rather than as a
# package. A model SERVER that answers an API and authors nothing is not this repository's on
# gate 1, whatever it is made of; a media library, a transcoder or a capture pipeline is not this
# repository's on gate 1 either, and each of those has an owner already.
#
# WHAT IS KNOWLEDGE AND WHAT IS A VALUE. Everything in this file is true of the software wherever
# anyone runs it: the port it listens on, the directories it reads and writes, whether it burns a
# GPU, whether it authenticates anybody, how patient a probe has to be before it is calling a slow
# start a failure. Nothing here names an address, a node, a hostname, a namespace, a device-plugin
# resource or a card. Those are one deployment's facts and they arrive from the consumer.
#
# THE GPU IS DECLARED AS A NEED AND NEVER AS AN ALLOCATION. `gpu = true` says the process puts
# work on a graphics device. What the cluster CALLS that device, how many there are, who yields it
# and in what order are four different fleet facts, and not one of them is expressible here.
#
# AN IMAGE REFERENCE IS NOT ALWAYS A FACT ABOUT THE SOFTWARE. Where somebody publishes a runnable
# container, naming its repository here is knowledge and a deployment supplies the version. Where
# nobody does -- where upstream ships a Dockerfile written against one vendor's compute runtime and
# every operator builds their own -- there is no reference this repository could state, `image` is
# `null`, and the translator refuses a declaration that does not carry a whole one. That is the
# knowledge/value split reaching the least obvious field rather than an omission.
#
# A HOOK POINT IS THE IMAGE'S, AND ITS CONTENT IS NOT. `hook` describes a path an image reads
# before it starts, the directory that path lives in, and the reason a read-only projection cannot
# be mounted there -- three facts about a packaging, true of it wherever anyone runs it. It carries
# no script, no ConfigMap name and no installer image: what the hook SAYS is content, and content is
# not vocabulary. A deployment that wants one names the object holding it and the image that copies
# it into place, and the translator builds the container. `null` means the image reads no such path.
#
# WHICH MODEL A WORKLOAD SERVES, in `serves`, keyed into `lib/voices.nix`. It is empty for a tool
# that runs whatever weights a deployment installs into it, and it names one for an application
# that IS a model's server -- where the model is what the image was built around rather than
# content loaded into it. The distinction is the whole reason the second catalogue is voice-shaped
# and not a checkpoint list; `lib/voices.nix` opens with it.
{}:
{
  applications = {
    comfyui = {
      # A COMMUNITY PACKAGING, and that is a fact worth carrying rather than an accident. ComfyUI
      # upstream publishes source, not an image; every runnable container is somebody's assembly of
      # it, and this one is the assembly that carries a working ROCm stack. A deployment that
      # prefers a different assembly overrides the whole reference -- which is also where a digest
      # pin goes, and pinning by digest is what makes two syncs of an identical tree run identical
      # code. The catalogue carries no tag and no digest: a version is a deployment's choice.
      image = "yanwk/comfyui-boot";

      ports.http = 8188;
      primaryPort = "http";

      # IT BURNS THE CARD, which is the single fact everything else about this workload follows
      # from. Recorded as a NEED and nothing more: the device's name, its count, who yields it and
      # in what order are fleet facts, and a repository that guessed any of them would schedule a
      # pod with no device and no error.
      gpu = true;

      # WHERE, only. What backs each of these can only come from a declaration.
      state = {
        # Checkpoints, LoRAs, VAEs, embeddings, upscalers -- gigabytes of weights, read on every
        # graph execution and WRITTEN by the in-app node manager when it installs a model or a
        # node's assets. Read-only is a legitimate deployment choice and costs those installs.
        models = "/root/ComfyUI/models";

        # The container's whole writable home: the application tree, `custom_nodes`, per-node
        # configuration, saved workflows, the input directory, and the `user-scripts` hook path
        # below. It is one curated directory rather than four, because a custom node installs
        # itself as a git clone and expects the tree around it.
        #
        # IT IS CALLED `home` SO THAT IT SORTS FIRST, and that is a constraint rather than a
        # preference. The model directory lives INSIDE this one, mounts are emitted in
        # attribute-name order, and a shallower mount emitted last covers the deeper one it
        # contains -- so the parent has to sort before the child, and the only lever a catalogue
        # has over that is the name it gives the key.
        home = "/root";

        # Where finished renders land. Separate from `home` on purpose: the product of the work
        # outlives the working tree, and the argument below is what points the process at it.
        output = "/images-out";
      };

      # WHICH OF THOSE MUST ALREADY HOLD SOMETHING, keyed to the same names, with the reason the
      # guard quotes back. A node path that is created on demand is silently empty, and an empty
      # directory is not an error anywhere in this stack -- it is a workload that starts, reports
      # ready, and then cannot do the one thing it exists for.
      mustExist = {
        models = ''
          an auto-created model directory is a ComfyUI that starts happily, serves its graph
          editor, and can execute nothing: every checkpoint node fails at the moment somebody
          queues a prompt, which is minutes after the point at which anything was watching
        '';
        output = ''
          renders are the product, and an auto-created output directory is where they go when the
          real one failed to arrive -- a run that looks successful and leaves its results on a
          path nobody curates or backs up
        '';
      };

      # WHICH DIRECTORY THE PROCESS IS TOLD TO WRITE ITS PRODUCT INTO. The name of a `state` key,
      # so the guard can compare the path against what the process is actually told below; see
      # `modules/cluster.nix` for what it refuses.
      outputState = "output";

      # THE HOOK POINT THIS PACKAGING SOURCES ON EVERY START, in a shape a translator can render
      # rather than only in prose. Every field of it is true of the software wherever anyone runs
      # it: the image is what reads this path, the image is what makes it executable before sourcing
      # it, and the directory it lives in is one this catalogue already names. What the hook SAYS,
      # and which utility image copies it into place, are a deployment's and arrive from there.
      #
      # WHY THE FILE CANNOT SIMPLY BE PROJECTED ONTO THAT PATH, which is the fact that makes this a
      # term instead of a comment. A projected volume is read-only with no override; the entrypoint
      # runs `chmod +x` on the hook before sourcing it; that fails on a read-only projection and,
      # under the entrypoint's own `set -e`, aborts startup before the application ever runs. The
      # file has to be COPIED onto the writable directory named below, which is a container that
      # runs to completion before the application starts.
      hook = {
        # WHAT THE IMAGE CALLS IT. The volume that carries the content, the container that installs
        # it, and the directory that container reads it from are all named off this one word, so a
        # deployment never spells any of the three.
        name = "pre-start";

        # WHERE THE IMAGE LOOKS. Inside `home` below, which is precisely why that is the directory
        # written to and why the hook survives a restart at all.
        path = "/root/user-scripts/pre-start.sh";

        # WHICH of this application's directories that path lives in, by `state` key -- so the
        # installer writes onto the volume a declaration already backs, rather than onto a second
        # one nothing keeps.
        state = "home";
      };

      # NO NAMED MODEL, and that is a fact about this application rather than a gap. A node graph
      # runs whatever checkpoints, LoRAs and VAEs a deployment put in the directory above; the model
      # set is CONTENT, it changes on a Tuesday afternoon, and a catalogue of it would be one
      # deployment's library pretending to be knowledge. Contrast the voice tier below, where the
      # image was built around one model and swapping the model means swapping the workload.
      serves = [ ];

      # NOBODY. ComfyUI ships no login, no user model and no authorization of any kind -- every
      # visitor gets the same full graph editor. That is not a gap to be configured around: the
      # graph editor executes custom nodes, custom nodes are arbitrary Python, and the process runs
      # beside the weights and the output directory. Whoever can open it can run code on the node.
      authenticates = false;

      env = {
        # The image's entrypoint reads its whole command line out of this one variable. Two things
        # are being said: bind every interface (a fact about a container, not about a network), and
        # write renders into the `output` mount rather than into the working tree. A declaration
        # that overrides this variable and drops the second half is refused -- see the guard.
        CLI_ARGS = "--listen 0.0.0.0 --output-directory /images-out";
      };

      args = [ ];

      # FIFTEEN MINUTES OF TOLERATED START, and the number is the budget rather than the
      # expectation. A cold start loads a Python stack, initialises the GPU runtime, imports every
      # installed custom node, and -- where a deployment plants the hook described below -- installs
      # those nodes' Python requirements before the server answers anything. On top of that a
      # workload that shares one card can be waiting for another tenant to release it. Readiness is
      # what holds a waiting page up for exactly that long.
      #
      # THERE IS DELIBERATELY NO LIVENESS PROBE, and its absence is the decision. On a process this
      # slow to come up, a guessed liveness probe is how a working application ends up in a restart
      # loop that reads as the application's fault.
      readiness = {
        path = "/";
        periodSeconds = 5;
        failureThreshold = 180;
      };

      note = ''
        A node-graph front end for diffusion models: you wire samplers, conditioners, loaders and
        post-processing into a graph and execute it, one iteration at a time, looking at what came
        out and changing the graph. The operator sits in that loop continuously, which is why this
        is generative media rather than a job somebody queued -- and it needs weights, which is why
        it is a workload rather than a package.

        IT HOLDS THE WHOLE DEVICE WHILE IT RUNS. A second replica does not halve the queue; it is a
        second claim on one card, and on a cluster that hands the device out by count the second
        pod simply never schedules. Two live copies is never the shape of this workload, and its
        durable directories already say so: a rollout that overlaps the old pod and the new one is
        the new one waiting forever for a device the old one will not release until it is ready.

        AMD CARDS OFTEN NEED A GFX OVERRIDE, and it is not in this catalogue. ROCm ships compiled
        kernels for a short list of GFX targets and refuses a card that is architecturally
        compatible but absent from it; telling the runtime to report a supported target is what
        makes those cards work at all. WHICH target is a fact about a specific piece of silicon,
        so it arrives as environment from the declaration, and a wrong value fails at import time
        rather than quietly.

        THE HOOK POINT IS PART OF THE IMAGE, and worth knowing because the alternative is
        mysterious. This packaging sources `/root/user-scripts/pre-start.sh` on every start when it
        is present, which is the generic answer to a problem custom nodes create: a node cloned
        straight into `custom_nodes/` gets no dependency install, because installing dependencies
        is the in-app node manager's job and a git clone never asked it. That path is INSIDE the
        `home` directory above, which is why `hook` names that directory: the file has to land on a
        volume something backs, or it is gone at the next restart. This repository still plants no
        hook and never will -- what the script SAYS is content, and content is not vocabulary. It
        describes the point, and a deployment names the object that fills it.

        A ROCM TRAP THAT COSTS AN AFTERNOON: several widely-used custom nodes list `onnxruntime-gpu`
        unconditionally in their requirements, with a marker that checks the machine architecture
        and never the vendor. That package is CUDA-only. Installed on an AMD box it replaces a
        working `onnxruntime` and breaks every node that reaches face-analysis or ONNX inference,
        with an import error that names neither the culprit nor the node that pulled it in.

        IT IS SAFE TO SLEEP, and that is a property of the software rather than of its size.
        Nothing in it fires on a timer, nothing watches a directory, and a graph runs only when
        somebody submits one -- so at zero replicas there is no work that fails to happen, which is
        the actual test. WHETHER it sleeps is a deployment's call, and so is what wakes it; the one
        thing this repository will say about the wake path is that a request arriving while the pod
        is down has to be held until the pod holds the card, because a front that admits it earlier
        turns "the device is busy" into an error at the edge.

        AND IT AUTHENTICATES NOBODY. See `authenticates` above: this is the field that decides how
        far it may be exposed, and the module warns rather than refuses only because whether an
        authenticating front sits between it and the world is something a deployment can see and
        this repository cannot.
      '';
    };

    # ── The voice tier ────────────────────────────────────────────────────────────────────────
    #
    # Two applications rather than one, and they are split on the axis that decides everything
    # about how a cluster treats them: one burns the card and one does not. Everything else they
    # have in common -- an HTTP API, a model server, a few directories, no login -- and none of it
    # would tell a scheduler, an arbiter or a reader which of the two is the expensive one.

    kokoro = {
      # THE COMMUNITY FASTAPI PACKAGING of the model named in `serves`. Upstream publishes a Python
      # package and weights, not a server; this image is the assembly that puts an HTTP API in
      # front of them.
      #
      # THE PACKAGING PUBLISHES TWO IMAGES, one built against a vendor compute runtime and one not,
      # and this entry names the one that is not. That is not a default a deployment overrides: the
      # accelerated build is a workload that holds a device, which is a different entry with a
      # different `gpu`, and this repository does not have one. Swapping the reference alone would
      # give you a pod that burns a card nothing was told about.
      image = "ghcr.io/remsky/kokoro-fastapi-cpu";

      ports.http = 8880;
      primaryPort = "http";

      # IT DOES NOT TOUCH THE CARD, and that is the entire reason this half of the tier exists. An
      # 82M model is real-time on a CPU reservation, so narration costs cores rather than the one
      # resource every other tenant is queueing for -- and it stays available while the card is
      # busy, which is the property that actually matters on a single-device cluster.
      gpu = false;

      # ONE MODEL, and it is not content: this image was built around the model in `serves` and
      # serving a different one means running a different image. See `lib/voices.nix`.
      serves = [ "kokoro-82m" ];

      state = {
        # EXTRA voice packs, beside the released set that ships inside the image. The name is the
        # vocabulary a declaration has to match, and it says what the directory is FOR rather than
        # where upstream happens to keep it.
        voices = "/app/api/src/models/extra";
      };

      # NOTHING HAS TO ALREADY EXIST, and the contrast with the graph editor above is the point.
      # An empty extra-voices directory is a deployment with no extra voices: every released voice
      # is inside the image, so the workload starts, reports ready, and does exactly what it says
      # on the tin. `mustExist` names the directories where empty is the WHOLE PROBLEM, and this is
      # not one of them -- so the guard stays silent here rather than being spent on a caution.
      mustExist = { };

      # NOWHERE. Audio leaves as the response to the request that asked for it; nothing is written
      # for later, so there is no product directory to route work into and no argument to protect.
      outputState = null;

      # NO HOOK POINT. Nothing in this image reads a script off a path before starting, so there is
      # no place a deployment could plant one and nothing for a translator to install. `null` is the
      # fact rather than an empty shape.
      hook = null;

      # NOBODY. The API takes a key-shaped field for compatibility with a well-known interface and
      # enforces nothing behind it, so anything that can open the port can spend the CPU.
      authenticates = false;

      env = { };
      args = [ ];

      # THREE MINUTES, and it is a budget for loading a small model and its voice packs off disk
      # rather than for anything hard. Polled briskly, because a workload that is cheap to start is
      # a workload worth finding ready quickly.
      readiness = {
        path = "/health";
        periodSeconds = 3;
        failureThreshold = 60;
      };

      note = ''
        Narration. You hand it text and a voice from a fixed set, and it hands back audio -- no
        reference sample, no cloning, nothing about the request that identifies a person. That is a
        smaller act than the one below it, and the smaller act is the one that covers most of the
        work: a caption, a walkthrough, a draft read back to hear whether it scans.

        IT IS THE TIER'S ANSWER TO A BUSY CARD. Two applications that both needed the device would
        be one queue with two names on it; this one is genuinely elsewhere, so a voice is available
        while a render or a clone holds the card, and neither has to be scaled down for the other.

        IT IS SAFE TO SLEEP. Nothing fires on a timer and nothing watches a directory, so zero
        replicas loses no work -- but the case for sleeping is much weaker here than for a device
        tenant: what a sleeping CPU workload frees is a memory reservation, not the one resource
        anything is contending for, and the wake latency is paid by whoever asked.

        AND IT AUTHENTICATES NOBODY, which is the field that decides how far it may be exposed.
      '';
    };

    chatterbox = {
      # NO REFERENCE THIS REPOSITORY CAN STATE. Upstream ships a Dockerfile written against one
      # vendor's compute runtime, so a cluster whose card is anybody else's silicon runs an image
      # somebody built for it -- and where that image lives, who may pull it and what it was built
      # from are a deployment's facts, not this software's. `null` is the honest value and the
      # translator turns it into a refusal: a declaration must carry a whole reference.
      image = null;

      ports.http = 8004;
      primaryPort = "http";

      # IT BURNS THE CARD. Not because the model cannot run without one -- `lib/voices.nix` records
      # that a CPU path exists for it -- but because at this parameter scale the CPU path is slow
      # enough that nobody waits for it. The burn is a throughput decision made once, here, where a
      # scheduler and an arbiter can both see it; a model's own `needsGpu` and a workload's `gpu`
      # are different questions and this tier is where they come apart.
      gpu = true;

      serves = [ "chatterbox" ];

      state = {
        # The weights cache the serving stack fills on first start, by downloading them. Backing it
        # is what stops the download happening again on every restart of a workload that restarts
        # every time somebody wakes it.
        cache = "/app/hf_cache";

        # The reference samples a clone is made FROM -- seconds of somebody's recorded speech. It
        # is durable because a deployment curates it, and it is the most sensitive directory in
        # this repository's whole cluster plane: what is in it is a person's voice.
        reference = "/app/reference_audio";

        # The saved voices a clone produced, kept so the same voice can be used again without
        # re-deriving it from the reference audio.
        voices = "/app/voices";
      };

      # NOTHING HAS TO ALREADY EXIST, for a different reason than the CPU half above: these three
      # directories are all filled by the running process -- the cache by a download, the other two
      # by an operator working in the UI. An empty one is a cold start, which is slow and correct,
      # rather than a workload that comes up healthy and can do nothing.
      mustExist = { };

      # NOWHERE, same as the CPU half: generated audio is the response to the request. A deployment
      # that wanted generated files kept would be asking for a directory this catalogue does not
      # describe, and that is a change here rather than a value there.
      outputState = null;

      # NO HOOK POINT, same as the CPU half: the serving stack reads no start-up script off disk.
      hook = null;

      # NOBODY. No login, no user model, no token -- and on this application that is a sharper
      # problem than on the graph editor above, because what an open port buys is the ability to
      # make a recorded voice say anything.
      authenticates = false;

      env = { };
      args = [ ];

      # TEN MINUTES, and it is not one number's worth of caution: a cold start loads a Python and
      # compute stack, may be downloading weights into the cache above the first time, and on a
      # cluster that hands out one device it may be waiting for whoever currently holds it.
      #
      # THE PROBE PATH IS THE ROOT OF THE SERVER AND NOT A HEALTH ENDPOINT, which looks like
      # laziness and is a fact: the server has no health path, `/health` answers 404, and the root
      # answers 200 once the model is loaded. Verified against a running server rather than assumed
      # from the shape of other services -- a probe pointed at a 404 is a workload that never
      # becomes ready and reads as a broken application.
      #
      # THERE IS DELIBERATELY NO LIVENESS PROBE. Same reason as the graph editor: on a process this
      # slow to come up, a guessed liveness probe is a restart loop wearing the application's name.
      readiness = {
        path = "/";
        periodSeconds = 5;
        failureThreshold = 120;
      };

      note = ''
        Voice cloning. A few seconds of reference audio, then text, and the output is that voice
        saying something it never said. The operator is in the loop continuously -- a take is
        judged by listening to it and the reference, the text or the knobs change -- which is what
        makes this generative work rather than a job somebody queued.

        IT HOLDS THE WHOLE DEVICE WHILE IT RUNS, exactly like the graph editor: a second replica is
        a second claim on one card, and on a cluster that hands the device out by count the second
        pod never schedules. Its durable directories say the same thing from the other side.

        A CARD OFTEN NEEDS AN ARCHITECTURE OVERRIDE, and it is not in this catalogue. A compute
        runtime that ships kernels for a short list of targets refuses a card that is compatible
        but absent from the list, and telling it to report a supported target is what makes such a
        card work at all. WHICH target is a fact about one piece of silicon, so it arrives as
        environment from the declaration.

        IT IS SAFE TO SLEEP, and here the case is strong: a pod at zero replicas is a card another
        tenant can have. Nothing fires on a timer and nothing watches a directory, so sleeping
        loses no work; what it costs is the cold start above, paid by whoever wakes it.

        WHAT IS IN THE REFERENCE DIRECTORY IS A PERSON'S VOICE, and that is worth stating in the
        catalogue rather than leaving to a deployment to notice. Two consequences that are facts
        about this application rather than policy: it authenticates nobody, so exposure is the only
        control there is; and the model it serves watermarks its output by default, so a generated
        file remains identifiable as generated -- see `lib/voices.nix`.
      '';
    };
  };
}
