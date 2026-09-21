# SPDX-License-Identifier: MIT OR Apache-2.0
{ ... }:
{
  # ── DAW ─────────────────────────────────────────────────────────────────────────────────────
  #
  # A digital audio workstation belongs HERE and not in nixrecord, and the reasoning is the one
  # this repo's gate already states: a DAW authors material whose result is not specified before
  # the work starts -- two people at the same session file produce two different records --
  # whereas nixrecord captures an event that happened. Recording a take is capture; arranging,
  # mixing and mastering it is not.
  #
  # The second reason is structural, and it is why this must not drift into nixrecord later: nixrecord
  # is single-host BECAUSE OF AN ENCODER (only one machine in this estate has an AV1 hardware
  # encoder). Anything filed there inherits that constraint permanently. Authoring is not
  # encoder-bound, so binding a DAW to one machine would be an accident of hardware, not a decision.
  #
  # The operator considered Ardour, Reaper and LMMS and declined all three; Audacity was declined
  # outright and was never a DAW candidate at all. qtractor is the pick -- a light, comprehensible
  # multitrack recorder, chosen on size over the alternatives (qtractor 8.7 MiB vs ardour 105 MiB /
  # reaper 127 MiB).
  daw = {
    qtractor = {
      arch = "qtractor";
      nixpkgs = "qtractor";
      description = "Lightweight multitrack audio/MIDI recorder and sequencer, JACK-native.";
    };
  };

  vector = {
    inkscape = {
      arch = "inkscape";
      nixpkgs = "inkscape";
      description = "SVG illustration and vector asset creation.";
    };
  };

  raster = {
    krita = {
      arch = "krita";
      nixpkgs = "krita";
      description = "Raster artwork and digital painting.";
    };
    # Agentic image authoring: authors raster images through ComfyUI rather than
    # painting pixels, so it files as image creation. AUR-only (first `aur = true`
    # entry in this catalogue) with no nixpkgs equivalent.
    ccti = {
      arch = "ccti";
      aur = true;
      nixpkgs = null;
      description = "Agentic ComfyUI image chat with inline terminal rendering.";
    };
  };

  # 3D, explicitly not video editing: blender authors scenes and renders, it does not cut footage.
  "3d" = {
    blender = {
      arch = "blender";
      nixpkgs = "blender";
      description = "3D creation suite and compositor for motion visuals.";
    };
  };
}
