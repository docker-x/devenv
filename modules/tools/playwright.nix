# dx.tools.playwright — Playwright browser automation
# Migrated from: ghcr.io/docker-x/devcontainers/playwright
# Installs system dependencies for Playwright browser automation.

{ lib, config, pkgs, ... }:

let
  cfg = config.dx.tools.playwright;
in
{
  options.dx.tools.playwright = {
    enable = lib.mkEnableOption "Playwright system dependencies";

    browsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "chromium" ];
      description = "Browsers to install (chromium, firefox, webkit).";
    };

    installMethod = lib.mkOption {
      type = lib.types.enum [ "auto" "deps-only" ];
      default = "auto";
      description = "Install browser binaries (auto) or just system deps (deps-only).";
    };
  };

  config = lib.mkIf cfg.enable {
    packages = [ pkgs.playwright ]
      ++ lib.optional (pkgs ? nixpkgs-fmt) pkgs.nixpkgs-fmt;

    env.DISPLAY = ":99";

    enterShell = ''
      # dx.tools.playwright: install browser dependencies
      if command -v npx &>/dev/null; then
        npx playwright install-deps ${lib.concatStringsSep " " cfg.browsers} 2>/dev/null || true
        ${lib.optionalString (cfg.installMethod == "auto") ''
          npx playwright install ${lib.concatStringsSep " " cfg.browsers} 2>/dev/null || true
        ''}
      fi
    '';
  };
}
