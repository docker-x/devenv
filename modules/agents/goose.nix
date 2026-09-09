# dx.agents.goose — Goose CLI from Block
# Migrated from: ghcr.io/docker-x/devcontainers/goose
# Install method: GitHub release binary from aaif-goose/goose

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.agents.goose;
  agentConfigDir = config.dx.core.agentConfig.dir or "\${AGENT_CONFIG_DIR:-$HOME/.local/share/agent-config}";
in
{
  options.dx.agents.goose = helpers.mkAgentOptions {
    agentId = "goose";
    name = "Goose CLI";
  };

  config = lib.mkIf cfg.enable {
    dx.core.agentConfig.enable = lib.mkIf cfg.shareConfig true;

    packages = [
      (helpers.mkGithubBinary {
        pname = "goose";
        version = if cfg.version == "latest" then "latest" else cfg.version;
        owner = "aaif-goose";
        repo = "goose";
        asset = "goose-linux-amd64.tar.gz";
        sha256 = lib.fakeHash;
      })
    ];

    enterShell = lib.optionalString cfg.shareConfig (helpers.shareConfigHook {
      agentId = "goose";
      configPaths = [ "$HOME/.goose" "$HOME/.config/goose" ];
      agentConfigDir = toString agentConfigDir;
    });
  };
}
