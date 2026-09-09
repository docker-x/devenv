# dx.agents.copilot — GitHub Copilot CLI
# Migrated from: ghcr.io/docker-x/devcontainers/copilot
# npm package: @github/copilot-cli (requires gh auth)

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.agents.copilot;
  agentConfigDir = config.dx.core.agentConfig.dir or "\${AGENT_CONFIG_DIR:-$HOME/.local/share/agent-config}";
in
{
  options.dx.agents.copilot = helpers.mkAgentOptions {
    agentId = "copilot";
    name = "GitHub Copilot CLI";
  };

  config = lib.mkIf cfg.enable {
    dx.core.agentConfig.enable = lib.mkIf cfg.shareConfig true;

    packages = [
      (helpers.mkNpmCli {
        pname = "copilot";
        npmName = "@github/copilot-cli";
        version = cfg.version;
        sha256 = lib.fakeHash;
      })
    ];

    enterShell = lib.optionalString cfg.shareConfig (helpers.shareConfigHook {
      agentId = "copilot";
      configPaths = [ "$HOME/.copilot" "$HOME/.config/copilot" ];
      agentConfigDir = toString agentConfigDir;
    });
  };
}
