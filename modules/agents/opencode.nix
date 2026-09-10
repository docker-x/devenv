# dx.agents.opencode — OpenCode AI
# Migrated from: ghcr.io/docker-x/devcontainers/opencode
# Install methods: npm or binary

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.agents.opencode;
  agentConfigDir = config.dx.core.agentConfig.dir or "\${AGENT_CONFIG_DIR:-$HOME/.local/share/agent-config}";
in
{
  options.dx.agents.opencode = helpers.mkAgentOptions {
    agentId = "opencode";
    name = "OpenCode AI";
    extraOptions = {
      installMethod = lib.mkOption {
        type = lib.types.enum [ "npm" "binary" ];
        default = "npm";
        description = "Install OpenCode via npm or a direct binary download.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    dx.core.agentConfig.enable = lib.mkIf cfg.shareConfig true;

    packages = lib.optional (cfg.installMethod == "npm")
      (helpers.mkNpmCli {
        pname = "opencode";
        npmName = "opencode-ai";
        version = cfg.version;
        sha256 = lib.fakeHash;
      }) ++ lib.optional (cfg.installMethod == "binary")
      (helpers.mkGithubBinary {
        pname = "opencode";
        version = if cfg.version == "latest" then "latest" else cfg.version;
        owner = "opencode-ai";
        repo = "opencode";
        asset = "opencode-linux-amd64";
        sha256 = lib.fakeHash;
      });

    enterShell = lib.optionalString cfg.shareConfig (helpers.shareConfigHook {
      agentId = "opencode";
      configPaths = [ "$HOME/.opencode" "$HOME/.config/opencode" ];
      agentConfigDir = toString agentConfigDir;
    });
  };
}
