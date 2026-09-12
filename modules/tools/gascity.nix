# dx.tools.gascity — Gas City
# Migrated from: ghcr.io/docker-x/devcontainers/gascity
# AI agent orchestration platform: gc binary from gastownhall/gascity,
# bd (beads) from gastownhall/beads, dolt from dolthub/dolt.
#
# NOTE: versions are pinned because mkGithubBinary verifies sha256.
# Bumping a version requires updating its hashes below.

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.tools.gascity;

  goarch = {
    x86_64-linux = "amd64";
    aarch64-linux = "arm64";
  }.${pkgs.stdenv.hostPlatform.system} or (throw "dx.tools.gascity: unsupported system ${pkgs.stdenv.hostPlatform.system}");

  gcVersion = lib.removePrefix "v" cfg.version;
  beadsVersion = lib.removePrefix "v" cfg.beadsVersion;

  hashes = {
    gascity = {
      x86_64-linux = "8d8c8b511db3fc44931445aab5cb9f212509c0867105c880d6c3d0e6e5d33e42";
      aarch64-linux = "6620ef51c8ba620821e5ef8b208bb1b3de090fa86ec5e0327da1edd615407e29";
    };
    beads = {
      x86_64-linux = "8140098a51d3b81d5548d1c5e6db1a2d9930e5d141efe2a4bff7d079c4d321e8";
      aarch64-linux = "501f38a1070d4b9b3b6261a86a3c92c4a52366869021560430a4bb0036afd83a";
    };
    dolt = {
      x86_64-linux = "4acd730a4c53991996854a72fbb1add102b0a583bd07411320efb65037a43d9d";
      aarch64-linux = "850a880aece6587cb9251ea0f07eb51fcc0a37450471fd89e03ac2fba1fdaed3";
    };
  };
in
{
  options.dx.tools.gascity = {
    enable = lib.mkEnableOption "Gas City — AI agent orchestration platform";

    version = lib.mkOption {
      type = lib.types.str;
      default = "v1.4.1";
      description = "Gas City release tag. Pinned because sha256 is verified; bump hashes when bumping the version.";
    };

    beadsVersion = lib.mkOption {
      type = lib.types.str;
      default = "v1.2.2";
      description = "Beads (bd) release tag from gastownhall/beads. Pinned because sha256 is verified.";
    };

    doltVersion = lib.mkOption {
      type = lib.types.str;
      default = "v2.3.3";
      description = "Dolt release tag from dolthub/dolt. Pinned because sha256 is verified.";
    };

    autoRegister = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Automatically register city with supervisor on startup.";
    };
  };

  config = lib.mkIf cfg.enable {
    packages = [
      pkgs.tmux
      pkgs.jq
      (helpers.mkGithubBinary {
        pname = "gc";
        version = cfg.version;
        owner = "gastownhall";
        repo = "gascity";
        asset = "gascity_${gcVersion}_linux_${goarch}.tar.gz";
        sha256 = hashes.gascity.${pkgs.stdenv.hostPlatform.system} or lib.fakeHash;
      })
      (helpers.mkGithubBinary {
        pname = "bd";
        version = cfg.beadsVersion;
        owner = "gastownhall";
        repo = "beads";
        asset = "beads_${beadsVersion}_linux_${goarch}.tar.gz";
        sha256 = hashes.beads.${pkgs.stdenv.hostPlatform.system} or lib.fakeHash;
      })
      (helpers.mkGithubBinary {
        pname = "dolt";
        version = cfg.doltVersion;
        owner = "dolthub";
        repo = "dolt";
        asset = "dolt-linux-${goarch}.tar.gz";
        sha256 = hashes.dolt.${pkgs.stdenv.hostPlatform.system} or lib.fakeHash;
      })
    ];

    processes.gascity-register = lib.mkIf cfg.autoRegister {
      exec = ''
        gc register .
      '';
    };
  };
}
