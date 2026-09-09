# dx.agents.goose — Goose CLI from Block
# Migrated from: ghcr.io/docker-x/devcontainers/goose
# Install method: upstream installer / binary release

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

    enterShell = ''
      # dx.agents.goose: install via upstream installer
      if ! command -v goose &>/dev/null; then
        echo "dx.agents.goose: running upstream installer..."
        curl --proto =https -fsSL https://github.com/block/goose/releases/download/stable/download.sh | bash || true
      fi
      ${lib.optionalString cfg.shareConfig (helpers.shareConfigHook {
        agentId = "goose";
        configPaths = [ "$HOME/.goose" "$HOME/.config/goose" ];
        agentConfigDir = toString agentConfigDir;
      })}
    '';
  };
}
