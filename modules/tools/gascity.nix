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
      x86_64-linux = "3219443a9734b89b93fb16ee8d65844759fa1b3cd3cf139c606b7353cfb0715c";
      aarch64-linux = "c3b32c71a6c0cd6358a12c28272b17e6818db991da192f87df52339c222e423a";
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
      default = "v1.3.1";
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
        # bd is a CGO Go binary — patchelf rewrites ELF program headers and
        # the Go runtime segfaults re-reading them. Run it through the nix
        # dynamic loader via a wrapper instead (docker-x/devenv#22).
        ldsoWrapper = true;
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

    # Store-pinned binaries — updater reports drift; real update = version
    # bump here + image rebuild.
    dx.tools.updater.entries =
      let
        # jq is in this module's packages; GH_TOKEN lifts the 60/h
        # unauthenticated rate limit when present.
        latestTag = repo: ''
          h=(); [ -n "''${GH_TOKEN:-}" ] && h=(-H "Authorization: Bearer $GH_TOKEN")
          curl -fsSL "''${h[@]}" https://api.github.com/repos/${repo}/releases/latest 2>/dev/null | jq -r .tag_name'';
        vpin = v: "v" + lib.removePrefix "v" v;
      in
      [
        { name = "gc";   current = "echo ${vpin cfg.version}";       latest = latestTag "gastownhall/gascity"; }
        { name = "bd";   current = "echo ${vpin cfg.beadsVersion}";  latest = latestTag "gastownhall/beads"; }
        { name = "dolt"; current = "echo ${vpin cfg.doltVersion}";   latest = latestTag "dolthub/dolt"; }
      ];
  };
}
