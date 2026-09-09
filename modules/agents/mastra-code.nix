# dx.agents.mastra-code — Mastra Code
# Migrated from: ghcr.io/docker-x/devcontainers/mastra-code
# npm package: mastracode

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.agents.mastraCode;
  agentConfigDir = config.dx.core.agentConfig.dir or "\${AGENT_CONFIG_DIR:-$HOME/.local/share/agent-config}";
in
{
  options.dx.agents.mastraCode = helpers.mkAgentOptions {
    agentId = "mastra-code";
    name = "Mastra Code";
  };

  config = lib.mkIf cfg.enable {
    dx.core.agentConfig.enable = lib.mkIf cfg.shareConfig true;

    packages = [
      (helpers.mkNpmCli {
        pname = "mastra-code";
        npmName = "mastracode";
        version = cfg.version;
        sha256 = lib.fakeHash;
      })
    ];

    enterShell = lib.optionalString cfg.shareConfig (helpers.shareConfigHook {
      agentId = "mastra-code";
      configPaths = [ "$HOME/.mastra-code" "$HOME/.config/mastra-code" ];
      agentConfigDir = toString agentConfigDir;
    });
  };
}
