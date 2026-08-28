# nixcreative

**The tools you sit inside, declared — and the generative work that cannot be a package, declared
as a workload.**

Two things make this repo harder to bound than its siblings, and the whole README is about them.
The first is that "creative" borders three catalogues at once: watching, capturing, and making are
three different repos in this family, and the line between them is not the medium. The second is
that the heavy end of generative work runs on a shared GPU rather than on a desk — so this repo has
**two planes**, a package plane and a cluster plane, and the rule that decides which one a tool
lands on is gate 2 below. Left undefined, "generative content" swallows the cluster whole; defined,
it splits cleanly, and both halves are this repo's.

## "Experimental" is the right word for this repo

It is the honest description — generative things, image manipulation, vector work, tools picked up
to see what they do — and it survives being written down, as long as it is understood as a claim
about the *work* rather than about how new anything feels.

**Experimental means the result is not specified before the work starts.** That single property is
where this repo's design comes from, because it has two consequences:

1. **The work cannot be written down as a job.** If you could state the input, the parameters and
   the acceptance criteria up front, you would queue it, walk away, and look at the output
   afterwards — and that is a workload, not a desktop tool. Everything catalogued here is
   hand-driven out of necessity, not preference. That is gate 1 below.
2. **A tool earns its place by what it lets you try, not by a task it closes.** Every other
   catalogue in this family answers a standing need: nixmedia exists because media has to play,
   nixoffice because documents have to be read. Here, *"I want to see what this can do"* is a
   sufficient reason to add an entry.

Consequence 2 is the part that looks like a mood, so state the split plainly: **novelty is the
admission bar, not the boundary.** The bar decides whether an entry is worth adding at all. The
boundary decides whether it could be added *here*, and the boundary is the three gates below, none
of which asks how new anything is. A tool does not graduate out of this repo by becoming routine —
a vector editor used every week is not thereby somebody else's — and no amount of novelty gets a
tool in past a gate.

One real consequence follows from the bar, and it is worth writing down because it is the only
place "experimental" changes behaviour: **removal is cheap here and expensive everywhere else.** A
nixmedia entry is load-bearing — drop it and something stops playing. An entry here that stopped
being opened is just an experiment that ended. Delete it; there is no migration story to write.

## The placement rule

Three gates, applied in order. The first two are the family's and already in force elsewhere; only
the third is this repo's own. A tool that reaches the end belongs here.

### Gate 0 — is it terminal-shaped?

[nixsh][nixsh]'s rule, unchanged: *does the tool have a display mode at all, and is that its
default?* No → nixsh, whatever it operates on. This gate runs first, and it is why several
obviously image-shaped tools will never be catalogued here: `ffmpeg`, `chafa` and `timg` are
already nixsh's, and `imagemagick`, `oxipng` and friends would be nixsh's by the same test rather
than this repo's by subject matter. One package has one catalogue — both feed
`environment.systemPackages` on a NixOS host, so a second entry is a collision, not a redundancy.

### Gate 1 — would someone else, given the same input, produce a different file?

This is the seam with [nixmedia][nixmedia] and [nixrecord][nixrecord], and it needs stating
carefully because the obvious phrasings all misfile something:

- *"authors new content"* misfiles RAW development, which starts from a capture you did not author
  and is squarely this repo's.
- *"transforms existing content"* misfiles a transcoder, which transforms and is nixmedia's.
- *"interactive"* misfiles a live camera or microphone capture, which is interactive and is
  nixrecord's.

What actually separates the three is **whose decisions the output file records**:

| The output file is… | Its contents were decided by | Repo |
|---|---|---|
| something that already existed, played, tagged, or re-encoded | its original author, plus a preset | [nixmedia][nixmedia] — consumption and format-shift |
| a transcript of what happened in front of a camera or microphone | the events, not you | [nixrecord][nixrecord] — capture |
| **a record of judgements only you made** | **you, continuously, while the tool was open** | **here** |

Stated as one decidable question: **run the tool twice, on the same input, with two different
people at the keyboard — do you get two different files?** A preset-driven transcode gives the same
file to anyone. A microphone capture gives the same recording to anyone. A developed RAW, a vector
drawing and a paint-over do not, and that difference *is* the artifact.

This refines nixmedia's own test ("did the artifact already exist before the tool ran?") rather
than contradicting it: that question is about the *output*, and a developed RAW is not the same
image in a different container the way a transcode is the same programme in a different container.
The two rules agree on every case; this one just also answers the case where the input existed.

### Gate 2 — does the tool's working set include model weights?

Yes → the cluster, as a workload declared by **this repo's own cluster plane**
(`modules/cluster.nix`, scheduled against the card by [nixgpu][nixgpu]). Never a package here, no
matter how the weights were delivered. Gate 2 changes the PLANE, never the OWNER: generative media
is this repo's subject wherever it runs, and the reason the tool leaves the package catalogue is
that a package manager cannot finish installing a model — not that it stopped being creative. It
gets its own section below.

