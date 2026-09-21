# SPDX-License-Identifier: MIT OR Apache-2.0
{ lib, ... }:
{
  options.nixcreative.blender.mcp = {
    enable = lib.mkEnableOption "the official Blender Lab MCP integration";

    blenderBinary = lib.mkOption {
      type = lib.types.str;
      default = "blender";
      description = ''
        Blender command used by the per-user setup service. A foreign-distro consumer should set
        an absolute path supplied by its package backend rather than naming one in this module.
      '';
    };

    uvxBinary = lib.mkOption {
      type = lib.types.str;
      default = "uvx";
      description = ''
        uvx command written into the MCP client configuration. The host-level Python/uv floor is
        deliberately owned by a development-tool module; nixcreative owns only this use of it.
      '';
    };

    host = lib.mkOption {
      type = lib.types.enum [ "localhost" "127.0.0.1" ];
      default = "127.0.0.1";
      description = "Loopback address used by Blender's MCP bridge. Non-loopback listeners are refused by type.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 9876;
      description = "Local TCP port used by the official Blender MCP bridge.";
    };

    codex = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Register the pinned official server in Codex's MCP configuration.";
      };

      binary = lib.mkOption {
        type = lib.types.str;
        default = "codex";
        description = "Codex command used to validate the managed MCP configuration block.";
      };

      configPath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Codex config.toml path; null resolves to ~/.codex/config.toml on the Home Manager plane.";
      };

      startupTimeoutSeconds = lib.mkOption {
        type = lib.types.ints.positive;
        default = 60;
        description = "Time allowed for uvx to materialize and start the pinned MCP server.";
      };

      toolTimeoutSeconds = lib.mkOption {
        type = lib.types.ints.positive;
        default = 300;
        description = "Maximum duration of one Blender MCP tool call.";
      };
    };
  };
}
