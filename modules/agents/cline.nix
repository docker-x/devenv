# dx.agents.cline — Cline CLI
# Migrated from: ghcr.io/docker-x/devcontainers/cline
# npm package: cline

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.agents.cline;
  agentConfigDir = config.dx.core.agentConfig.dir or "\${AGENT_CONFIG_DIR:-$HOME/.local/share/agent-config}";
in
{
  options.dx.agents.cline = helpers.mkAgentOptions {
    agentId = "cline";
    name = "Cline CLI";
  };

  config = lib.mkIf cfg.enable {
    dx.core.agentConfig.enable = lib.mkIf cfg.shareConfig true;

    packages = [
      (helpers.mkNpmCli {
        pname = "cline";
        npmName = "cline";
        version = cfg.version;
        sha256 = lib.fakeHash;
      })
    ];

    enterShell = lib.optionalString cfg.shareConfig (helpers.shareConfigHook {
      agentId = "cline";
      configPaths = [ "$HOME/.cline" "$HOME/.config/cline" ];
      agentConfigDir = toString agentConfigDir;
    });
  };
}
