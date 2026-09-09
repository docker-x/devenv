# dx.agents.codex — OpenAI Codex CLI
# Migrated from: ghcr.io/docker-x/devcontainers/codex
# npm package: @openai/codex

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.agents.codex;
  agentConfigDir = config.dx.core.agentConfig.dir or "\${AGENT_CONFIG_DIR:-$HOME/.local/share/agent-config}";
in
{
  options.dx.agents.codex = helpers.mkAgentOptions {
    agentId = "codex";
    name = "OpenAI Codex CLI";
  };

  config = lib.mkIf cfg.enable {
    dx.core.agentConfig.enable = lib.mkIf cfg.shareConfig true;

    packages = [
      (helpers.mkNpmCli {
        pname = "codex";
        npmName = "@openai/codex";
        version = cfg.version;
        sha256 = lib.fakeHash;
      })
    ];

    enterShell = lib.optionalString cfg.shareConfig (helpers.shareConfigHook {
      agentId = "codex";
      configPaths = [ "$HOME/.codex" "$HOME/.config/codex" ];
      agentConfigDir = toString agentConfigDir;
    });
  };
}
