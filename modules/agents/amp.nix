# dx.agents.amp — Amp from Ampcode
# Migrated from: ghcr.io/docker-x/devcontainers/amp
# npm package: @ampcode/cli

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.agents.amp;
  agentConfigDir = config.dx.core.agentConfig.dir or "\${AGENT_CONFIG_DIR:-$HOME/.local/share/agent-config}";
in
{
  options.dx.agents.amp = helpers.mkAgentOptions {
    agentId = "amp";
    name = "Amp";
  };

  config = lib.mkIf cfg.enable {
    dx.core.agentConfig.enable = lib.mkIf cfg.shareConfig true;

    packages = [
      (helpers.mkNpmCli {
        pname = "amp";
        npmName = "@ampcode/cli";
        version = cfg.version;
        sha256 = lib.fakeHash;
      })
    ];

    enterShell = lib.optionalString cfg.shareConfig (helpers.shareConfigHook {
      agentId = "amp";
      configPaths = [ "$HOME/.amp" "$HOME/.config/amp" ];
      agentConfigDir = toString agentConfigDir;
    });
  };
}
