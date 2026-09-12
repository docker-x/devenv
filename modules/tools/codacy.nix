# dx.tools.codacy — Codacy CLI v2
# Migrated from: ghcr.io/docker-x/devcontainers/codacy
# Install method: GitHub release binary from codacy/codacy-cli-v2
#
# NOTE: the version option is pinned because mkGithubBinary verifies sha256.
# Bumping `version` requires updating the per-arch hashes below.

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.tools.codacy;

  goarch = {
    x86_64-linux = "amd64";
    aarch64-linux = "arm64";
  }.${pkgs.stdenv.hostPlatform.system} or (throw "dx.tools.codacy: unsupported system ${pkgs.stdenv.hostPlatform.system}");

  # sha256 of the 1.0.0-main.382.sha.473b61c release assets (GitHub API digests)
  hashes = {
    x86_64-linux = "c9417215e4e53ec338debdf0ff48f2f05f00fefdb4833cbe0d98d307e246f8ad";
    aarch64-linux = "787920760144d4030fc441fb5a2dbe47707e21cf3821a10c62d8c260e1044f4d";
  };
in
{
  options.dx.tools.codacy = {
    enable = lib.mkEnableOption "Codacy CLI v2";

    version = lib.mkOption {
      type = lib.types.str;
      default = "1.0.0-main.382.sha.473b61c";
      description = "Codacy CLI v2 release tag. Pinned because sha256 is verified; bump hashes when bumping the version.";
    };
  };

  config = lib.mkIf cfg.enable {
    packages = [
      (helpers.mkGithubBinary {
        pname = "codacy-cli-v2";
        version = cfg.version;
        owner = "codacy";
        repo = "codacy-cli-v2";
        asset = "codacy-cli-v2_${cfg.version}_linux_${goarch}.tar.gz";
        sha256 = hashes.${pkgs.stdenv.hostPlatform.system} or lib.fakeHash;
        postInstall = ''
          ln -sf $out/bin/codacy-cli-v2 $out/bin/codacy-cli
        '';
      })
    ];
  };
}
