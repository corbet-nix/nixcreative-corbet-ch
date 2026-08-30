# Per-user half of the official Blender Lab MCP integration.
#
# Blender stores extension enablement and online-access permission in binary user preferences, so
# a declarative file link cannot finish this job. The retrying oneshot below is the narrow adoption
# boundary: it waits until Blender is closed, asks Blender's own extension CLI to install+enable the
# pinned official archive, then writes only the preferences this bridge needs. The Codex entry is a
# tagged block in the existing config.toml so unrelated user and tool configuration remains owned by
# whoever already owns it.
{ config, lib, pkgs, ... }:
let
  cfg = config.nixcreative.blender.mcp;
  integration = import ../lib/blender-mcp.nix;

  addonRelativePath = ".local/share/nixcreative/blender-mcp/mcp-${integration.version}.zip";
  setupRelativePath = ".local/share/nixcreative/blender-mcp/setup";
  addonPath = "${config.home.homeDirectory}/${addonRelativePath}";
  setupPath = "${config.home.homeDirectory}/${setupRelativePath}";
  stateDirectory = "${config.home.homeDirectory}/.local/state/nixcreative/blender-mcp";
  stampPath = "${stateDirectory}/${integration.sourceRevision}";
  codexConfigPath =
    if cfg.codex.configPath == null
    then "${config.home.homeDirectory}/.codex/config.toml"
    else cfg.codex.configPath;

  addonArchive = pkgs.fetchurl {
    url = integration.addonUrl;
    hash = integration.addonHash;
  };

  pythonPreferenceCode = ''
    import bpy
    preferences = bpy.context.preferences
    preferences.system.use_online_access = True
    addon = preferences.addons["bl_ext.user_default.mcp"].preferences
    addon.host = ${builtins.toJSON cfg.host}
    addon.port = ${toString cfg.port}
    addon.use_autostart = True
    bpy.ops.wm.save_userpref()
  '';

  setupScript = ''
    #!${pkgs.runtimeShell}
    set -eu

    blender=${lib.escapeShellArg cfg.blenderBinary}
    addon=${lib.escapeShellArg addonPath}
    stamp=${lib.escapeShellArg stampPath}

    if [ -e "$stamp" ]; then
      exit 0
    fi

    # Never load and save Blender's binary preferences beside another live Blender process. The
    # service retries until the UI closes instead of overwriting preferences from a stale snapshot.
    for comm in /proc/[0-9]*/comm; do
      [ -r "$comm" ] || continue
      IFS= read -r process_name < "$comm" || true
      if [ "$process_name" = blender ]; then
        echo "nixcreative-blender-mcp: Blender is running; retrying after it closes" >&2
        exit 75
      fi
    done

    if [ ! -x "$blender" ]; then
      echo "nixcreative-blender-mcp: Blender is not available at $blender; retrying" >&2
      exit 75
    fi

    mkdir -p ${lib.escapeShellArg stateDirectory}

    "$blender" --background --online-mode \
      --command extension install-file -r user_default -e "$addon"

    "$blender" --background --online-mode \
      --python-expr ${lib.escapeShellArg pythonPreferenceCode}

    touch "$stamp"
    echo "nixcreative-blender-mcp: installed official MCP ${integration.version} and enabled loopback auto-start"
  '';

  managedBegin = "# BEGIN nixcreative: blender-mcp";
  managedEnd = "# END nixcreative: blender-mcp";
  codexBlock = ''
    ${managedBegin}
    [mcp_servers.blender]
    command = ${builtins.toJSON cfg.uvxBinary}
    args = [
      "--with",
      ${builtins.toJSON integration.pythonMcpRequirement},
      "--from",
      ${builtins.toJSON integration.serverSource},
      "blender-mcp"
    ]
    startup_timeout_sec = ${toString cfg.codex.startupTimeoutSeconds}
    tool_timeout_sec = ${toString cfg.codex.toolTimeoutSeconds}
    default_tools_approval_mode = "prompt"
    ${managedEnd}
  '';
in
{
  imports = [ ../modules/blender-mcp-options.nix ];

  config = lib.mkIf cfg.enable {
    home.file.${addonRelativePath}.source = addonArchive;
    home.file.${setupRelativePath} = {
      text = setupScript;
      executable = true;
    };

    systemd.user.services.nixcreative-blender-mcp-setup = {
      Unit = {
        Description = "Install and enable the official Blender Lab MCP extension";
      };
      Service = {
        Type = "oneshot";
        ExecStart = setupPath;
        Restart = "on-failure";
        RestartSec = 30;
      };
      Install.WantedBy = [ "default.target" ];
    };

    # The literal DAG record keeps this module evaluable without importing Home Manager as a
    # second flake input. Home Manager accepts the same shape returned by lib.hm.dag.entryAfter.
    home.activation.nixcreativeBlenderMcpCodex = lib.mkIf cfg.codex.enable {
      after = [ "writeBoundary" ];
      before = [ ];
      data = ''
        export PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.gawk pkgs.gnugrep ]}:$PATH
        config_file=${lib.escapeShellArg codexConfigPath}
        begin=${lib.escapeShellArg managedBegin}
        end=${lib.escapeShellArg managedEnd}
        codex=${lib.escapeShellArg cfg.codex.binary}
        work="$(mktemp -d)"
        trap 'rm -rf "$work"' EXIT

        mkdir -p "$(dirname "$config_file")"
        if [ -f "$config_file" ]; then
          awk -v begin="$begin" -v end="$end" '
            $0 == begin { managed = 1; next }
            $0 == end { managed = 0; next }
            !managed { print }
            END { if (managed) exit 42 }
          ' "$config_file" > "$work/base.toml"
        else
          : > "$work/base.toml"
        fi

        if grep -Fqx '[mcp_servers.blender]' "$work/base.toml"; then
          echo "nixcreative-blender-mcp: refusing to replace an unmanaged Codex blender entry" >&2
          exit 1
        fi

        {
          cat "$work/base.toml"
          printf '\n%s\n' ${lib.escapeShellArg codexBlock}
        } > "$work/config.toml"

        if [ -x "$codex" ]; then
          CODEX_HOME="$work" "$codex" mcp get blender --json >/dev/null
        else
          echo "nixcreative-blender-mcp: Codex not available at $codex; writing the declarative entry without CLI validation" >&2
        fi

        install -m 0600 "$work/config.toml" "$config_file"
      '';
    };
  };
}
