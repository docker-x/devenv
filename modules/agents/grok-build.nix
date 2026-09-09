# dx.agents.grok-build — Grok Build from xAI
# Migrated from: ghcr.io/docker-x/devcontainers/grok-build
# Install method: upstream install script (https://x.ai/cli/install.sh)

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.agents.grokBuild;
  agentConfigDir = config.dx.core.agentConfig.dir or "\${AGENT_CONFIG_DIR:-$HOME/.local/share/agent-config}";
in
{
  options.dx.agents.grokBuild = helpers.mkAgentOptions {
    agentId = "grok-build";
    name = "Grok Build";
  };

  config = lib.mkIf cfg.enable {
    dx.core.agentConfig.enable = lib.mkIf cfg.shareConfig true;

    enterShell = ''
      # dx.agents.grok-build: install via upstream installer
      if ! command -v grok-build &>/dev/null; then
        echo "dx.agents.grok-build: running upstream installer..."
        curl --proto =https -fsSL https://x.ai/cli/install.sh | bash || true
      fi
      ${lib.optionalString cfg.shareConfig (helpers.shareConfigHook {
        agentId = "grok-build";
        configPaths = [ "$HOME/.grok-build" "$HOME/.config/grok-build" ];
        agentConfigDir = toString agentConfigDir;
      })}
    '';
  };
}
