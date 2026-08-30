# Evaluates the Blender MCP Home Manager integration against the smallest honest host-option
# surface. This checks rendered behavior without importing Home Manager as a flake dependency.
{ pkgs, lib ? pkgs.lib }:
let
  fakeHomeManager = { lib, ... }: {
    options = {
      home.homeDirectory = lib.mkOption { type = lib.types.str; };
      home.file = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
      };
      home.activation = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
      };
      systemd.user.services = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
      };
    };

    config.home.homeDirectory = "/build/home";
  };

  evaluated = lib.evalModules {
    modules = [
      fakeHomeManager
      ../home/blender-mcp.nix
      {
        nixcreative.blender.mcp = {
          enable = true;
          blenderBinary = "/usr/bin/blender";
          uvxBinary = "/usr/bin/uvx";
          codex.binary = "/usr/bin/codex";
        };
      }
    ];
    specialArgs = { inherit pkgs; };
  };

  cfg = evaluated.config;
  integration = import ../lib/blender-mcp.nix;
  setupService = cfg.systemd.user.services.nixcreative-blender-mcp-setup;
  registration = cfg.home.activation.nixcreativeBlenderMcpCodex.data;
  has = needle: haystack: lib.hasInfix needle haystack;

  results = {
    "official addon archive is staged in the home" =
      builtins.hasAttr ".local/share/nixcreative/blender-mcp/mcp-${integration.version}.zip" cfg.home.file;

    "setup service is enabled and retries until Blender can be changed safely" =
      setupService.Install.WantedBy == [ "default.target" ]
      && setupService.Service.Restart == "on-failure"
      && setupService.Service.RestartSec == 30;

    "setup service installs and enables the official extension" =
      has "extension install-file"
        cfg.home.file.".local/share/nixcreative/blender-mcp/setup".text;

    "Codex registration pins the official server commit" =
      has integration.sourceRevision registration
      && has "projects.blender.org/lab/blender_mcp.git" registration;

    "Codex registration pins the compatible MCP Python SDK" =
      has integration.pythonMcpRequirement registration;

    "Codex registration prompts before every Blender tool call" =
      has ''default_tools_approval_mode = "prompt"'' registration;

    "Codex registration uses the declared uvx binary" =
      has ''command = "/usr/bin/uvx"'' registration;
  };

  failed = lib.attrNames (lib.filterAttrs (_: passed: !passed) results);
in
if failed == [ ] then
  pkgs.runCommand "nixcreative-blender-mcp-home-eval"
  {
    addon = cfg.home.file.".local/share/nixcreative/blender-mcp/mcp-${integration.version}.zip".source;
    registrationScript = pkgs.writeShellScript "register-blender-mcp" registration;
    setupScript = pkgs.writeText "setup-blender-mcp" cfg.home.file.".local/share/nixcreative/blender-mcp/setup".text;
    nativeBuildInputs = [ pkgs.unzip ];
  }
    ''
      ${pkgs.runtimeShell} -n "$registrationScript"
      ${pkgs.runtimeShell} -n "$setupScript"

      # Execute the staged file itself, not only `bash -n` its contents. This catches a missing
      # interpreter line, which systemd reports as status=203/EXEC before the script can retry.
      install -m 0755 "$setupScript" executable-setup
      set +e
      ./executable-setup
      setup_status=$?
      set -e
      test "$setup_status" -eq 75

      test -s "$addon"
      unzip -p "$addon" blender_manifest.toml > manifest.toml
      grep -F 'id = "mcp"' manifest.toml
      grep -F 'version = "${integration.version}"' manifest.toml
      grep -F 'blender_version_min = "5.1.0"' manifest.toml

      mkdir -p /build/home/.codex
      printf '%s\n' '[mcp_servers.existing]' 'command = "existing"' > /build/home/.codex/config.toml
      "$registrationScript"
      "$registrationScript"
      grep -F '[mcp_servers.existing]' /build/home/.codex/config.toml
      test "$(grep -Fc '# BEGIN nixcreative: blender-mcp' /build/home/.codex/config.toml)" -eq 1
      grep -F 'default_tools_approval_mode = "prompt"' /build/home/.codex/config.toml

      touch "$out"
    ''
else
  throw ''
    nixcreative: blender-mcp-home-eval check failed:
    ${lib.concatMapStringsSep "\n" (f: "  - ${f}") failed}
  ''