### Worked examples

Decidable rather than argued, including the cases that look like they go the other way:

| Tool | Gate 0 | Gate 1 | Gate 2 | Filed |
|---|---|---|---|---|
| a vector editor | display default | two people, two drawings | no weights | **here** |
| a raster editor, a painting app | display default | two people, two images | no weights | **here** |
| a RAW developer | display default | two people, two developments of one capture | no weights | **here** |
| a 3D suite | display default | two people, two scenes | no weights | **here** — but see *The card is shared* |
| a non-linear video editor | display default | two people, two cuts | no weights | [nixrecord][nixrecord] — see below |
| a GUI transcoder driven by presets | display default | **same file for anyone** | — | [nixmedia][nixmedia], which files it under format-shift |
| a perceptual duplicate finder | display default | **it finds; it decides nothing** | — | not here — it authors nothing. Already a [nixapps][nixapps] recipe. |
| a stylus note-taker | display default | your hand | no weights | **[nixoffice][nixoffice], already** — see below |
| an image-generation front-end | display default | your hand, genuinely | **needs weights** | **here, on the cluster plane** |
| a voice cloner | display default | your reference sample, your take | **needs weights** | **here, on the cluster plane** |
| a stock-voice speech synthesiser | display default | your text, your voice, your take — **the closest call in this table** | **needs weights** | **here, on the cluster plane** — see *The voice tier* |
| a desktop AI upscaler with bundled models | display default | your hand | **needs weights, even bundled** | the cluster plane — see below |
| `ffmpeg`, `chafa`, `timg`, an image-processing CLI | **no display default** | — | — | [nixsh][nixsh] |
| a colour-management or RAW-decoding library | it has no user at all | — | — | not a catalogue entry here; it is a dependency, or the preview pipeline's |

Three of those deserve saying out loud, because they are the ones a future reader will try to add.

**The stylus note-taker is already [nixoffice][nixoffice]'s**, in its `viewers` group, as the
markup half of reading a document. It passes all three gates here — freehand, your hand, no
weights — and it is still not this repo's, because it was placed first. A rule that admits a tool
is not a claim on a tool another catalogue already owns.

**The GUI transcoder is the hard case, and it is already settled elsewhere.** It fails gate 1 here,
and nixmedia's own format-shift rule claims it positively rather than leaving it homeless. Both
repos reach the same answer from opposite sides, which is the test that the two rules are actually
compatible rather than merely non-overlapping.

**The non-linear video editor passes every gate here and still isn't filed here.** Hand-driven, a
different cut for every editor, no weights — gate 1 alone would seat it in this catalogue. It sits
in [nixrecord][nixrecord]'s `edit` group instead, by ruling: video editing stays next to the
capture it cuts, in the repo that already owns the encoder. The counter-argument — that editing is
not encoder-bound, only export is — was raised and settled the other way. This is the same override
already at work for the stylus note-taker, just decided on structure rather than on precedence: a
gate that admits a tool is not a claim on a tool another catalogue already owns.

## Gate 2 in full: anything with weights is a workload, not a package

The heavy end of generative work — image and video model inference — runs on the cluster, which
owns the shared card. Gate 2 is not a capacity argument, and it is not "batch there, interactive
here". An image-generation front-end is driven by hand, iteration by iteration, exactly like the
editors in this catalogue; the operator really does sit in that loop, and by gate 1 alone it would
belong here. The overlap is real, and gate 2 resolves it without sending the tool anywhere else:
the tool stays this repo's and changes plane.

What gate 2 separates is the **deliverable**, and the line is sharp: *a package manager can finish
installing a raster editor. It cannot finish installing a model.*

A model-driven tool is not complete when the package manager exits. Its working set is gigabytes of
weights that have to live somewhere durable, be versioned, be shared between the several
applications that use the same checkpoint, and be scheduled against a card other tenants also want.
Those are all cluster properties, and a workstation package manager provides none of them.

Two concrete failures this prevents:

- **An undeclared second consumer of the card.** [nixgpu][nixgpu] arbitrates one physical GPU by
  priority, scaling the lowest-priority compute tenant to zero when VRAM runs out — the only way to
  free VRAM that is pinned and cannot be evicted. A model server installed by *this* catalogue onto
  the workstation would be a tenant the arbitration was never told about, holding pinned VRAM
  nothing can reclaim.
- **Weights inside a package manager's blast radius.** A checkpoint arriving as a package
  dependency is a private second copy of something the shared store already has, invisible to
  everything that manages the real one, and sweepable by an orphan-pruning reconciler that has no
  idea it is several GB of irreplaceable state.

