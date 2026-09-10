# dx.tools.gascity — Gas City
# Migrated from: ghcr.io/docker-x/devcontainers/gascity
# AI agent orchestration platform: gc, bd binaries from gastownhall/gascity
# + dolt from dolthub/dolt. Entry point for auto-register.

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.tools.gascity;
in
{
  options.dx.tools.gascity = {
    enable = lib.mkEnableOption "Gas City — AI agent orchestration platform";

    version = lib.mkOption {
      type = lib.types.str;
      default = "latest";
      description = "Version of Gas City to install (e.g. '1.4.1' or 'latest').";
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
        version = if cfg.version == "latest" then "latest" else cfg.version;
        owner = "gastownhall";
        repo = "gascity";
        asset = "gc-linux-amd64";
        sha256 = lib.fakeHash;
      })
      (helpers.mkGithubBinary {
        pname = "bd";
        version = if cfg.version == "latest" then "latest" else cfg.version;
        owner = "gastownhall";
        repo = "gascity";
        asset = "bd-linux-amd64";
        sha256 = lib.fakeHash;
      })
      (helpers.mkGithubBinary {
        pname = "dolt";
        version = "latest";
        owner = "dolthub";
        repo = "dolt";
        asset = "dolt-linux-amd64.tar.gz";
        sha256 = lib.fakeHash;
      })
    ];

    processes.gascity-register = lib.mkIf cfg.autoRegister {
      exec = ''
        gc register .
      '';
    };
  };
}
