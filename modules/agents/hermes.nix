# dx.agents.hermes — Hermes Agent from Nous Research
# Migrated from: ghcr.io/docker-x/devcontainers/hermes
# Install method: upstream install script (https://hermes-agent.nousresearch.com/install.sh)

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

    enterShell = ''
      # dx.agents.hermes: install via upstream installer
      if ! command -v hermes &>/dev/null; then
        echo "dx.agents.hermes: running upstream installer..."
        curl --proto =https -fsSL https://hermes-agent.nousresearch.com/install.sh | bash || true
      fi
      ${lib.optionalString cfg.shareConfig (helpers.shareConfigHook {
        agentId = "hermes";
        configPaths = [ "$HOME/.hermes" "$HOME/.config/hermes" ];
        agentConfigDir = toString agentConfigDir;
      })}
    '';
  };
}