**Bundled weights are still weights.** The tempting counter-example is the AI upscaler shipped as
one desktop package with its models inside: one package name, no service, a GUI you drive by hand.
It looks like it passes. It does not — the second copy and the unmanaged tenant are both still
there, just hidden inside a package. Gate 2 asks what the tool *needs*, not how it was delivered.

**Neither half is a consolation prize.** The package catalogue is the entire local half of a
generative session: the raster editor you take the output into, the vector tool you build the input
mask in, the RAW developer whose export becomes the reference. The generator reaches this host as a
URL rather than as a package — and the thing that serves that URL is declared by the cluster
catalogue below, in the same repo, on the other plane.

### The cluster plane

`lib/applications.nix` is the cluster catalogue and `modules/cluster.nix` is the translator that
turns a declaration into an app in the [nixk3s][nixk3s] grammar. Its common projection, collision
guards, volume identity rules and reports come from nixk3s' shared consumer factory; the local tail
is only the creative-specific hook, resource shape, reports and safety sentences. It renders no
Kubernetes object of its own: the grammar owns the Application, the Namespace, the Deployment and
the Service, and this repo supplies the one thing the grammar cannot know — what these applications
*are*.

Three applications are catalogued: a node-graph image generator, and the two halves of a voice tier
that are split on the one axis a cluster cares about — *The voice tier* below.

The same knowledge/value split as the package plane, enforced rather than trusted. The catalogue
holds what is true of the software wherever anyone runs it: the port, the directories it reads and
writes, whether it burns a graphics device, whether it authenticates anybody, how patient a probe
has to be. A declaration holds what is true of one cluster: what backs each directory, which
namespace, how far it is exposed, which version. Neither can supply the other's half, and the guards
say so — backing a directory the application does not use, leaving one it does use unbacked, putting
weights on a node path that gets created empty, or overriding the argument that routes renders into
the directory you backed are all eval errors rather than surprises at runtime.

**The card is a need, never an allocation.** The catalogue records that a workload puts work on a
graphics device. What the cluster calls that device, how many exist, who yields it and in what order
are four fleet facts, and not one of them is expressible here — the grammar underneath refuses to
render a device request until the site has named its own resource.

```nix
{
  imports = [ inputs.nixk3s.nixidyModules.apps inputs.nixcreative.nixidyModules.default ];

  nixcreative.clusterPlatform = { namespace = "…"; project = "…"; };

  nixcreative.applications.graphs = {
    app = "comfyui";
    version = "…";                                                   # or a whole `image`, never neither
    exposure = "nb";
    scaling = "scale-to-zero";
    wake = "sablier";
    state.models.hostPath = "…";                                     # weights, must already exist
    state.home = { hostPath = "…"; hostPathType = "DirectoryOrCreate"; };
    state.output.hostPath = "…";                                     # where renders land
    hook = { configMap = "…"; installerImage = "…"; };               # fills the image's start-up hook
  };

  nixcreative.applications.narration = {
    app = "kokoro";                                                  # stock voices, no device
    version = "…";
    state.voices = { hostPath = "…"; hostPathType = "DirectoryOrCreate"; };
  };

  nixcreative.applications.cloning = {
    app = "chatterbox";                                              # burns the card
    image = "…";                                                     # required: nobody publishes one
                                                                     # (and no `version`: nothing to hang one on)
    scaling = "scale-to-zero";
    wake = "sablier";
    state.cache = { hostPath = "…"; hostPathType = "DirectoryOrCreate"; };
    state.reference = { hostPath = "…"; hostPathType = "DirectoryOrCreate"; };
    state.voices = { hostPath = "…"; hostPathType = "DirectoryOrCreate"; };
    env.HSA_OVERRIDE_GFX_VERSION = "…";                              # one card's quirk
  };
}
```

### Two terms that look like they cross the line, and do not

Adopting an application that is *already running* is where a translator is most tempted to grow an
escape hatch.

The adoption itself is one plain term. `adopt = true` on a declaration renders that Application with
server-side apply and server-side diff, so the delivery layer compares against what the API server
actually holds rather than against a client-side reconstruction of it. It sits on the **declaration**
and not in the catalogue for the flattest of reasons: whether a Deployment of this application
already exists is that cluster's history, not a fact about the software — the same application
adopted on one cluster and created fresh on another differs here and nowhere else. It shrinks the
diff; it does not zero it, and for these workloads the difference is not a pod restart, because
durable directories force `Recreate`: the old pod stops before the new one starts, and one holding
the card then re-runs a cold start measured in minutes. Render it, diff it against what the cluster
is serving, and decide knowingly.

Two further terms exist for the pressure adoption puts on the *catalogue*, and both are split across
the line rather than handed through it.

