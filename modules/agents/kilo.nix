# dx.agents.kilo — Kilo CLI
# Migrated from: ghcr.io/docker-x/devcontainers/kilo
# Install method: GitHub release binary

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.agents.kilo;
  agentConfigDir = config.dx.core.agentConfig.dir or "\${AGENT_CONFIG_DIR:-$HOME/.local/share/agent-config}";
in
{
  options.dx.agents.kilo = helpers.mkAgentOptions {
    agentId = "kilo";
    name = "Kilo CLI";
    hasShareConfig = false;
  };

  config = lib.mkIf cfg.enable {
    packages = [
      (helpers.mkGithubBinary {
        pname = "kilo";
        version = if cfg.version == "latest" then "latest" else cfg.version;
        owner = "kilo";
        repo = "kilo";
        asset = "kilo-linux-amd64";
        sha256 = lib.fakeHash;
      })
    ];
  };
}
