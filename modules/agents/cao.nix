# dx.agents.cao — CLI Agent Orchestrator (CAO) from AWS Labs
# Migrated from: ghcr.io/docker-x/devcontainers/cao
# Install method: uv tool install from awslabs/cli-agent-orchestrator
# Multi-agent orchestration for AI coding CLIs coordinated in tmux sessions.

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.agents.cao;
  agentConfigDir = config.dx.core.agentConfig.dir or "\${AGENT_CONFIG_DIR:-$HOME/.local/share/agent-config}";
in
{
  options.dx.agents.cao = {
    enable = lib.mkEnableOption "CLI Agent Orchestrator (CAO)";

    version = lib.mkOption {
      type = lib.types.str;
      default = "latest";
      description = "Git ref to install from (e.g. 'latest' or a commit/tag).";
    };

    shareConfig = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "When true, symlink ~/.cao to the shared AGENT_CONFIG_DIR.";
    };
  };

  config = lib.mkIf cfg.enable {
    dx.core.agentConfig.enable = lib.mkIf cfg.shareConfig true;

    packages = [ pkgs.tmux pkgs.uv ];

    enterShell = ''
      # dx.agents.cao: install via uv tool
      if ! command -v cao &>/dev/null; then
        echo "dx.agents.cao: installing via uv..."
        _cao_ref="${if cfg.version == "latest" then "" else "@${cfg.version}"}"
        uv tool install "git+https://github.com/awslabs/cli-agent-orchestrator.git''${_cao_ref}" --force
      fi
      ${lib.optionalString cfg.shareConfig (helpers.shareConfigHook {
        agentId = "cao";
        configPaths = [ "$HOME/.cao" ];
        agentConfigDir = toString agentConfigDir;
      })}
    '';
  };
}
