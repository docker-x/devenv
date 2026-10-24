# dx.agents.auggie — Auggie CLI (Augment Code)
# npm package: @augmentcode/auggie

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.agents.auggie;
  agentConfigDir = config.dx.core.agentConfig.dir or "\${AGENT_CONFIG_DIR:-$HOME/.local/share/agent-config}";
in
{
  options.dx.agents.auggie = helpers.mkAgentOptions {
    agentId = "auggie";
    name = "Auggie";
  };

  config = lib.mkIf cfg.enable {
    dx.core.agentConfig.enable = lib.mkIf cfg.shareConfig true;

    packages = [
      (helpers.mkNpmCli {
        pname = "auggie";
        npmName = "@augmentcode/auggie";
        version = cfg.version;
        sha256 = lib.fakeHash;
      })
    ];

    enterShell = lib.optionalString cfg.shareConfig (helpers.shareConfigHook {
      agentId = "auggie";
      configPaths = [ "$HOME/.augment" "$HOME/.config/augment" ];
      agentConfigDir = toString agentConfigDir;
    });
  };
}
