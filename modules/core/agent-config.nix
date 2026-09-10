# dx.core.agent-config — shared agent configuration directory
#
# Migrated from: ghcr.io/docker-x/devcontainers/agent-config
#
# Creates a shared directory for AI agent configuration and exposes it as
# AGENT_CONFIG_DIR so multiple agent modules can store their configs in
# one place. This is the foundation that all agent modules build on.
#
# In devcontainers this was a build-time feature that created
# /usr/local/share/agent-config. In devenv the directory is created at
# shell-entry time under the user's home (or a custom path) so it works
# across all platforms without root.

{ lib, config, pkgs, ... }:

let
  cfg = config.dx.core.agentConfig;
in
{
  options.dx.core.agentConfig = {
    enable = lib.mkEnableOption "shared agent configuration directory (AGENT_CONFIG_DIR)";

    dir = lib.mkOption {
      type = lib.types.str;
      default = "$HOME/.local/share/agent-config";
      description = ''
        Path to the shared agent config directory. All agent modules with
        `shareConfig = true` will symlink their config into subdirectories
        of this path.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    env.AGENT_CONFIG_DIR = toString cfg.dir;

    enterShell = ''
      # dx.core.agent-config: ensure shared config directory exists
      mkdir -p "${toString cfg.dir}"
      chmod 755 "${toString cfg.dir}" 2>/dev/null || true
    '';
  };
}
