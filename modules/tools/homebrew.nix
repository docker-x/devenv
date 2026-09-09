# dx.tools.homebrew — Homebrew on Linux
# Migrated from: ghcr.io/docker-x/devcontainers/homebrew
# Installs Homebrew with optional package list.

{ lib, config, pkgs, ... }:

let
  cfg = config.dx.tools.homebrew;
in
{
  options.dx.tools.homebrew = {
    enable = lib.mkEnableOption "Homebrew on Linux";

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Homebrew packages to install.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Homebrew is a Linuxbrew installation. In devenv, prefer nixpkgs
    # but provide Homebrew for compatibility with brew-only formulas.
    packages = [ pkgs.homebrew ];

    env.HOMEBREW_PREFIX = "/home/linuxbrew/.linuxbrew";

    enterShell = ''
      # dx.tools.homebrew: ensure Homebrew is initialized
      if command -v brew &>/dev/null; then
        eval "$(brew shellenv)"
      fi
      ${lib.concatMapStrings (pkg: ''
        if command -v brew &>/dev/null; then
          brew install ${pkg} 2>/dev/null || true
        fi
      '') cfg.packages}
    '';
  };
}
