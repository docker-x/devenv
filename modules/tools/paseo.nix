# dx.tools.paseo — Paseo CLI
# Migrated from: ghcr.io/docker-x/devcontainers/paseo
# Local-first AI development environment with daemon, web UI, and agent orchestration.
# npm package: @getpaseo/cli

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.tools.paseo;
in
{
  options.dx.tools.paseo = {
    enable = lib.mkEnableOption "Paseo CLI";

    version = lib.mkOption {
      type = lib.types.str;
      default = "latest";
      description = "Version of Paseo CLI to install.";
    };

    enableRelay = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Paseo relay for remote connections (app.paseo.sh).";
    };

    enableWebUi = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Serve the bundled web UI from the daemon.";
    };
  };

  config = lib.mkIf cfg.enable {
    packages = [
      (helpers.mkNpmCli {
        pname = "paseo";
        npmName = "@getpaseo/cli";
        version = cfg.version;
        sha256 = lib.fakeHash;
      })
    ];

    enterShell = ''
      # dx.tools.paseo: ensure .paseo directory exists
      mkdir -p "$HOME/.paseo"

      # dx.tools.paseo: generate config.json if it doesn't exist
      # The config enables relay, MCP injection, terminal agent hooks,
      # and configures the Devin agent provider via ACP.
      PASEO_CONFIG="$HOME/.paseo/config.json"
      if [ ! -f "$PASEO_CONFIG" ]; then
        cat > "$PASEO_CONFIG" << 'PASEOEOF'
{
  "version": 1,
  "daemon": {
    "listen": "127.0.0.1:6767",
    "mcp": {
      "injectIntoAgents": true
    },
    "browserTools": {
      "enabled": true
    },
    "enableTerminalAgentHooks": true,
    "appendSystemPrompt": "Use worktrees for parallel work\nAlways reply with refs (PRs, commits) instead of raw text\nUtilize own paseo capabilities\nAlways pull before starting new branch",
    "cors": {
      "allowedOrigins": [
        "https://app.paseo.sh"
      ]
    },
    "relay": {
      "enabled": true
    }
  },
  "app": {
    "baseUrl": "https://app.paseo.sh"
  },
  "pluginsEnabled": true,
  "plugins": {},
  "agents": {
    "providers": {
      "devin": {
        "extends": "acp",
        "label": "Devin CLI",
        "description": "Cognition's Devin for Terminal via Agent Client Protocol",
        "command": ["devin", "acp"],
        "env": {}
      },
      "pi": { "enabled": false },
      "opencode": { "enabled": false },
      "copilot": { "enabled": false },
      "codex": { "enabled": false },
      "claude": { "enabled": false }
    },
    "skills": {
      "selection": { "mode": "all" }
    }
  },
  "features": {
    "dictation": { "enabled": false },
    "voiceMode": { "enabled": false }
  }
}
PASEOEOF
        chmod 600 "$PASEO_CONFIG"
      fi

      # dx.tools.paseo: create workspace directory for projects
      mkdir -p "$HOME/workspace"
    '';
  };
}
