# dx.agents.pi — Pi coding agent (earendil-works/pi)
# Install method: npm (@earendil-works/pi-coding-agent)
# Requires Node.js 22.19+ at runtime (the npx wrapper resolves through the
# ambient node — pkgs.nodejs in the consumer's packages list).

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.agents.pi;
  agentConfigDir = config.dx.core.agentConfig.dir or "\${AGENT_CONFIG_DIR:-$HOME/.local/share/agent-config}";
in
{
  options.dx.agents.pi = helpers.mkAgentOptions {
    agentId = "pi";
    name = "Pi";
  };

  config = lib.mkIf cfg.enable {
    dx.core.agentConfig.enable = lib.mkIf cfg.shareConfig true;

    packages = [
      (helpers.mkNpmCli {
        pname = "pi";
        npmName = "@earendil-works/pi-coding-agent";
        version = cfg.version;
      })
    ];

    enterShell = lib.optionalString cfg.shareConfig (helpers.shareConfigHook {
      agentId = "pi";
      configPaths = [ "$HOME/.pi" ];
      agentConfigDir = toString agentConfigDir;
    });
  };
}
