# dx.agents.bob — Bob Shell
# Migrated from: ghcr.io/docker-x/devcontainers/bob
# npm package: bob

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.agents.bob;
  agentConfigDir = config.dx.core.agentConfig.dir or "\${AGENT_CONFIG_DIR:-$HOME/.local/share/agent-config}";
in
{
  options.dx.agents.bob = helpers.mkAgentOptions {
    agentId = "bob";
    name = "Bob Shell";
  };

  config = lib.mkIf cfg.enable {
    dx.core.agentConfig.enable = lib.mkIf cfg.shareConfig true;

    packages = [
      (helpers.mkNpmCli {
        pname = "bob";
        npmName = "@roo-code/bob-shell";
        version = cfg.version;
        sha256 = lib.fakeHash;
      })
    ];

    enterShell = lib.optionalString cfg.shareConfig (helpers.shareConfigHook {
      agentId = "bob";
      configPaths = [ "$HOME/.bob" "$HOME/.config/bob" ];
      agentConfigDir = toString agentConfigDir;
    });
  };
}
