# dx.agents.openclaw — OpenClaw
# Migrated from: ghcr.io/docker-x/devcontainers/openclaw
# npm package: openclaw

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.agents.openclaw;
  agentConfigDir = config.dx.core.agentConfig.dir or "\${AGENT_CONFIG_DIR:-$HOME/.local/share/agent-config}";
in
{
  options.dx.agents.openclaw = helpers.mkAgentOptions {
    agentId = "openclaw";
    name = "OpenClaw";
  };

  config = lib.mkIf cfg.enable {
    dx.core.agentConfig.enable = lib.mkIf cfg.shareConfig true;

    packages = [
      (helpers.mkNpmCli {
        pname = "openclaw";
        npmName = "openclaw";
        version = cfg.version;
        sha256 = lib.fakeHash;
      })
    ];

    enterShell = lib.optionalString cfg.shareConfig (helpers.shareConfigHook {
      agentId = "openclaw";
      configPaths = [ "$HOME/.openclaw" "$HOME/.config/openclaw" ];
      agentConfigDir = toString agentConfigDir;
    });
  };
}
