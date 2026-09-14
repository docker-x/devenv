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
      pkgs.nss_wrapper
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
      # Wire the mounted authorized_keys secret into place. The cdk8s chart
      # mounts it read-only at /ssh-keys/; sshd reads $HOME/.ssh/authorized_keys.
      # Symlink (not copy) so secret rotation propagates without a restart.
      if [[ -f /ssh-keys/authorized_keys ]]; then
        mkdir -p "$HOME/.ssh" \
          && ln -sfn /ssh-keys/authorized_keys "$HOME/.ssh/authorized_keys" \
          || { echo "sshd: failed to link authorized_keys into $HOME/.ssh" >&2; exit 1; }
      fi
      # Map the login user ('user') to the runtime UID/GID. OpenShift SCC
      # assigns a random UID, and a non-root sshd can only serve logins for
      # the UID it runs as — without the remap, `ssh user@` targets uid 1000
      # and fails setuid. /etc/passwd is a read-only CRI-O bind-mount, so use
      # nss_wrapper (LD_PRELOAD) with a rewritten copy — also fixes the
      # SCC-injected nologin shell on the runtime-UID entry.
      RUNTIME_UID=$(id -u); RUNTIME_GID=$(id -g)
      NSS_PASSWD=$(mktemp); NSS_GROUP=$(mktemp)
      SHELL_BIN="${pkgs.bashInteractive}/bin/bash"
      awk -F: -v uid="$RUNTIME_UID" -v gid="$RUNTIME_GID" -v sh="$SHELL_BIN" -v home="$HOME" '
        BEGIN { OFS=":" }
        $1 == "user"          { $3 = uid; $4 = gid; $6 = home; $7 = sh }
        $3 == uid && $7 ~ /nologin/ { $7 = sh }
        { print }
      ' /etc/passwd > "$NSS_PASSWD"
      awk -F: -v gid="$RUNTIME_GID" '
        BEGIN { OFS=":" }
        $1 == "user" { $3 = gid }
        { print }
      ' /etc/group > "$NSS_GROUP"
      export NSS_WRAPPER_PASSWD="$NSS_PASSWD" NSS_WRAPPER_GROUP="$NSS_GROUP"
      export LD_PRELOAD="${pkgs.nss_wrapper}/lib/libnss_wrapper.so''${LD_PRELOAD:+:$LD_PRELOAD}"
      # Generate host keys in a writable location (OpenShift restricted SCC
      # prevents writing to /etc/ssh). Use HOME (PVC-backed) so keys persist.
      # Group-writable dir (770): fsGroup shares the PVC across random UIDs —
      # a chmod-700 dir owned by a previous pod UID would break sshd on
      # restart. If the dir isn't writable by us, fall back to an ephemeral
      # mktemp dir (host key rotates) rather than crash.
      SSH_KEY_DIR="$HOME/.ssh-host-keys"
      mkdir -p "$SSH_KEY_DIR" 2>/dev/null || true
      if [[ ! -d "$SSH_KEY_DIR" || ! -w "$SSH_KEY_DIR" ]]; then
        echo "sshd: $SSH_KEY_DIR not writable (prior pod UID owns it) — using ephemeral key dir" >&2
        SSH_KEY_DIR=$(mktemp -d)
      fi
      chmod 770 "$SSH_KEY_DIR" 2>/dev/null || true
      SSH_KEY="$SSH_KEY_DIR/ssh_host_ed25519_key"
      # OpenSSH requires private keys be owner-only (& 0077 == 0) regardless
      # of StrictModes — a group-readable key is rejected on load. A key left
      # by a previous pod UID can't be chmod'd by us — the group-writable dir
      # lets us remove and regenerate it instead. Symlinks are rejected first:
      # the dir is group-writable, so a peer pod could point this path at an
      # unrelated file and trick us into chmod'ing it.
      if [[ -L "$SSH_KEY" ]]; then
        echo "sshd: $SSH_KEY is a symlink — regenerating" >&2
        rm -f "$SSH_KEY" "$SSH_KEY.pub"
      elif [[ -f "$SSH_KEY" ]] && ! chmod 600 "$SSH_KEY" 2>/dev/null; then
        echo "sshd: $SSH_KEY owned by another UID — regenerating" >&2
        rm -f "$SSH_KEY" "$SSH_KEY.pub"
      fi
      # A readable non-regular object (dir, fifo, dangling symlink) at the
      # key path must not bypass regeneration — sshd would fail to load it.
      if [[ ! -f "$SSH_KEY" || ! -r "$SSH_KEY" ]]; then
        rm -rf "$SSH_KEY"; rm -f "$SSH_KEY.pub"
        if ! ssh-keygen -t ed25519 -f "$SSH_KEY" -N ""; then
          echo "sshd: failed to generate host key in $SSH_KEY_DIR" >&2
          exit 1
        fi
        chmod 600 "$SSH_KEY"
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
