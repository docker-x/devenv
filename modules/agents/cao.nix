# dx.agents.cao — CLI Agent Orchestrator (CAO) from AWS Labs
# Migrated from: ghcr.io/docker-x/devcontainers/cao
# Install method: GitHub release binary

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.agents.cao;
  agentConfigDir = config.dx.core.agentConfig.dir or "\${AGENT_CONFIG_DIR:-$HOME/.local/share/agent-config}";
in
{
  options.dx.agents.cao = helpers.mkAgentOptions {
    agentId = "cao";
    name = "CLI Agent Orchestrator (CAO)";
  };

  config = lib.mkIf cfg.enable {
    dx.core.agentConfig.enable = lib.mkIf cfg.shareConfig true;

    packages = [
      (helpers.mkGithubBinary {
        pname = "cao";
        version = if cfg.version == "latest" then "latest" else cfg.version;
        owner = "aws-samples";
        repo = "cli-agent-orchestrator";
        asset = "cao-linux-amd64";
        sha256 = lib.fakeHash;
      })
    ];

    enterShell = lib.optionalString cfg.shareConfig (helpers.shareConfigHook {
      agentId = "cao";
      configPaths = [ "$HOME/.cao" "$HOME/.config/cao" ];
      agentConfigDir = toString agentConfigDir;
    });
  };
}
