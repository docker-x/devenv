# dx.tools.paseo — Paseo CLI
# Migrated from: ghcr.io/docker-x/devcontainers/paseo
# Local-first AI development environment with daemon, web UI, and agent orchestration.
# npm package: @getpaseo/cli

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.tools.paseo;
in
{
  options.dx.tools.paseo = {
    enable = lib.mkEnableOption "Paseo CLI";

    version = lib.mkOption {
      type = lib.types.str;
      default = "latest";
      description = "Version of Paseo CLI to install.";
    };
  };

  config = lib.mkIf cfg.enable {
    packages = [
      (helpers.mkNpmCli {
        pname = "paseo";
        npmName = "@getpaseo/cli";
        version = cfg.version;
        sha256 = lib.fakeHash;
      })
    ];

    enterShell = ''
      # dx.tools.paseo: ensure .paseo directory exists
      mkdir -p "$HOME/.paseo"
    '';
  };
}
