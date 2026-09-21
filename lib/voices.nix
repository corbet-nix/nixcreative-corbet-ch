# SPDX-License-Identifier: MIT OR Apache-2.0
#
# The voice-model catalogue: WHICH speech model a cluster workload serves, and the handful of facts
# that decide whether you can run it.
#
# WHY A SECOND CATALOGUE, and why it is voice-shaped rather than model-shaped in general. The
# applications catalogue next door says what a piece of SOFTWARE is. For most of what runs on the
# card that is the whole story: a node-graph editor is a graph editor whatever checkpoints a
# deployment installs into it, and a catalogue of those checkpoints would be a catalogue of
# CONTENT -- one deployment's library, changing weekly, and no more this repository's than a brush
# preset is. The voice tier is the case where that split does not hold. Each of these applications
# IS one model's server: the model is not content you load into it, it is the thing the image was
# built around, so "which model does this serve" is knowledge about the software and belongs beside
# it. Swapping the model means swapping the workload.
#
# WHAT THIS FILE IS FOR, concretely: making a swap DECIDABLE. The catalogue is deliberately wider
# than what any deployment runs, because the question it answers is never "what is deployed" -- the
# declaration answers that -- but "what would we move to, and what does moving cost". Five facts
# decide that, and they are the only five here: how big the model is, whether it needs a graphics
# device, whether it can clone a voice from a reference sample, what its licence is and whether
# that licence permits commercial use, and where the weights come from.
#
# NOTHING HERE DOWNLOADS ANYTHING, and no path to a weight file appears in this repository. A
# repository id says where weights come FROM; where the file lands on a given machine is a
# deployment's fact, backed through the application's `state` directories like every other one.
# `checks/voices-eval.nix` refuses an absolute path anywhere in this file for exactly that reason.
#
# ── THE EVIDENCE RULE, AND IT IS THE POINT OF THE FILE ─────────────────────────────────────────
#
# Every fact below was read off a primary source -- a model card, a licence text, or a repository
# API -- and every entry carries the URLs it was read from. Where a source does not establish a
# fact, the field is `null` AND the entry names it in `unverified` with what would have to be
# fetched to fill it in. The check enforces that in BOTH directions: a null that is not named is an
# error, and naming a field that is not null is an error too. There is no way to leave a fact out
# quietly, and no way to guess one.
#
# A LICENCE THAT DOES NOT CLEARLY PERMIT COMMERCIAL USE IS THE EXPENSIVE MISTAKE, so it is the one
# fact that cannot be recorded silently: `commercialUse` is a JUDGEMENT and not a boolean -- `yes`,
# `no`, or `conditional` for a licence that permits commercial use while binding what you may do
# with it -- and anything other than `yes` must carry a `caveat` saying what the restriction is.
# Two of the models below have permissive CODE and non-commercial WEIGHTS, which is precisely the
# shape that a reader -- or a scraper keying on a repository's licence tag -- gets wrong.
#
# `gated` IS ABOUT TERMS, NOT ABOUT ENFORCEMENT. It records that the weights are published behind
# an agreement the publisher wrote and expects you to accept, which is a property of the release.
# Whether the hub is mechanically blocking anonymous downloads today is a separate and movable
# thing, and the two disagree in practice -- `experiments/verify-voices.sh` reports both and
# compares only the first, and `studies/` records the run where they came apart.
#
# THE FACTS ROT AT DIFFERENT SPEEDS. A parameter count and a licence are properties of a released
# artifact and do not move. Download counts, star counts and "last pushed" dates are observations,
# and they are kept OUT of this file: where staleness is itself the decision (an upstream that
# stopped moving years ago) the note says so with the date attached, and the underlying numbers
# live in `studies/` where they are dated rather than pretended to be permanent.
{ ... }:
{
  voices = {
    # ── Small enough to run without a card ──────────────────────────────────────────────────────

    # https://huggingface.co/hexgrad/Kokoro-82M/raw/main/README.md
    # https://huggingface.co/api/models/hexgrad/Kokoro-82M
    # https://api.github.com/repos/hexgrad/kokoro
    kokoro-82m = {
      name = "Kokoro";
      hfRepo = "hexgrad/Kokoro-82M";
      upstream = "https://github.com/hexgrad/kokoro";

      # "82 million parameters", model card.
      parameters = "82M";

      # The card cites A100 hours for TRAINING and states no inference device requirement; the
      # published serving path is the `kokoro` pip package plus the `misaki` G2P library, both of
      # which run on a CPU. That is the fact that makes this the tier's cheap half.
      needsGpu = false;

      # Stock voices only. There is no reference-audio path: a voice is a released voice pack, and
      # a voice that is not in the pack is not a voice this model has.
      voiceCloning = false;

      licence = {
        name = "Apache-2.0";
        spdx = "Apache-2.0";
        commercialUse = "yes";
        # Unusually, the card says so in words rather than leaving it to the tag: "This is an
        # Apache-licensed model, and Kokoro has been deployed in numerous projects and commercial
        # APIs. We welcome the deployment of the model in real use cases."
        caveat = null;
      };

      gated = false;
      unverified = { };

      sources = [
        "https://huggingface.co/hexgrad/Kokoro-82M/raw/main/README.md"
        "https://huggingface.co/api/models/hexgrad/Kokoro-82M"
        "https://api.github.com/repos/hexgrad/kokoro"
      ];

      note = ''
        The reason a voice tier can have a half that never touches the card. Everything else in
        this catalogue trades a device, a licence or both for the ability to sound like a
        particular person; this one cannot do that at all, and in exchange it costs a CPU
        reservation and starts in seconds.
      '';
    };

    # https://huggingface.co/Supertone/supertonic-3/raw/main/README.md
    # https://huggingface.co/api/models/Supertone/supertonic-3
    # https://api.github.com/repos/supertone-inc/supertonic
    supertonic-3 = {
      name = "Supertonic 3";
      hfRepo = "Supertone/supertonic-3";
      upstream = "https://github.com/supertone-inc/supertonic";

      # "about 99M parameters across the public ONNX assets" -- a count over what is published
      # rather than a figure the card states for a single checkpoint, and carried in those words.
      parameters = "~99M across the public ONNX assets";

      # The card states it outright: "It does not require a GPU". Its own benchmarks put a CPU run
      # against A100 baselines, which is the claim being made rather than an aside.
      needsGpu = false;

      # FALSE FOR THE OPEN WEIGHTS, and the distinction is the whole reason this field is not a
      # summary of the product. The card says the open-weight package "includes fixed preset voice
      # styles for immediate local inference" and then points anyone wanting "zero-shot custom voice
      # styles" at the vendor's hosted studio. So the capability exists in the product and does not
      # ship in what you can run here. A reader who takes `false` as "this family cannot clone"
      # would be wrong; a reader who takes it as "you cannot clone with these weights" is right, and
      # that is what every field in this catalogue means.
      voiceCloning = false;

      licence = {
        # The model and the sample code are under different instruments, which is the first of the
        # two-licence stacks in this catalogue.
        name = "OpenRAIL-M (model); MIT (sample code)";
        spdx = null;
        commercialUse = "conditional";
        caveat = ''
          OpenRAIL-M is commercially permissive in principle and is NOT equivalent to MIT or
          Apache-2.0: it carries binding use-based behavioural restrictions that travel with the
          weights and bind downstream users. Read the licence body before treating this as free.
        '';
      };

      gated = false;
      unverified = { };

      sources = [
        "https://huggingface.co/Supertone/supertonic-3/raw/main/README.md"
        "https://huggingface.co/api/models/Supertone/supertonic-3"
        "https://api.github.com/repos/supertone-inc/supertonic"
      ];

      note = ''
        Ships as ONNX assets rather than as a Python framework, so the serving path is an ONNX
        runtime and not a torch stack -- which is a container an order of magnitude smaller than
        anything else here, and a different kind of dependency to keep working.
      '';
    };

    # ── Cloning, small enough to stay off the card ──────────────────────────────────────────────

    # https://huggingface.co/ResembleAI/chatterbox/raw/main/README.md
    # https://huggingface.co/api/models/ResembleAI/chatterbox
    chatterbox = {
      name = "Chatterbox";
      hfRepo = "ResembleAI/chatterbox";
      upstream = "https://github.com/resemble-ai/chatterbox";

      parameters = "500M";

      # CUDA, MPS and CPU are all supported paths -- `device="cpu"` is documented -- so a device is
      # not a REQUIREMENT of this model. It is a requirement of running it at a useful speed: the
      # 500M tier is far slower on a CPU than the 110M sibling below, whose card is where the
      # 3x-realtime CPU figure comes from. A workload that burns the card to serve this is making
      # a throughput choice, not satisfying a hard need, and the applications catalogue records
      # the burn separately for exactly that reason.
      needsGpu = false;

      # A reference sample of a few seconds is all it takes, which is the whole reason this half of
      # the tier exists and the whole reason its output is watermarked.
      voiceCloning = true;

      licence = {
        name = "MIT";
        spdx = "MIT";
        commercialUse = "yes";
        caveat = ''
          MIT, with a property that is not a licence term and matters anyway: every generated file
          is stamped with Resemble's Perth neural watermark by default. Nothing forbids commercial
          use; the output is identifiable as this model's.
        '';
      };

      gated = false;
      unverified = { };

      sources = [
        "https://huggingface.co/ResembleAI/chatterbox/raw/main/README.md"
        "https://huggingface.co/ResembleAI/chatterbox-nano/raw/main/README.md"
        "https://huggingface.co/api/models/ResembleAI/chatterbox"
      ];

      note = ''
        The English original. A multilingual sibling at the same parameter scale is described on
        the same model card, and its weights repository id is NOT catalogued here: probing the two
        plausible ids returned 401 rather than a model, so the id is unestablished and an invented
        one would be worse than an absent one. `experiments/` carries it as an open question.
      '';
    };

    # https://huggingface.co/ResembleAI/chatterbox-nano/raw/main/README.md
    # https://huggingface.co/api/models/ResembleAI/chatterbox-nano
    chatterbox-nano = {
      name = "Chatterbox Nano";
      hfRepo = "ResembleAI/chatterbox-nano";
      upstream = "https://github.com/resemble-ai/chatterbox";

      # 110M, from the Model Zoo table on the shared family model card.
      parameters = "110M";

      # The card's own figure: 3x realtime on eight CPU cores. CUDA and MPS are supported too.
      needsGpu = false;

      voiceCloning = true;

      licence = {
        name = "MIT";
        spdx = "MIT";
        commercialUse = "yes";
        caveat = ''
          MIT. Same Perth neural watermark on every generated file as the 500M original.
        '';
      };

      gated = false;
      unverified = { };

      sources = [
        "https://huggingface.co/ResembleAI/chatterbox-nano/raw/main/README.md"
        "https://huggingface.co/api/models/ResembleAI/chatterbox-nano"
        "https://api.github.com/repos/resemble-ai/chatterbox"
      ];

      note = ''
        A READING TRAP WORTH CARRYING, because it is the exact error this catalogue exists to stop.
        One model card covers the whole Chatterbox family, and it lists 23 languages -- for the
        500M multilingual variant. The Model Zoo table on that same card puts Nano at 110M and
        English. Anything that reads the card top to bottom, human or otherwise, attributes the
        language list to whichever model it was looking up. `studies/` records it.
      '';
    };

    # ── A device is the price of entry ──────────────────────────────────────────────────────────

    # https://huggingface.co/Qwen/Qwen3-TTS-12Hz-0.6B-Base/raw/main/README.md
    # https://huggingface.co/api/models/Qwen/Qwen3-TTS-12Hz-0.6B-Base
    "qwen3-tts-0.6b" = {
      name = "Qwen3-TTS 12Hz 0.6B";
      hfRepo = "Qwen/Qwen3-TTS-12Hz-0.6B-Base";
      upstream = "https://github.com/QwenLM/Qwen3-TTS";

      parameters = "0.6B";

      # In practice yes, and the honest form of that is what the official sample does rather than
      # what a card claims: it loads with `device_map="cuda:0"` in bfloat16, with optional
      # flash-attention. No CPU path is documented, which is not the same as none existing.
      needsGpu = true;

      voiceCloning = true;

      licence = {
        name = "Apache-2.0";
        spdx = "Apache-2.0";
        commercialUse = "yes";
        caveat = null;
      };

      gated = false;
      unverified = { };

      sources = [
        "https://huggingface.co/Qwen/Qwen3-TTS-12Hz-0.6B-Base/raw/main/README.md"
        "https://huggingface.co/api/models/Qwen/Qwen3-TTS-12Hz-0.6B-Base"
        "https://api.github.com/repos/QwenLM/Qwen3-TTS"
      ];

      note = ''
        AN EASY ID ERROR, which is why the repository id above is the one that was actually
        fetched: `QwenLM/Qwen3-TTS` is the canonical upstream and a similarly-named organisation
        carries a mirror of it. Sibling weights repositories at this and larger scales are
        described but were not separately verified, so they are not catalogued -- see
        `experiments/`.
      '';
    };

    # https://huggingface.co/openbmb/VoxCPM2/raw/main/README.md
    # https://huggingface.co/api/models/openbmb/VoxCPM2
    voxcpm2 = {
      name = "VoxCPM2";
      hfRepo = "openbmb/VoxCPM2";
      upstream = "https://github.com/OpenBMB/VoxCPM";

      # "Based on MiniCPM-4, totally 2B parameters", model card.
      parameters = "2B";

      # The card states the requirement rather than implying it: roughly 8 GB of VRAM, CUDA >= 12.0,
      # PyTorch >= 2.5.0.
      needsGpu = true;

      voiceCloning = true;

      licence = {
        name = "Apache-2.0";
        spdx = "Apache-2.0";
        commercialUse = "yes";
        # Also stated in words on the card: "Fully Open-Source & Commercial-Ready -- Apache-2.0
        # license, free for commercial use."
        caveat = null;
      };

      gated = false;
      unverified = { };

      sources = [
        "https://huggingface.co/openbmb/VoxCPM2/raw/main/README.md"
        "https://huggingface.co/api/models/openbmb/VoxCPM2"
        "https://api.github.com/repos/OpenBMB/VoxCPM"
      ];

      note = ''
        The best licence-to-capability ratio in this catalogue above the small tier: cloning, a
        clean Apache-2.0 with no second instrument attached, and a card that says commercial use is
        intended rather than leaving it to a tag.
      '';
    };

    # https://huggingface.co/nineninesix/gepard-1.0/raw/main/README.md
    # https://huggingface.co/api/models/nineninesix/gepard-1.0
    "gepard-1.0" = {
      name = "Gepard 1.0";
      hfRepo = "nineninesix/gepard-1.0";
      upstream = "https://github.com/nineninesix-ai/gepard-inference";

      # Backbone plus audio interface plus voice-cloning compressor.
      parameters = "~555.7M total (backbone ~500M)";

      needsGpu = true;
      voiceCloning = true;

      licence = {
        name = "Apache-2.0 (model); NVIDIA Open Model License Agreement (NeMo NanoCodec)";
        spdx = null;
        commercialUse = "conditional";
        caveat = ''
          A TWO-LICENCE STACK, not a clean Apache-2.0. The model is Apache-2.0; the audio codec it
          depends on is NVIDIA's NeMo NanoCodec, governed by a separate NVIDIA Open Model License
          Agreement. Both instruments have to be read, and only the first one is the permissive one
          a reader would assume from the model's own tag.
        '';
      };

      gated = false;
      unverified = { };

      sources = [
        "https://huggingface.co/nineninesix/gepard-1.0/raw/main/README.md"
        "https://huggingface.co/api/models/nineninesix/gepard-1.0"
        "https://api.github.com/repos/nineninesix-ai/gepard-inference"
      ];

      note = ''
        YOUNG, and that is a fact about the risk rather than about the model: both of its official
        serving repositories had double-digit stars when this was recorded (2026-08-19), against
        five-figure counts for everything else at this scale. Fine to try; not something to build a
        tier on before somebody else has.
      '';
    };

    # ── Licences that are not what the code's licence looks like ────────────────────────────────

    # https://huggingface.co/k2-fsa/OmniVoice/raw/main/README.md
    # https://huggingface.co/api/models/k2-fsa/OmniVoice
    omnivoice = {
      name = "OmniVoice";
      hfRepo = "k2-fsa/OmniVoice";
      upstream = "https://github.com/k2-fsa/OmniVoice";

      # NOT ESTABLISHED BY THE WEIGHTS REPOSITORY. See `unverified` below.
      parameters = null;

      # NVIDIA CUDA, Apple Silicon MPS or Intel Arc XPU; no CPU path is documented.
      needsGpu = true;

      voiceCloning = true;

      licence = {
        name = "CC-BY-NC (weights); Apache-2.0 (code)";
        spdx = null;
        commercialUse = "no";
        caveat = ''
          THE WEIGHTS ARE NON-COMMERCIAL, and the repository's licence tag will not tell you.
          Verbatim from the model card: "Our code is released under the Apache 2.0 License. The
          pre-trained model is licensed under the CC-BY-NC due to constraints from its training
          data (e.g., Emilia)." The Hugging Face repository carries NO licence tag at all, so
          anything keying on the tag records it as unlicensed, and a reader who sees Apache-2.0 in
          the sentence assumes it covers the weights. It does not. This model is the reason this
          catalogue treats `commercialUse` as a judgement to be sourced rather than a tag to be
          copied.
        '';
      };

      gated = false;

      unverified = {
        parameters = ''
          The model card states no parameter count -- "param", "0.8B" and "billion" all return
          nothing. A 0.8B backbone initialised from Qwen3-0.6B is stated in the paper
          (https://huggingface.co/papers/2604.00688) and not in the weights repository, so
          establishing it here means confirming that the released weights are the paper's model
          rather than assuming the two describe each other.
        '';
      };

      sources = [
        "https://huggingface.co/k2-fsa/OmniVoice/raw/main/README.md"
        "https://huggingface.co/api/models/k2-fsa/OmniVoice"
        "https://huggingface.co/papers/2604.00688"
        "https://github.com/k2-fsa/OmniVoice"
      ];

      note = ''
        The broadest language coverage of anything here by a wide margin, and unusable in a
        commercial context on the weights' own terms. Catalogued because a model you cannot use is
        still a model somebody will propose, and the second time it comes up the answer should
        already be written down.
      '';
    };

    # https://huggingface.co/fishaudio/s2-pro/raw/main/README.md
    # https://huggingface.co/api/models/fishaudio/s2-pro
    fish-s2-pro = {
      name = "Fish Audio S2 Pro";
      hfRepo = "fishaudio/s2-pro";
      upstream = "https://github.com/fishaudio/fish-speech";

      # Dual-AR: a 4B slow autoregressive stage over a 400M fast one.
      parameters = "4.4B total (4B + 400M)";

      needsGpu = true;

      # NOT ESTABLISHED. See `unverified` below.
      voiceCloning = null;

      licence = {
        name = "Fish Audio Research License";
        spdx = null;
        commercialUse = "no";
        caveat = ''
          Non-commercial without a paid licence. The card: "Research and non-commercial use is
          permitted free of charge. Commercial use requires a separate license from Fish Audio."
          The weights are additionally published behind an agreement gate whose fields include a
          "I agree to use this model for non-commercial use ONLY" checkbox, so accepting the terms
          is part of obtaining them -- see `gated`, which records the terms and not their
          enforcement: a run of `experiments/verify-voices.sh` on 2026-08-20 found the hub's own
          enforcement flag reading false and an anonymous file request answered with a redirect
          rather than refused. The agreement is what binds; the wall is not currently up.
        '';
      };

      gated = true;

      unverified = {
        voiceCloning = ''
          The model card documents inline prosody and emotion tags and a very wide language list,
          and says nothing either way about zero-shot speaker cloning from reference audio. The
          family it belongs to historically supports it, which is an inference and not a source.
          Establishing it means reading the technical report rather than the card.
        '';
      };

      sources = [
        "https://huggingface.co/fishaudio/s2-pro/raw/main/README.md"
        "https://huggingface.co/api/models/fishaudio/s2-pro"
        "https://api.github.com/repos/fishaudio/fish-speech"
      ];

      note = ''
        Its serving path is a purpose-built streaming engine with continuous batching and prefix
        caching rather than a reference script, which is a different class of operational
        commitment from everything above it -- and moot here anyway while the licence says what it
        says.
      '';
    };

    # https://huggingface.co/api/models/bosonai/higgs-tts-3-4b
    # https://www.boson.ai/blog/higgs-audio-v3-tts
    higgs-tts-3 = {
      name = "Higgs TTS 3";
      hfRepo = "bosonai/higgs-tts-3-4b";
      upstream = "https://github.com/boson-ai/higgs-audio";

      # ~4B: a 36-layer autoregressive decoder, hidden size 2560, grouped query attention.
      parameters = "~4B";

      needsGpu = true;
      voiceCloning = true;

      licence = {
        name = "Boson Higgs TTS 3 Research and Non-Commercial License";
        spdx = null;
        commercialUse = "no";
        caveat = ''
          Non-commercial by default: commercial deployment, API hosting, embedding in a product and
          resale of the model each require a separate paid licence. There is one narrow carve-out --
          a digital creator may monetise podcasts, video or social content at no charge PROVIDED
          the work credits "Boson AI's Higgs Audio" in the audio or prominently in accompanying
          text. The licence separately forbids unauthorised voice cloning, impersonation, fraud,
          election manipulation and biometric surveillance.
        '';
      };

      gated = false;
      unverified = { };

      sources = [
        "https://huggingface.co/bosonai/higgs-audio-v3-tts-4b/raw/main/README.md"
        "https://huggingface.co/api/models/bosonai/higgs-tts-3-4b"
        "https://www.boson.ai/blog/higgs-audio-v3-tts"
        "https://api.github.com/repos/boson-ai/higgs-audio"
      ];

      note = ''
        THE REPOSITORY WAS RENAMED and the vendor's own blog still links the old id, which redirects
        rather than 404s -- so a fetcher following the blog gets weights and a reader copying the
        blog's id records a name that is no longer canonical. The id above is the one the API
        resolves to.
      '';
    };

    # ── Kept because they will be proposed again ────────────────────────────────────────────────

    # https://huggingface.co/coqui/XTTS-v2
    # https://huggingface.co/coqui/XTTS-v2/raw/main/LICENSE.txt
    xtts-v2 = {
      name = "XTTS-v2";
      hfRepo = "coqui/XTTS-v2";
      # The original upstream is abandoned; this is the maintained community fork, which is where a
      # serving path has to come from now.
      upstream = "https://github.com/idiap/coqui-ai-TTS";

      # NOT ESTABLISHED. See `unverified` below.
      parameters = null;
      needsGpu = null;

      voiceCloning = true;

      licence = {
        name = "Coqui Public Model License (CPML) 1.0.0";
        spdx = null;
        commercialUse = "no";
        caveat = ''
          Read against the licence text rather than the tag: the grant is "for any non-commercial
          purpose", and receiving "any direct or indirect payment arising from the use of the model
          or its output" takes an activity outside it. A commercial entity may use it for testing,
          evaluation and non-commercial research and no further. This is a hard blocker in a
          commercial context and is independent of whether the model is any good.

          AND IT IS A CODE/WEIGHTS SPLIT, the second one in this catalogue: the maintained fork that
          serves these weights is MPL-2.0, an open-source licence, while the weights themselves are
          not. Reading the serving code's licence and stopping there gets this exactly backwards.
        '';
      };

      gated = false;

      unverified = {
        parameters = ''
          Neither the model card nor the repository states a parameter count. Establishing it means
          reading it off the released checkpoint's own tensor shapes.
        '';
        needsGpu = ''
          The card states no device requirement in either direction. Establishing it means running
          the maintained fork on a CPU and measuring, rather than inferring from the model's size.
        '';
      };

      sources = [
        "https://huggingface.co/coqui/XTTS-v2"
        "https://huggingface.co/coqui/XTTS-v2/raw/main/LICENSE.txt"
        "https://api.github.com/repos/coqui-ai/TTS"
        "https://api.github.com/repos/idiap/coqui-ai-TTS"
      ];

      note = ''
        STILL ENORMOUSLY DOWNLOADED AND STILL NOT A CANDIDATE, which is why it is written down.
        Inertia is not maintenance: the original repository's last push was 2024-08-16 and the
        weights repository was last modified in December 2023 (recorded 2026-08-19). The licence
        settles it before the staleness has to.
      '';
    };

    # https://huggingface.co/suno/bark/raw/main/README.md
    # https://api.github.com/repos/suno-ai/bark
    bark = {
      name = "Bark";
      hfRepo = "suno/bark";
      upstream = "https://github.com/suno-ai/bark";

      # Carried in the source's own words rather than resolved into one number: the model is three
      # stacked stages (text-to-semantic, semantic-to-coarse, coarse-to-fine) and the card gives the
      # scale per stage.
      parameters = "three stacked models at 80M/300M each";

      # NOT ESTABLISHED. See `unverified` below.
      needsGpu = null;

      # HEDGED IN THE SOURCE, so it is hedged here. The card does not say Bark cannot clone; it says
      # "it is not straightforward to voice clone known people with Bark" while warning the model
      # can still be misused. That is a statement about difficulty, not capability, and there is no
      # documented reference-audio path in the released package -- what it ships is a fixed set of
      # speaker presets.
      #
      # Recorded as false because no supported cloning interface exists in the open release, NOT
      # because the card denies it. If that distinction ever matters to a decision, read the card
      # rather than this field.
      voiceCloning = false;

      licence = {
        name = "MIT";
        spdx = "MIT";
        commercialUse = "yes";
        caveat = null;
      };

      gated = false;

      unverified = {
        needsGpu = ''
          The card states no device requirement. It is practically GPU-oriented and slow relative
          to anything released since, but "slow on a CPU" is a measurement nobody in these sources
          took, and the field is not a place to record an impression.
        '';
      };

      sources = [
        "https://huggingface.co/suno/bark/raw/main/README.md"
        "https://huggingface.co/api/models/suno/bark"
        "https://api.github.com/repos/suno-ai/bark"
      ];

      note = ''
        Effectively unmaintained: upstream's last push was 2024-08-19 and the weights repository was
        last modified in October 2023 (recorded 2026-08-19). Catalogued because it is supported by
        the mainstream transformers library, which keeps it findable long after it stopped being a
        reasonable choice.
      '';
    };
  };
}