**A hook point is the image's; what the hook says is not.** Some images source a script off a fixed
path before they start. That the path exists, which of the application's own directories it lives
in, and why a read-only projection mounted there aborts start-up instead of working, are three facts
about a packaging — they are in `lib/applications.nix`, as `hook`. Which object holds the script and
which small image copies it into place are one deployment's — they are `hook.configMap` and
`hook.installerImage` on the declaration. Neither half is a pod spec, and neither could be: the
catalogue has no object names and the declaration has no paths. What the translator builds out of
the two is a volume and an init container, with every string in it derived — the container's name,
the scratch mount path and the copy command are never spelled by anybody. An application whose image
reads no such path has `hook = null`, and supplying one to it is refused.

**A volume's manifest name is not a fact about the software.** The catalogue names directories for
what they *are*, and chooses those names so that a parent sorts before the directory nested inside
it — mounts are emitted in attribute-name order, and a shallower mount emitted last covers the
deeper one it contains. A live object, though, already carries whatever names it was born with, and
renaming a volume on a running workload rewrites the pod template for the sake of a word. So
`state.<name>.volumeName` renames a volume **in the manifest and nowhere else**: where the directory
lands inside the container stays the catalogue's, which is what stops this becoming a second
vocabulary for the same directories. A rename that inverts a nested pair warns rather than passing
quietly, because the constraint the catalogue's own names encode is still true after the rename.

### The voice tier

Two of the three catalogued applications are speech synthesis, and they are **two entries rather
than one** because they differ on the axis that decides everything a cluster does with them: one
burns the card and one does not.

| | Stock voices | Voice cloning |
|---|---|---|
| What it does | you pick a voice from a released set and it reads your text | you give it seconds of reference audio and it speaks in that voice |
| Device | **none** — a small model, real-time on a CPU reservation | **holds the card**, exactly like the graph editor |
| Image | a community server image, named in the catalogue | **none anybody publishes** — see below |
| Durable directories | extra voice packs | a weights cache, the reference audio, the saved voices |
| Available while the card is busy | yes | no; it *is* the card being busy |

Everything else about them is alike — an HTTP API, a model server, a few directories, no login —
and none of that would tell a scheduler which of the two is the expensive one. Catalogued as one
entry, the cheap half would inherit a device it never uses, and the arbitration that decides who
yields the card would be told about a tenant that was never going to hold it.

Two things this tier taught the translator, both of which apply to anything catalogued later:

**A catalogue entry may have no image.** Where somebody publishes a runnable container, naming its
repository is knowledge and a declaration names the version. Where nobody does — where upstream
ships a build recipe written against one vendor's compute runtime and every operator builds their
own — there is no reference this repository could state. `image` is `null`, and a declaration
without a whole reference is refused rather than rendered with a version hanging off nothing.

That is also why `version` is **not** a required option, and is defaulted nowhere either. A
workload pinned by digest has nothing for a tag to hang on, and one whose catalogue entry publishes
no repository could never use a tag at all — demanding a version there would be demanding a value
nobody can supply honestly, which is how `version = "unused"` gets written into a real declaration.
Saying *neither* a version nor a whole reference is the actual mistake, and that is the guard.

**`mustExist` is for directories where empty is the whole problem, and it stays silent otherwise.**
The graph editor's weights directory must already exist: auto-created and empty, it is a workload
that starts, reports ready, and can execute nothing. The voice tier's directories are all filled by
the running process — a cache by a download, voices and reference clips by an operator — so an
empty one is a cold start, which is slow and correct. A guard spent on a caution is a guard nobody
reads.

### Why a voice server passes gate 1, and where it nearly doesn't

This is the closest call in the catalogue and it deserves the argument rather than an assertion.
Gate 1 asks whether two people at the keyboard, given the same input, produce two different files —
and a speech synthesiser handed the same text looks uncomfortably like the preset-driven transcoder
the gate exists to exclude.

It is not one, for two reasons that hold in both halves of the tier:

- **Nothing existed before the tool ran.** [nixmedia][nixmedia]'s own test — did the artifact
  already exist? — answers cleanly here: a transcode is the same programme in a different
  container, and an audio file of a voice reading your text is not a container change of anything.
  There was no recording. The tool made one.
- **The file records choices, not a specification.** Which voice out of dozens, which phrasing, how
  the text was rewritten so it would scan when spoken, which take was kept. A preset gives anyone
  the same file; a voice and a take do not. For the cloning half it is not even close — the
  reference sample is a judgement in itself.

Where it genuinely stops being this repo's is worth stating, because it is decidable: **fix the
voice, feed a queue of documents from a script, and walk away.** Now the result is specified before
the work starts, nobody is in the loop, and by this repo's own first gate that is a job somebody
queued rather than a tool somebody sat inside. Same software, different act. This catalogue
describes the interactive one.

## The voice-model catalogue

`lib/voices.nix` says **which speech model** an application serves, and the facts that decide
whether you can serve it. `lib/applications.nix` says what the software is; this says what it was
built around.

