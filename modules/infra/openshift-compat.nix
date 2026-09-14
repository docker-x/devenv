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

    # Do not override HOME — let the container runtime / cdk8s construct
    # set it (e.g. /env for OpenShift PVC-backed workspaces).
    # env.HOME was previously set to "$HOME" (literal), which broke
    # every path that relied on $HOME expansion.

    processes.sshd.exec = ''
      # HOME must be a real writable directory. OpenShift restricted SCC can
      # set HOME=/ for random-UID containers — fail fast rather than falling
      # back to world-readable /tmp (docker-x/devenv#6).
      if [[ -z "''${HOME:-}" || "$HOME" == "/" || ! -d "$HOME" || ! -w "$HOME" ]]; then
        echo "sshd: HOME='$HOME' is unset, '/', or not writable — refusing to start (host keys need a persistent writable dir)" >&2
        exit 1
      fi
      # Generate host keys in a writable location (OpenShift restricted SCC
      # prevents writing to /etc/ssh). Use HOME (PVC-backed) so keys persist.
      SSH_KEY_DIR="$HOME/.ssh-host-keys"
      mkdir -p "$SSH_KEY_DIR"
      chmod 700 "$SSH_KEY_DIR"
      if [[ ! -f "$SSH_KEY_DIR/ssh_host_ed25519_key" ]]; then
        ssh-keygen -t ed25519 -f "$SSH_KEY_DIR/ssh_host_ed25519_key" -N "" 2>/dev/null || true
        chmod 600 "$SSH_KEY_DIR/ssh_host_ed25519_key"
      fi
      # Minimal sshd_config — /etc/ssh/sshd_config doesn't exist in the container.
      # StrictModes stays off: it rejects group-writable homes, and the
      # PVC-backed HOME must be group-writable (fsGroup) for random-UID
      # access. There is no per-file scoping — OpenSSH checks the whole
      # authorized_keys path chain. Compensated by PasswordAuthentication no
      # (pubkey-only) and PermitRootLogin no.
      SSHD_CFG="$SSH_KEY_DIR/sshd_config"
      cat > "$SSHD_CFG" <<'SSHDCFG'
      Port 2222
      HostKey dummy
      PidFile dummy
      StrictModes no
      UsePAM no
      PasswordAuthentication no
      PubkeyAuthentication yes
      AuthorizedKeysFile .ssh/authorized_keys
      PermitRootLogin no
      X11Forwarding no
      PrintMotd no
      AcceptEnv LANG LC_*
      Subsystem sftp internal-sftp
SSHDCFG
      # Start sshd with absolute path (sshd refuses to run without it).
      SSHD_BIN="${pkgs.openssh}/bin/sshd"
      "$SSHD_BIN" -f "$SSHD_CFG" -p ${toString cfg.sshPort} -D \
        -o "HostKey=$SSH_KEY_DIR/ssh_host_ed25519_key" \
        -o "PidFile=$SSH_KEY_DIR/sshd.pid"
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
