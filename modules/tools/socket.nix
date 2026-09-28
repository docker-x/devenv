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
      default = "latest";
      description = ''
        Version of the socket npm package. "latest" resolves the newest
        release on every invocation; pin an exact version (e.g. "1.2.1")
        for deterministic behavior — the npx wrapper then fetches that
        tag once and serves it from the npx cache afterwards.
      '';
    };

    installShims = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Install socket-npm, socket-npx, socket-pnpm and socket-yarn —
        drop-in package-manager wrappers that scan dependencies during
        install. Disable for the bare `socket` command only.
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
exec ${pkgs.nodejs}/bin/npx --yes --package 'socket@${cfg.version}' ${shim} "$@"
WRAPPER
            chmod +x $out/bin/${shim}
          '') pmShims
        );
      })
    ];
  };
}
