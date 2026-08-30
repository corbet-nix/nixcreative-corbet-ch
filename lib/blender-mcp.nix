let
  version = "1.0.0";
  sourceRevision = "03004fd0216bfe5e0a3d9ac9b47d5efadc3d78c4";
  pythonMcpVersion = "1.29.1";
in
{
  inherit version sourceRevision pythonMcpVersion;

  addonUrl =
    "https://projects.blender.org/lab/blender_mcp/releases/download/v${version}/mcp-${version}.zip";
  addonHash = "sha256-g4w0SfAQFchhKQZYrmfxIvCEb3iC9gpd/aDvfmqbhAM=";

  # `uvx` consumes this as a PEP 508 direct reference. A commit, not a branch or tag: identical
  # declarations launch identical server source even when Blender Lab moves its release refs.
  serverSource =
    "git+https://projects.blender.org/lab/blender_mcp.git@${sourceRevision}#subdirectory=mcp";

  # Blender Lab's pinned server still imports the MCP Python SDK's v1 FastMCP API, but its
  # pyproject only declares `mcp[cli]>=1.2.0`. MCP 2.x satisfies that open lower bound and then
  # fails before server startup because FastMCP was renamed. Keep the compatible direct runtime
  # dependency exact until the pinned server source migrates to the v2 API.
  pythonMcpRequirement = "mcp[cli]==${pythonMcpVersion}";

  # Arch's Blender package currently omits this runtime dependency even though its built-in
  # extension manager imports it. Without it every `blender --command extension ...` invocation
  # fails before the official MCP package can be installed.
  archRuntimePackages = [ "python-cattrs" ];
}
