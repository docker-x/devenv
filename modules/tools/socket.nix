# dx.tools.socket — Socket CLI (socket.dev supply-chain security)
# Install method: npm package `socket` via the shared npx wrapper.
#
# The package ships five bins: `socket` plus `socket-npm`, `socket-npx`,
# `socket-pnpm`, `socket-yarn` — drop-in wrappers that scan packages on
# install (the CLI's main value is intercepting installs, not just scans
# on demand). All five are installed so callers can alias or invoke the
# manager shims directly.

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.tools.socket;

  # Extra entrypoint shims for the package-manager wrappers. Each runs
  # the named bin from the same pinned npm package via npx.
  pmShims = [ "socket-npm" "socket-npx" "socket-pnpm" "socket-yarn" ];
in
{
  options.dx.tools.socket = {
    enable = lib.mkEnableOption "Socket CLI";

    version = lib.mkOption {
      type = lib.types.str;
      # Pinned by default: a security scanner floating on "latest" can
      # change or weaken its install-time checks between invocations.
      # Bump deliberately after checking the upstream changelog.
      default = "1.2.1";
      description = ''
        Version of the socket npm package. An exact tag (the default)
        resolves once and is served from the npx cache afterwards;
        "latest" re-resolves on every invocation — nondeterministic for
        a security tool.
      '';
    };

    installShims = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Install socket-npm, socket-npx, socket-pnpm and socket-yarn —
        drop-in package-manager wrappers that scan dependencies during
        install. The wrappers exec the real npm/npx/pnpm/yarn from
        PATH, so the matching package manager must be available (e.g.
        languages.javascript.enable); they only gate installs when
        invoked directly or aliased (npm itself is not replaced).
        Disable for the bare `socket` command only.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    packages = [
      (helpers.mkNpmCli {
        pname = "socket";
        npmName = "socket";
        version = cfg.version;
        postInstall = lib.optionalString cfg.installShims (
          lib.concatMapStringsSep "\n" (shim: ''
            cat > $out/bin/${shim} << 'WRAPPER'
#!/bin/sh
# --prefer-offline: the shims wrap every package-manager call — serve the
# pinned tag from the npx cache instead of paying a registry round-trip
# per invocation (and breaking offline installs on a cold cache).
exec ${pkgs.nodejs}/bin/npx --yes --prefer-offline --package 'socket@${cfg.version}' ${shim} "$@"
WRAPPER
            chmod +x $out/bin/${shim}
          '') pmShims
        );
      })
    ];
  };
}
