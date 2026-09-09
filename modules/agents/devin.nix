# dx.agents.devin — Devin CLI
#
# Migrated from: ghcr.io/docker-x/devcontainers/devin
#
# Install Devin CLI for AI-powered development and optionally share its
# config folder with other agents via AGENT_CONFIG_DIR.
#
# The devcontainer feature supported two install methods (script, binary).
# In devenv we use the binary manifest from static.devin.ai for reproducible
# builds. The `script` method is kept as a fallback for development.

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.agents.devin;
  agentConfigDir = config.dx.core.agentConfig.dir or "\${AGENT_CONFIG_DIR:-$HOME/.local/share/agent-config}";
in
{
  options.dx.agents.devin = helpers.mkAgentOptions {
    agentId = "devin";
    name = "Devin CLI";
    extraOptions = {
      installMethod = lib.mkOption {
        type = lib.types.enum [ "script" "binary" ];
        default = "binary";
        description = "Install Devin via the official install script or a direct binary tarball.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Ensure agent-config is enabled when shareConfig is on
    dx.core.agentConfig.enable = lib.mkIf cfg.shareConfig true;

    packages = lib.optionals (cfg.installMethod == "binary") [
      (helpers.mkGithubBinary {
        pname = "devin";
        version = if cfg.version == "latest" then "current" else cfg.version;
        owner = "cognition-ai";
        repo = "devin";
        asset = "devin-linux-amd64";
        sha256 = lib.fakeHash;
      })
    ];

    enterShell = ''
      # dx.agents.devin: install/verify
      ${lib.optionalString (cfg.installMethod == "script") ''
        if ! command -v devin &>/dev/null; then
          echo "dx.agents.devin: running upstream install script..."
          curl --proto =https -fsSL https://cli.devin.ai/install.sh | bash || true
        fi
      ''}
      ${lib.optionalString cfg.shareConfig (helpers.shareConfigHook {
        agentId = "devin";
        configPaths = [ "$HOME/.devin" "$HOME/.config/devin" ];
        agentConfigDir = toString agentConfigDir;
      })}
      if command -v devin &>/dev/null; then
        echo "dx.agents.devin: $(devin --version 2>&1 || echo 'installed')"
      fi
    '';
  };
}
