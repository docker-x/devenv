# dx.infra.devsy — Devsy agent (pre-install)
# Migrated from: ghcr.io/docker-x/devcontainers/devsy
# Pre-installs the Devsy agent binary as a fallback for orchestrators
# where native agent injection fails (e.g. OpenShift restricted SCC).

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.infra.devsy;
in
{
  options.dx.infra.devsy = {
    enable = lib.mkEnableOption "Devsy agent binary (pre-install fallback)";

    version = lib.mkOption {
      type = lib.types.str;
      default = "v1.16.2";
      description = "Pinned Devsy release tag.";
    };
  };

  config = lib.mkIf cfg.enable {
    packages = [
      (helpers.mkGithubBinary {
        pname = "devsy";
        version = cfg.version;
        owner = "devsy-org";
        repo = "devsy";
        asset = "devsy-linux-amd64";
        sha256 = "4983c52a3536c5a91d1b5f356a1c3428778ebf3f896d9897f60bce3978abc839";
      })
    ];
  };
}
