# dx.agents.hermes — Hermes Agent from Nous Research
# Migrated from: ghcr.io/docker-x/devcontainers/hermes
# Install method: GitHub release binary

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.agents.hermes;
  agentConfigDir = config.dx.core.agentConfig.dir or "\${AGENT_CONFIG_DIR:-$HOME/.local/share/agent-config}";
in
{
  options.dx.agents.hermes = helpers.mkAgentOptions {
    agentId = "hermes";
    name = "Hermes Agent";
  };

  config = lib.mkIf cfg.enable {
    dx.core.agentConfig.enable = lib.mkIf cfg.shareConfig true;

    packages = [
      (helpers.mkGithubBinary {
        pname = "hermes";
        version = if cfg.version == "latest" then "latest" else cfg.version;
        owner = "NousResearch";
        repo = "hermes";
        asset = "hermes-linux-amd64";
        sha256 = lib.fakeHash;
      })
    ];

    enterShell = lib.optionalString cfg.shareConfig (helpers.shareConfigHook {
      agentId = "hermes";
      configPaths = [ "$HOME/.hermes" "$HOME/.config/hermes" ];
      agentConfigDir = toString agentConfigDir;
    });
  };
}
