# dx.agents.kilo — Kilo CLI
# Migrated from: ghcr.io/docker-x/devcontainers/kilo
# Install method: GitHub release binary from Kilo-Org/kilo
#
# NOTE: the version option is pinned because mkGithubBinary verifies sha256.
# Bumping `version` requires updating the per-arch hashes below.

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.agents.kilo;

  archSuffix = {
    x86_64-linux = "x64";
    aarch64-linux = "arm64";
  }.${pkgs.stdenv.hostPlatform.system} or (throw "dx.agents.kilo: unsupported system ${pkgs.stdenv.hostPlatform.system}");

  # sha256 of the v1.0.25 release assets (from GitHub API asset digests)
  hashes = {
    x86_64-linux = "41b11206107c619c880076dfbdaed6b4b03c2263376fb1b3372b14bd9613564a";
    aarch64-linux = "1af9d2c8ef4c14b80d22c231ec640ac3aedd2b5d710bf9850e2027fd42fa261a";
  };
in
{
  options.dx.agents.kilo = helpers.mkAgentOptions {
    agentId = "kilo";
    name = "Kilo CLI";
    hasShareConfig = false;
    extraOptions = {
      version = lib.mkOption {
        type = lib.types.str;
        default = "v1.0.25";
        description = "Kilo release tag. Pinned because sha256 hashes are verified; bump hashes when bumping the version.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    packages = [
      (helpers.mkGithubBinary {
        pname = "kilo";
        version = cfg.version;
        owner = "Kilo-Org";
        repo = "kilo";
        asset = "kilo-linux-${archSuffix}.tar.gz";
        sha256 = hashes.${pkgs.stdenv.hostPlatform.system} or lib.fakeHash;
      })
    ];
  };
}
