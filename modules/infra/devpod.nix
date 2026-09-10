# dx.infra.devpod — DevPod agent (legacy)
# Migrated from: ghcr.io/docker-x/devcontainers/devpod
# Pre-installs the DevPod agent binary from loft-sh/devpod.
# DevPod is unmaintained — use only for rollback during DevPod->Devsy migration.

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.infra.devpod;
in
{
  options.dx.infra.devpod = {
    enable = lib.mkEnableOption "DevPod agent binary (legacy, unmaintained)";

    version = lib.mkOption {
      type = lib.types.str;
      default = "v0.5.0";
      description = "Pinned DevPod release tag.";
    };
  };

  config = lib.mkIf cfg.enable {
    packages = [
      (helpers.mkGithubBinary {
        pname = "devpod";
        version = cfg.version;
        owner = "loft-sh";
        repo = "devpod";
        asset = "devpod-linux-amd64";
        sha256 = lib.fakeHash;
      })
    ];
  };
}
