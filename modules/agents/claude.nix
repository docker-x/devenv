# dx.agents.claude — Anthropic Claude SDK
# Migrated from: ghcr.io/docker-x/devcontainers/claude
# Config-only: configures the Anthropic Claude SDK and shares config.

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.agents.claude;
  agentConfigDir = config.dx.core.agentConfig.dir or "\${AGENT_CONFIG_DIR:-$HOME/.local/share/agent-config}";
in
{
  options.dx.agents.claude = {
    enable = lib.mkEnableOption "Anthropic Claude SDK configuration";
    shareConfig = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "When true, symlink ~/.anthropic to the shared AGENT_CONFIG_DIR.";
    };
  };

  config = lib.mkIf cfg.enable {
    dx.core.agentConfig.enable = lib.mkIf cfg.shareConfig true;

    env.ANTHROPIC_API_KEY = lib.mkDefault "";

    enterShell = lib.optionalString cfg.shareConfig (helpers.shareConfigHook {
      agentId = "claude";
      configPaths = [ "$HOME/.anthropic" "$HOME/.config/anthropic" ];
      agentConfigDir = toString agentConfigDir;
    });
  };
}
