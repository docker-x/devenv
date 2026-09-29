# dx.agents.claude-code — Anthropic Claude Code CLI
#
# Migrated from: ghcr.io/docker-x/devcontainers/claude-code
#
# Delegates to devenv's native `claude.code` integration and extends it
# with the docker-x shareConfig pattern (AGENT_CONFIG_DIR symlinking).
#
# Native devenv features used:
#   - claude.code.enable          — the core Claude Code integration
#   - claude.code.hooks            — pre/post tool hooks
#   - claude.code.commands         — custom slash commands
#
# docker-x extensions:
#   - shareConfig                  — symlink ~/.claude to AGENT_CONFIG_DIR

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.agents.claudeCode;
  agentConfigDir = config.dx.core.agentConfig.dir or "\${AGENT_CONFIG_DIR:-$HOME/.local/share/agent-config}";
in
{
  options.dx.agents.claudeCode = {
    enable = lib.mkEnableOption "Claude Code CLI (delegates to native claude.code)";

    version = lib.mkOption {
      type = lib.types.str;
      default = "latest";
      description = ''
        Version of Claude Code to install. "latest" uses the bundled nixpkgs
        binary (offline, not necessarily the newest release); any other value
        is passed to npx as the npm specifier (e.g. "2.1.270" or a dist-tag
        like "next").
      '';
    };

    shareConfig = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "When true, symlink ~/.claude to the shared AGENT_CONFIG_DIR.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Delegate to native devenv Claude Code integration (settings, hooks,
    # commands). NOTE: native claude.code does NOT install the CLI — the
    # nixpkgs claude-code package provides the `claude` binary.
    claude.code.enable = true;
    # "latest" uses the nixpkgs binary (no runtime network needed); a pinned
    # version resolves through the mkNpmCli npx wrapper like other agents.
    packages = [
      (if cfg.version == "latest" then pkgs.claude-code else helpers.mkNpmCli {
        pname = "claude";
        npmName = "@anthropic-ai/claude-code";
        version = cfg.version;
      })
    ];

    # Ensure agent-config is enabled when shareConfig is on
    dx.core.agentConfig.enable = lib.mkIf cfg.shareConfig true;

    enterShell = lib.optionalString cfg.shareConfig (helpers.shareConfigHook {
      agentId = "claude-code";
      configPaths = [ "$HOME/.claude" ];
      agentConfigDir = toString agentConfigDir;
    });
  };
}
