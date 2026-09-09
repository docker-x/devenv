# dx.runtimes.bun — Bun JavaScript runtime
#
# Migrated from: ghcr.io/docker-x/devcontainers/bun
#
# Delegates to devenv's native `languages.javascript.bun` and extends
# with the docker-x shareConfig pattern (AGENT_CONFIG_DIR symlinking).
#
# Native devenv features used:
#   - languages.javascript.enable
#   - languages.javascript.bun.enable
#   - languages.javascript.bun.package
#
# docker-x extensions:
#   - shareConfig — symlink ~/.bun config to AGENT_CONFIG_DIR

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.runtimes.bun;
  agentConfigDir = config.dx.core.agentConfig.dir or "\${AGENT_CONFIG_DIR:-$HOME/.local/share/agent-config}";
in
{
  options.dx.runtimes.bun = {
    enable = lib.mkEnableOption "Bun JavaScript runtime (delegates to native languages.javascript.bun)";

    version = lib.mkOption {
      type = lib.types.str;
      default = "latest";
      description = "Version of Bun to install (e.g. 'latest' or a specific version).";
    };

    shareConfig = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "When true, symlink ~/.bun config to the shared AGENT_CONFIG_DIR.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Delegate to native devenv Bun support
    languages.javascript.enable = true;
    languages.javascript.bun.enable = true;

    # Use specific version if not 'latest'
    languages.javascript.bun.package = lib.mkIf (cfg.version != "latest")
      (pkgs.bun.overrideAttrs (_: { version = cfg.version; }));

    dx.core.agentConfig.enable = lib.mkIf cfg.shareConfig true;

    enterShell = lib.optionalString cfg.shareConfig (helpers.shareConfigHook {
      agentId = "bun";
      configPaths = [ "$HOME/.bun" "$HOME/.config/bun" ];
      agentConfigDir = toString agentConfigDir;
    });
  };
}
