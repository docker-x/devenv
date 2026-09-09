# dx.agents.herdr — Herdr
# Migrated from: ghcr.io/docker-x/devcontainers/herdr
# Install method: GitHub release binary

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.agents.herdr;
  agentConfigDir = config.dx.core.agentConfig.dir or "\${AGENT_CONFIG_DIR:-$HOME/.local/share/agent-config}";
in
{
  options.dx.agents.herdr = helpers.mkAgentOptions {
    agentId = "herdr";
    name = "Herdr";
  };

  config = lib.mkIf cfg.enable {
    dx.core.agentConfig.enable = lib.mkIf cfg.shareConfig true;

    packages = [
      (helpers.mkGithubBinary {
        pname = "herdr";
        version = if cfg.version == "latest" then "latest" else cfg.version;
        owner = "herdr";
        repo = "herdr";
        asset = "herdr-linux-amd64";
        sha256 = lib.fakeHash;
      })
    ];

    enterShell = lib.optionalString cfg.shareConfig (helpers.shareConfigHook {
      agentId = "herdr";
      configPaths = [ "$HOME/.herdr" "$HOME/.config/herdr" ];
      agentConfigDir = toString agentConfigDir;
    });
  };
}