That second catalogue exists for the voice tier and not for the graph editor, and the line is not
arbitrary. A node graph runs whatever checkpoints a deployment installed into it: the model set is
**content**, it changes on a Tuesday afternoon, and a catalogue of it would be one deployment's
library pretending to be knowledge. Each voice application **is one model's server** — the model is
what the image was built around, and swapping it means swapping the workload. So `serves` is empty
for one and names a model for the others, which is the shape of the split rather than a gap.

Twelve models are catalogued, which is deliberately more than anything runs. The question the table
answers is never "what is deployed" — a declaration answers that — but **"what would we move to,
and what does moving cost"**. Five facts decide that and they are the only five recorded:

| Field | Why it decides something |
|---|---|
| `parameters` | the scale, which is what a device requirement and a cold start both follow from |
| `needsGpu` | whether serving it costs the one resource everything else is queueing for |
| `voiceCloning` | whether it can be made to sound like a particular person at all |
| `licence` + `commercialUse` | whether you may use the output, which no amount of quality overrides |
| `hfRepo` | where the weights come from — **never** where they land |

**Nothing here downloads anything, and no path to a weight file appears in this repository.** A
repository id says where weights come *from*; where the file lives on a machine is a value, backed
through a `state` directory like every other one. `checks/voices-eval.nix` refuses an absolute path
anywhere in that file so the rule cannot erode.

**The evidence rule is the point of the file.** Every fact was read off a primary source and every
entry carries the URLs. Where a source does not establish a fact the field is `null` **and** the
entry names it in `unverified` with what would have to be fetched — enforced in both directions, so
a fact cannot be dropped quietly and a "we never checked this" note cannot outlive the checking.
Candidates that could not be established are not in the catalogue at all; they are open questions in
[`experiments/open-questions.md`](experiments/open-questions.md), because a wrong repository id is
more expensive than a missing one.

**A licence that does not clearly permit commercial use is recorded as such, loudly.**
`commercialUse` is a judgement — `yes`, `no`, `conditional` — and anything other than `yes` must
carry a `caveat` saying what the restriction is. Several catalogued models are non-commercial or
carry binding use restrictions, and two of them pair an *open-source licence on the code* with a
*non-commercial licence on the weights*, which is the shape a careful reader still gets wrong. One
of those carries no licence tag on its repository at all, so anything keying on the tag records it
as unlicensed and moves on. `nixcreative.voiceLicenceReview` publishes that list from the
catalogue, before any workload exists, and the module additionally warns when a *declared* workload
serves such weights — a warning rather than a refusal, because non-commercial use is exactly what
such a licence is for and whether a given deployment is commercial is not something this repository
can see.

[`studies/voice-model-survey.md`](studies/voice-model-survey.md) records what surveying those models
changed, including the one field the survey caused to be **removed**.

## Where this lives, and the card it shares

Unlike nixsh — where every host has a shell, so the catalogue has no per-host story — this repo has
essentially one host class: **the workstation container**, co-resident with the cluster on the
machine that holds the discrete GPU. Every group defaults to the empty list, and a laptop or a
headless box selecting nothing from this catalogue is the expected answer, not a gap. Selection
stays per-host regardless: a laptop that wants the vector editor selects the vector editor, and
that is not a contradiction of where the repo mostly lives.

Two consequences of that placement, both facts about the silicon rather than anything this repo can
declare away.

**The card is shared, and gate 2 does not make the local tools free of it.** Gate 2 keeps model
servers out; it does not stop a GPU renderer or a GPU-accelerated filter from taking VRAM on the
card the cluster is also using. Under nixgpu's priority model the interactive desktop is the
top-priority tenant — its graphics VRAM spills to GTT under pressure and the watcher sheds k8s
tenants lowest-first — so a large local render does not queue behind cluster work: it evicts it.
That is the arbitration working as designed, not a bug, but starting one is a scheduling decision
about the whole machine.

