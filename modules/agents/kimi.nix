# dx.agents.kimi — Kimi Code from Moonshot AI
# Migrated from: ghcr.io/docker-x/devcontainers/kimi
# npm package: @kimi-ai/kimi-code

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.agents.kimi;
  agentConfigDir = config.dx.core.agentConfig.dir or "\${AGENT_CONFIG_DIR:-$HOME/.local/share/agent-config}";
in
{
  options.dx.agents.kimi = helpers.mkAgentOptions {
    agentId = "kimi";
    name = "Kimi Code";
  };

  config = lib.mkIf cfg.enable {
    dx.core.agentConfig.enable = lib.mkIf cfg.shareConfig true;

    packages = [
      (helpers.mkNpmCli {
        pname = "kimi";
        npmName = "@kimi-ai/kimi-code";
        version = cfg.version;
        sha256 = lib.fakeHash;
      })
    ];

    enterShell = lib.optionalString cfg.shareConfig (helpers.shareConfigHook {
      agentId = "kimi";
      configPaths = [ "$HOME/.kimi" "$HOME/.config/kimi" ];
      agentConfigDir = toString agentConfigDir;
    });
  };
}
