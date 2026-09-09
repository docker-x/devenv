# dx.agents.gemini — Google Gemini CLI
# Migrated from: ghcr.io/docker-x/devcontainers/gemini
# npm package: @google/gemini-cli

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.agents.gemini;
  agentConfigDir = config.dx.core.agentConfig.dir or "\${AGENT_CONFIG_DIR:-$HOME/.local/share/agent-config}";
in
{
  options.dx.agents.gemini = helpers.mkAgentOptions {
    agentId = "gemini";
    name = "Gemini CLI";
  };

  config = lib.mkIf cfg.enable {
    dx.core.agentConfig.enable = lib.mkIf cfg.shareConfig true;

    packages = [
      (helpers.mkNpmCli {
        pname = "gemini";
        npmName = "@google/gemini-cli";
        version = cfg.version;
        sha256 = lib.fakeHash;
      })
    ];

    enterShell = lib.optionalString cfg.shareConfig (helpers.shareConfigHook {
      agentId = "gemini";
      configPaths = [ "$HOME/.gemini" "$HOME/.config/gemini" ];
      agentConfigDir = toString agentConfigDir;
    });
  };
}