**Video encode is the exception, and AV1 is the exception to the exception.** The media engine is
separate silicon with its own scheduling lane, never evicted for compute VRAM pressure — so a
hardware-encoded render export from Blender does not contend with cluster tenants at all (there is
no other source of encoded video here: video editing is nixrecord's, by ruling, above). AV1 does
not get that lane, because this GPU does not have it: the workstation's card is an RDNA2 part whose
`VAProfileAV1Profile0` exposes `VAEntrypointVLD` and nothing else — AV1 **decode only**, verified
with `vainfo` on the live host rather than inferred from a model number. The one host class here
that has a hardware AV1 encoder (`VAEntrypointEncSlice`) is the laptop, which is exactly where this
repo mostly does not live. So an AV1 render export from Blender is a CPU encode: slow, correct,
never broken, and never accelerated. Nothing in this catalogue is wrong because of that — it just
will not find the encoder it advertises. Capture policy is H.264 for the same reason, one repo
over: [nixrecord][nixrecord] captures in a codec every host can encode, and treats AV1 as a
delivery step done elsewhere with hardware, never at capture time.

## What this repo does not own

- **Terminal-shaped tools**, however image- or video-shaped they also are. Gate 0 sent them to
  nixsh and this catalogue does not take them back.
- **Video editing.** [nixrecord][nixrecord] owns it — kdenlive and Shotcut are catalogued in its
  `edit` group, not here. A DAW is a different act from cutting an existing recording: gate 1's
  continuous-judgement test is exactly why `qtractor` stays here while the video editors moved.
- **Application configuration.** This is installation intent — which package, resolved per platform
  — and nothing about how the app is set up. That is a different call from the one
  [nixrecord][nixrecord] made for its encoder profiles, and deliberately so: an encoder profile is
  a *specification* that produces a reproducible artifact. A creative application's configuration
  is brushes, palettes, workspace layout and window state — the residue of using it, an output of
  the work rather than an input to a machine build. Declaring it would fight the tool every time a
  brush changed.
- **Model weights themselves.** The shared store — where checkpoints live, how they are versioned,
  who else reads them — is the cluster's, not this repo's; the cluster catalogue names the directory
  a workload mounts them at and never what is in it. The *workload* that needs them is this repo's,
  on the cluster plane. Gate 2 moves the plane, not the owner. `lib/voices.nix` is not an exception:
  it names *which model* a workload serves and the repository the weights come from, and never a
  path, a copy or a download.
- **The GPU itself** — driver stack, arbitration, VRAM policy, VA-API drivers. [nixgpu][nixgpu]
  owns all of it, keyed to silicon rather than to a host class.
- **Audio routing.** A patchbay or graph controller is the audio fabric's, not a creative tool;
  [nixaudio][nixaudio] owns the daemons and the graph.
- **Fonts.** A whole-workstation concern, and [nixfont][nixfont]'s.

## The catalogue

`lib/creative.nix` is the package plane's data table; `modules/nixcreative.nix` turns a selection into
resolved package lists. Each entry maps a name to a pacman package (`arch`), a nixpkgs attribute
path (`nixpkgs`), and an `aur` flag (default `false`). `aur` is load-bearing: `pacman -S` fails the
**whole transaction** on an AUR name with "target not found", taking every unrelated package in the
same converge down with it, so AUR names are published on a separate list.

**Groups are ergonomics, not the boundary.** They are named by what you sit in front of, which is
convenient for selecting; nothing in the placement rule above mentions medium, and a group name is
never an argument for admitting an entry.

### What's declared

Four entries, one per group — the operator's ratified target state, not a partial catalogue still
filling in. Every `arch` name was verified with `pacman -Si` against a live host, and every
`nixpkgs` attribute by a **forcing** evaluation (`.name`, not an existence check — a renamed
attribute becomes a throwing alias that `?` happily accepts) against a real nixpkgs checkout.

| Group | Entry | `arch` | `nixpkgs` | Why |
|---|---|---|---|---|
| `vector` | Inkscape | `inkscape` | `inkscape` | SVG illustration and vector asset creation — also the input side of a generative loop (masks, guides, plates), not an afterthought to raster. |
| `raster` | Krita | `krita` | `krita` | Brush engines, animation and painting: the tool a generated image, or anything else, is taken *into* for hand-driven raster work. |
| `3d` | Blender | `blender` | `blender` | 3D authoring and node compositing — explicitly not video editing. Read *The card is shared* first: this is the one entry whose GPU renderer sheds cluster tenants under nixgpu's priority model. |
| `daw` | qtractor | `qtractor` | `qtractor` | A light, comprehensible multitrack recorder, picked on size over Ardour (105 MiB, ~75 dependencies) and Reaper (127 MiB, proprietary): qtractor is 8.7 MiB and quick to learn. Its session format is plain XML, so a project can be authored outside the app entirely and opened straight into it. |

### Deliberately not proposed

So the same names do not come back:

- **A duplicate finder, a stylus note-taker, a RAW-decoding library** — the three creative-looking
  packages sitting installed-but-undeclared elsewhere in this family, and none of them is this
  repo's. The duplicate finder authors nothing (gate 1) and already exists as a [nixapps][nixapps]
  recipe; the note-taker is [nixoffice][nixoffice]'s, placed first; the decoding library is the
  file-manager preview pipeline's, and [nixmedia][nixmedia] has already filed it there.
- **`ffmpeg`, `chafa`, `timg`** — [nixsh][nixsh]'s, already declared. A second entry here would be
  a collision with that catalogue, not a redundancy — gate 0 sends all three there regardless of
  how image- or video-shaped they look.
- **`imagemagick`, `graphicsmagick`, `oxipng`, `jpegoptim`, `potrace`** — all real, all image
  tools, all with no display mode by default. Gate 0 sends them to nixsh; whether nixsh wants them
  is nixsh's call and not something this repo may pre-empt.
- **A GUI transcoder, a tag editor, an internet-radio player** — nixmedia's, by its own
  format-shift and consumption rules.
- **An AI upscaler** — gate 2, regardless of how it is packaged.
- **Audacity, Ardour, LMMS, Reaper** — the DAW candidates. Audacity was declined outright and was
  never really a DAW candidate to begin with. Ardour, LMMS and Reaper were considered for the `daw`
  group and declined on size and complexity; qtractor won (see the table above). `qjackctl` is a
  different matter entirely — it is graph routing, which is [nixaudio][nixaudio]'s.
- **Kdenlive, Shotcut, Flowblade** — video editing is [nixrecord][nixrecord]'s by ruling: kdenlive
  and Shotcut are catalogued in its `edit` group, next to the capture they cut, not here. There is
  no `video` group in this repo, so which non-linear editor to pick doesn't arise.
- **Scribus, FontForge, a colour picker** — page layout, font authoring and a desktop accessory.
  Each passes gate 1, and each is closer to another catalogue's subject ([nixoffice][nixoffice],
  [nixfont][nixfont], [nixdesktop][nixdesktop]) than to this one. Named here so the *reason* is on
  record rather than rediscovered.
