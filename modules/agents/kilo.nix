# dx.agents.kilo — Kilo CLI
# Migrated from: ghcr.io/docker-x/devcontainers/kilo
# Install method: GitHub release binary from Kilo-Org/kilo

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.agents.kilo;
in
{
  options.dx.agents.kilo = helpers.mkAgentOptions {
    agentId = "kilo";
    name = "Kilo CLI";
    hasShareConfig = false;
  };

  config = lib.mkIf cfg.enable {
    packages = [
      (helpers.mkGithubBinary {
        pname = "kilo";
        version = if cfg.version == "latest" then "latest" else cfg.version;
        owner = "Kilo-Org";
        repo = "kilo";
        asset = "kilo-linux-amd64.tar.gz";
        sha256 = lib.fakeHash;
      })
    ];
  };
}
