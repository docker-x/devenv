# dx.agents.docker-agent — Docker Agent
# Migrated from: ghcr.io/docker-x/devcontainers/docker-agent
# Install method: GitHub release binary from docker/docker-agent

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.agents.dockerAgent;
  agentConfigDir = config.dx.core.agentConfig.dir or "\${AGENT_CONFIG_DIR:-$HOME/.local/share/agent-config}";
in
{
  options.dx.agents.dockerAgent = helpers.mkAgentOptions {
    agentId = "docker-agent";
    name = "Docker Agent";
  };

  config = lib.mkIf cfg.enable {
    dx.core.agentConfig.enable = lib.mkIf cfg.shareConfig true;

    packages = [
      (helpers.mkGithubBinary {
        pname = "docker-agent";
        version = if cfg.version == "latest" then "latest" else cfg.version;
        owner = "docker";
        repo = "docker-agent";
        asset = "docker-agent-linux-amd64";
        sha256 = lib.fakeHash;
      })
    ];

    enterShell = lib.optionalString cfg.shareConfig (helpers.shareConfigHook {
      agentId = "docker-agent";
      configPaths = [ "$HOME/.docker-agent" "$HOME/.config/docker-agent" ];
      agentConfigDir = toString agentConfigDir;
    });
  };
}
