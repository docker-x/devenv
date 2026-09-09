# dx.agents.crush — Crush CLI from Charm
# Migrated from: ghcr.io/docker-x/devcontainers/crush
# npm package: crush

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.agents.crush;
  agentConfigDir = config.dx.core.agentConfig.dir or "\${AGENT_CONFIG_DIR:-$HOME/.local/share/agent-config}";
in
{
  options.dx.agents.crush = helpers.mkAgentOptions {
    agentId = "crush";
    name = "Crush CLI";
  };

  config = lib.mkIf cfg.enable {
    dx.core.agentConfig.enable = lib.mkIf cfg.shareConfig true;

    packages = [
      (helpers.mkNpmCli {
        pname = "crush";
        npmName = "crush";
        version = cfg.version;
        sha256 = lib.fakeHash;
      })
    ];

    enterShell = lib.optionalString cfg.shareConfig (helpers.shareConfigHook {
      agentId = "crush";
      configPaths = [ "$HOME/.crush" "$HOME/.config/crush" ];
      agentConfigDir = toString agentConfigDir;
    });
  };
}
