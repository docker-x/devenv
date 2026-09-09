# dx.tools.sacp-conductor — sacp-conductor
# Migrated from: ghcr.io/docker-x/devcontainers/sacp-conductor
# ACP proxy orchestration tool, installed via Cargo.

{ lib, config, pkgs, ... }:

let
  cfg = config.dx.tools.sacpConductor;
in
{
  options.dx.tools.sacpConductor = {
    enable = lib.mkEnableOption "sacp-conductor (ACP proxy orchestration)";
  };

  config = lib.mkIf cfg.enable {
    packages = [ pkgs.cargo ];

    enterShell = ''
      # dx.tools.sacp-conductor: install via cargo
      if ! command -v sacp-conductor &>/dev/null; then
        cargo install sacp-conductor 2>/dev/null || true
      fi
    '';
  };
}
