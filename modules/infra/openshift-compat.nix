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

    env.HOME = lib.mkForce "$HOME";

    processes.sshd.exec = ''
      # Generate host keys in a writable location (OpenShift restricted SCC
      # prevents writing to /etc/ssh). Use HOME (PVC-backed) so keys persist.
      SSH_KEY_DIR="''${HOME:-/tmp}/.ssh-host-keys"
      mkdir -p "$SSH_KEY_DIR"
      if [[ ! -f "$SSH_KEY_DIR/ssh_host_ed25519_key" ]]; then
        ssh-keygen -t ed25519 -f "$SSH_KEY_DIR/ssh_host_ed25519_key" -N "" 2>/dev/null || true
      fi
      # Start sshd on the configured port with the generated host key
      sshd -p ${toString cfg.sshPort} -D \
        -o "HostKey=$SSH_KEY_DIR/ssh_host_ed25519_key" \
        -o "PidFile=$SSH_KEY_DIR/sshd.pid" \
        -o "StrictModes=no"
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
