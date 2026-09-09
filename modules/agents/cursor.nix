# dx.agents.cursor — Cursor Agent CLI
# Migrated from: ghcr.io/docker-x/devcontainers/cursor
# Install method: upstream curl|bash installer (https://cursor.com/install)

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.agents.cursor;
  agentConfigDir = config.dx.core.agentConfig.dir or "\${AGENT_CONFIG_DIR:-$HOME/.local/share/agent-config}";
in
{
  options.dx.agents.cursor = {
    enable = lib.mkEnableOption "Cursor Agent CLI";
    shareConfig = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "When true, symlink ~/.cursor to the shared AGENT_CONFIG_DIR.";
    };
  };

  config = lib.mkIf cfg.enable {
    dx.core.agentConfig.enable = lib.mkIf cfg.shareConfig true;

    enterShell = ''
      # dx.agents.cursor: install via upstream installer
      if ! command -v cursor-agent &>/dev/null; then
        echo "dx.agents.cursor: running upstream installer..."
        NO_COLOR=1 /bin/bash -c "$(curl --proto =https -fsSL https://cursor.com/install)" || true
      fi
      ${lib.optionalString cfg.shareConfig (helpers.shareConfigHook {
        agentId = "cursor";
        configPaths = [ "$HOME/.cursor" "$HOME/.config/cursor" ];
        agentConfigDir = toString agentConfigDir;
      })}
    '';
  };
}