- **GIMP and darktable** — proposed by an earlier draft, for general raster editing and
  non-destructive RAW development respectively. Neither was approved: darktable was ruled
  explicitly "uncalled for and unwanted right now," and GIMP was never approved as the raster
  entry — Krita is. No RAW workflow is declared, so a RAW-developer alternative (a second
  developer, a photo manager, a panorama stitcher) isn't proposed either; there is nothing yet for
  it to be an alternative to.

## Status

**The code matches the rule above, on both planes.** On the package plane `lib/creative.nix`
carries exactly the four entries in *What's declared*, one per group (`daw`, `vector`, `raster`,
`3d`); `modules/nixcreative.nix` resolves a selection into `archPackages` / `aurPackages` /
`nixosPackages` / `unavailableOnNixos`, and the two backends (`modules/nixos.nix`,
`modules/arch.nix`) plus the home-manager backend (`home/nixcreative.nix`) install from those lists.
On the cluster plane `lib/applications.nix` carries three entries — the node-graph image generator
and the voice tier's two halves — `lib/voices.nix` carries the twelve speech models they are chosen
from, and `modules/cluster.nix` translates a declaration into an app in the [nixk3s][nixk3s]
grammar.

`nix flake check` is green. `checks/catalogue-eval.nix` covers the package plane's namespaced
selection and eval-time rejection for all four groups, on every supported system.
`checks/voices-eval.nix` holds the voice catalogue to its own evidence rule — sources, the
both-directions `unverified` rule, the mandatory caveat on a restrictive licence, no absolute paths
— and checks the seam between the two `lib/` catalogues: every model an application serves exists,
and an application serving a model that requires a device says it burns one. It is pure data, so it
runs on every supported system too.

`checks/cluster-eval.nix` renders the example surface through the real grammar and makes every
guard fire on a declaration that must be refused; `checks/cluster-render.nix` reads the promises
back off the rendered YAML rather than off the options that produced it — including the tier's
defining asymmetry, read as the *absence* of a device request and a device label on the half that
does not burn the card. Those two are declared for `x86_64-linux` only, on purpose: each BUILDS a
nixidy environment, and a platform that cannot be built is a check `nix flake check` skips while
exiting 0.

`experiments/` and `studies/` are real and are two different things. `experiments/` holds what
`nix flake check` structurally cannot: `verify-packages.sh` resolves every catalogued package name
against a real pacman database and a real nixpkgs revision, and `verify-voices.sh` re-checks every
catalogued model against the hub — canonical id, licence tag, agreement gate, what an anonymous
fetch actually gets, and whether the upstream is still moving. Both read the catalogue through Nix
rather than parsing it, both exit non-zero on a disagreement, and neither counts a skip as a pass.
`experiments/open-questions.md` holds the candidates that could not be established and exactly what
would settle each. `studies/` holds what running them taught — the findings that shaped a field, a
guard, or a decision not to have one.

## Usage

On the package plane, the same shape as every catalogue in this family: a platform-neutral policy
module plus two backends, selecting nothing by default. (The cluster plane's usage is in *The
cluster plane* above.)

```nix
{
  imports = [ inputs.nixcreative.nixosModules.default ]; # or .systemManagerModules.default on Arch

  nixcreative = {
    daw    = [ "qtractor" ];
    vector = [ "inkscape" ];
    raster = [ "krita" ];
    "3d"   = [ "blender" ];
  };
}
```

On Arch the module installs nothing itself — wire the resolved lists into the host's own
reconciler:

```nix
{
  imports = [ inputs.nixcreative.systemManagerModules.default ];
  nixarch.packages.pacman = config.nixcreative.archPackages;
  nixarch.packages.aur    = config.nixcreative.aurPackages;
}
```

