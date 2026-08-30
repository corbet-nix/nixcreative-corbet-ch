{
  description = "nixcreative — declarative creative tool selection for creation workflows (DAW, vector, raster, 3D), plus the generative-media applications that run in the cluster instead of on a desk and the speech models they serve.";

  # THE PACKAGE SIDE STILL TAKES NOTHING BUT NIXPKGS. `nixidy` remains checks-only, while the
  # exported cluster module closes over nixk3s' catalogue-consumer factory. A host importing only
  # the package modules still puts neither the renderer nor a sibling flake's input closure into
  # its own closure.
  #
  # They exist because `nix flake check` evaluates no module output on its own. A cluster module
  # with no renderer to evaluate against would have been verified by nobody and would have passed
  # on flake syntax alone, which is not a check.
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # The renderer the cluster module defines into.
    nixidy = {
      url = "github:arnarg/nixidy";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # THE APP GRAMMAR AND CONSUMER FACTORY THIS REPOSITORY CONSUMES. The checks render through the
    # real grammar, and the exported cluster module is constructed by the matching factory rather
    # than carrying another copy of its catalogue projection.
    nixk3s = {
      url = "github:julian-corbet/nixk3s-corbet-ch";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixidy.follows = "nixidy";
    };
  };

  outputs = { self, nixpkgs, nixidy, nixk3s }:
    let
      lib = nixpkgs.lib;

      # The package catalogue is resolved by evaluation alone, so it is honest on every system a
      # host might be.
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];

      # The cluster checks are NOT, and the narrowing is on purpose: each one BUILDS a real nixidy
      # environment, so a declared platform that cannot be built here is a platform `nix flake
      # check` skips while exiting 0 -- a check that passed having tested nothing. Narrow the claim
      # rather than weaken the check.
      clusterSystems = [ "x86_64-linux" ];

      forAllSystems = lib.genAttrs supportedSystems;
    in
    {
      # Platform-neutral policy and package catalogue.
      nixosModules.nixcreative = ./modules/nixcreative.nix;
      homeManagerModules.nixcreative = ./home/nixcreative.nix;
      homeManagerModules.default = ./home/nixcreative.nix;
      homeManagerModules.install = ./home/nixcreative.nix;
      homeManagerModules.blender-mcp = ./home/blender-mcp.nix;

      # Install plane: NixOS host packages.
      nixosModules.default = ./modules/nixos.nix;
      nixosModules.install = ./modules/nixos.nix;

      # Arch/CachyOS plane: publish `nixcreative.archPackages` / `.aurPackages` into host reconciler.
      systemManagerModules.nixcreative = ./modules/arch.nix;
      systemManagerModules.default = ./modules/arch.nix;
      systemManagerModules.install = ./modules/arch.nix;

      # The cluster plane: gate 2's other half. A tool whose working set is model weights is not a
      # package here, and it was never another repository's SUBJECT either -- so it runs as a
      # workload declared from this module. Only one module in the class, so `.default` is honest
      # rather than invented.
      nixidyModules.nixcreative = import ./modules/cluster.nix {
        mkConsumerModule = nixk3s.lib.mkConsumerModule;
      };
      nixidyModules.default = self.nixidyModules.nixcreative;

      # Expose every catalogue for introspection, docs, and checks.
      lib.catalogue = import ./lib/creative.nix { };
      lib.applications = (import ./lib/applications.nix { }).applications;

      # The voice-model catalogue: which speech model a cluster workload serves, and the facts that
      # decide whether it can be served at all. Exported for the same reason as the other two --
      # something outside this flake has to be able to read a licence position without evaluating
      # a module or opening a container.
      lib.voices = (import ./lib/voices.nix { }).voices;

      checks = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          catalogue-eval = import ./checks/catalogue-eval.nix { inherit pkgs; };
          blender-mcp-home-eval = import ./checks/blender-mcp-home-eval.nix { inherit pkgs; };

          # The voice catalogue's own evidence rule, and the seam between the two `lib/`
          # catalogues. Pure data, so it is honest on every system rather than narrowed like the
          # two cluster checks below.
          voices-eval = import ./checks/voices-eval.nix { inherit pkgs; };
        }
        // lib.optionalAttrs (lib.elem system clusterSystems) {
          # The cluster module's own resolution and every guard it makes, in BOTH directions: an
          # empty surface renders nothing, a declared one resolves, and each refusal gets a
          # declaration that must be refused.
          cluster-eval = import ./checks/cluster-eval.nix {
            inherit pkgs lib nixidy;
            appsModule = nixk3s.nixidyModules.apps;
            clusterModule = self.nixidyModules.nixcreative;
            values = ./examples/all/values.nix;
          };

          # The manifests that actually come out, read back off the rendered bytes rather than off
          # the options that produced them.
          cluster-render = import ./checks/cluster-render.nix {
            inherit pkgs lib nixidy;
            appsModule = nixk3s.nixidyModules.apps;
            clusterModule = self.nixidyModules.nixcreative;
            values = ./examples/all/values.nix;
          };
        });

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixpkgs-fmt);
    };
}
