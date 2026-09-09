# dx.agents.grok-build — Grok Build from xAI
# Migrated from: ghcr.io/docker-x/devcontainers/grok-build
# Install method: GitHub release binary

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.agents.grokBuild;
  agentConfigDir = config.dx.core.agentConfig.dir or "\${AGENT_CONFIG_DIR:-$HOME/.local/share/agent-config}";
in
{
  options.dx.agents.grokBuild = helpers.mkAgentOptions {
    agentId = "grok-build";
    name = "Grok Build";
  };

  config = lib.mkIf cfg.enable {
    dx.core.agentConfig.enable = lib.mkIf cfg.shareConfig true;

    packages = [
      (helpers.mkGithubBinary {
        pname = "grok-build";
        version = if cfg.version == "latest" then "latest" else cfg.version;
        owner = "xai";
        repo = "grok-build";
        asset = "grok-build-linux-amd64";
        sha256 = lib.fakeHash;
      })
    ];

    enterShell = lib.optionalString cfg.shareConfig (helpers.shareConfigHook {
      agentId = "grok-build";
      configPaths = [ "$HOME/.grok-build" "$HOME/.config/grok-build" ];
      agentConfigDir = toString agentConfigDir;
    });
  };
}
