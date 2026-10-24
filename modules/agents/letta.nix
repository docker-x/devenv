# dx.agents.letta — Letta Code CLI (stateful Letta agents from the terminal)
# npm package: @letta-ai/letta-code

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.agents.letta;
  agentConfigDir = config.dx.core.agentConfig.dir or "\${AGENT_CONFIG_DIR:-$HOME/.local/share/agent-config}";
in
{
  options.dx.agents.letta = helpers.mkAgentOptions {
    agentId = "letta";
    name = "Letta Code";
  };

  config = lib.mkIf cfg.enable {
    dx.core.agentConfig.enable = lib.mkIf cfg.shareConfig true;

    packages = [
      (helpers.mkNpmCli {
        pname = "letta";
        npmName = "@letta-ai/letta-code";
        version = cfg.version;
        sha256 = lib.fakeHash;
      })
    ];

    enterShell = lib.optionalString cfg.shareConfig (helpers.shareConfigHook {
      agentId = "letta";
      configPaths = [ "$HOME/.letta" "$HOME/.config/letta" ];
      agentConfigDir = toString agentConfigDir;
    });
  };
}