## Repository layout

| Path | Purpose |
|---|---|
| `flake.nix` | Flake entry point: `nixosModules.default` (NixOS install), `systemManagerModules.default` (Arch publish), `nixidyModules.default` (the cluster plane), `lib.catalogue`, `lib.applications`, `lib.voices`, and `checks`. `nixidy` is checks-only; the cluster export closes over nixk3s' consumer factory, while a host importing only the package modules pulls in neither. |
| `lib/creative.nix` | The package catalogue — one entry per selected tool, platform-specific package names, and comments recording why each was chosen over the alternatives it was chosen against. |
| `lib/applications.nix` | The cluster catalogue — what each cluster-side application IS: its port, the directories it reads and writes, whether it burns a graphics device, whether it authenticates anybody, how patient its probe has to be, and which model it serves. No address, no node, no namespace, no device name. |
| `lib/voices.nix` | The voice-model catalogue — which speech model a workload serves, at what scale, needing a device or not, able to clone a voice or not, under which licence and whether that licence permits commercial use, and which repository the weights come from. Every entry carries the sources it was read from; nothing here is a path. |
| `modules/cluster.nix` | The bounded nixcreative adapter over nixk3s' shared catalogue-consumer factory. Renders no Kubernetes object of its own; its local hook, reports and guards cover only the half a declaration must supply and the catalogue cannot. |
| `examples/all/values.nix` | Placeholder values the cluster checks render from. Nothing in it is real. |
| `modules/nixcreative.nix` | Policy: selection groups and the resolved `archPackages` / `aurPackages` / `nixosPackages` / `unavailableOnNixos` lists. |
| `modules/nixos.nix`, `modules/arch.nix` | The two backends. The NixOS one force-evaluates every nixpkgs attribute before trusting it (`tryEval`, never a bare existence check — a renamed attribute in nixpkgs becomes a *throwing* alias, which `?` accepts). |
| `checks/` | `nix flake check`-wired proof for both planes: `catalogue-eval.nix` for selection and resolution (module evaluation, not a package build), `voices-eval.nix` for the voice catalogue's evidence rule and the seam between the two `lib/` catalogues, `cluster-eval.nix` for what the cluster module resolves and refuses, `cluster-render.nix` for what actually comes out as YAML. |
| `experiments/` | What a check structurally cannot do: resolve a catalogued name against the world. `verify-packages.sh` against a real pacman database and a real nixpkgs revision; `verify-voices.sh` against the model hub. Plus `open-questions.md` — what could not be established, and what would settle it. |
| `studies/` | Findings from those experiments that changed a field, a guard, or a decision not to have one. |

## Platform support

**NixOS:** full. Selections resolve to nixpkgs attributes and install via
`environment.systemPackages`, skipping a stale mapping with a warning rather than failing the whole
evaluation.

**Arch / CachyOS (via system-manager):** publishes `nixcreative.archPackages` and
`nixcreative.aurPackages` for the host's reconciler. Cannot install packages itself.

## Related projects

Part of the same independently-usable NixOS module family. Gate 1 draws its boundary against
[nixmedia][nixmedia] (graphical media *consumption* and format-shift) and [nixrecord][nixrecord]
(capture of the real world — light and sound, plus video editing by ruling; never a digital
interface, which is owned by whichever repo owns that interface); gate 0 sends everything
terminal-shaped to [nixsh][nixsh], including several tools that look like they belong here. Gate 2
does not point at another repo at all — it points at this one's other plane, which is declared
against the [nixk3s][nixk3s] app grammar and scheduled against the card by [nixgpu][nixgpu] (which
arbitrates the one card all of this shares). [nixoffice][nixoffice], [nixaudio][nixaudio], [nixfont][nixfont] and
[nixdesktop][nixdesktop] own the neighbouring subjects named above, and [nixarch][nixarch] is the
Arch host reconciler the `systemManagerModules` backend publishes into.

[nixmedia]: https://github.com/julian-corbet/nixmedia-corbet-ch
[nixrecord]: https://github.com/julian-corbet/nixrecord-corbet-ch
[nixsh]: https://github.com/julian-corbet/nixsh-corbet-ch
[nixapps]: https://github.com/julian-corbet/nixapps-corbet-ch
[nixgpu]: https://github.com/julian-corbet/nixgpu-corbet-ch
[nixk3s]: https://github.com/julian-corbet/nixk3s-corbet-ch
[nixoffice]: https://github.com/julian-corbet/nixoffice-corbet-ch
[nixaudio]: https://github.com/julian-corbet/nixaudio-corbet-ch
[nixfont]: https://github.com/julian-corbet/nixfont-corbet-ch
[nixdesktop]: https://github.com/julian-corbet/nixdesktop-corbet-ch
[nixarch]: https://github.com/julian-corbet/nixarch-corbet-ch

## License

MIT.
