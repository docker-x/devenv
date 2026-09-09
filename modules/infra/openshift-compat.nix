# dx.infra.openshift-compat — OpenShift compatibility
# Migrated from: ghcr.io/docker-x/devcontainers/openshift-compat
# Makes the environment compatible with OpenShift restricted SCC:
#   - SSH server on configurable port
#   - Random UID support
#   - Fake sudo wrapper
#   - Group-writable home
#
# In devenv, most of this is handled natively (no root needed). This module
# provides the SSH server and entrypoint hooks for OpenShift deployments.

{ lib, config, pkgs, ... }:

let
  cfg = config.dx.infra.openshiftCompat;
in
{
  options.dx.infra.openshiftCompat = {
    enable = lib.mkEnableOption "OpenShift restricted SCC compatibility";

    sshPort = lib.mkOption {
      type = lib.types.port;
      default = 2222;
      description = "Port for the SSH server.";
    };
  };

  config = lib.mkIf cfg.enable {
    packages = [
      pkgs.openssh
      pkgs.shadow
    ];

    env.HOME = lib.mkForce (config.env.HOME or "$HOME");

    processes.sshd.exec = ''
      # Generate host keys if missing
      if [[ ! -d /etc/ssh ]]; then
        mkdir -p /etc/ssh
        ssh-keygen -A 2>/dev/null || true
      fi
      # Start sshd on the configured port
      sshd -p ${toString cfg.sshPort} -D
    '';

    enterShell = ''
      # dx.infra.openshift-compat: ensure home is group-writable
      if [[ -d "$HOME" ]]; then
        chmod g+rwx "$HOME" 2>/dev/null || true
      fi
      # Ensure /etc/passwd is group-writable for runtime UID fix
      if [[ -w /etc/passwd ]]; then
        chmod g+w /etc/passwd 2>/dev/null || true
      fi
    '';
  };
}
