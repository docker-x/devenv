# dx.agents.qwen-code — Qwen Code from Alibaba
# Migrated from: ghcr.io/docker-x/devcontainers/qwen-code
# npm package: qwen-code

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.agents.qwenCode;
  agentConfigDir = config.dx.core.agentConfig.dir or "\${AGENT_CONFIG_DIR:-$HOME/.local/share/agent-config}";
in
{
  options.dx.agents.qwenCode = helpers.mkAgentOptions {
    agentId = "qwen-code";
    name = "Qwen Code";
  };

  config = lib.mkIf cfg.enable {
    dx.core.agentConfig.enable = lib.mkIf cfg.shareConfig true;

    packages = [
      (helpers.mkNpmCli {
        pname = "qwen-code";
        npmName = "qwen-code";
        version = cfg.version;
        sha256 = lib.fakeHash;
      })
    ];

    enterShell = lib.optionalString cfg.shareConfig (helpers.shareConfigHook {
      agentId = "qwen-code";
      configPaths = [ "$HOME/.qwen-code" "$HOME/.config/qwen-code" ];
      agentConfigDir = toString agentConfigDir;
    });
  };
}
