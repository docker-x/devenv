# dx.agents.codewhale — Codewhale terminal coding agent
# Install method: platform binary tarball from GitHub releases.
# The npm package's postinstall downloads the same ELF (no /lib64/ld-linux
# in Nix containers → silent failure, same as opencode), so the binary
# install path fetches the release asset directly and wraps it through the
# nix dynamic loader.

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.agents.codewhale;
  agentConfigDir = config.dx.core.agentConfig.dir or "\${AGENT_CONFIG_DIR:-$HOME/.local/share/agent-config}";

  asset = {
    x86_64-linux = "codewhale-linux-x64.tar.gz";
    aarch64-linux = "codewhale-linux-arm64.tar.gz";
  }.${pkgs.stdenv.hostPlatform.system} or (throw "dx.agents.codewhale: unsupported system ${pkgs.stdenv.hostPlatform.system}");

  # sha256 of the GitHub release tarballs, keyed by version — same
  # fill-in-the-hash flow as dx.agents.opencode on version bumps.
  hashes = {
    "0.10.1" = {
      x86_64-linux = "sha256-EBkzl7xg8ozUUUGtRUFLBf0U2fHiYe+QpX92ccmHC8A=";
      aarch64-linux = "sha256-TjXuVbPXmvkWRjrPDrPmDUjslz6aH9xlU+bxWSCUwVE=";
    };
  };
in
{
  options.dx.agents.codewhale = helpers.mkAgentOptions {
    agentId = "codewhale";
    name = "Codewhale";
    extraOptions = {
      version = lib.mkOption {
        type = lib.types.str;
        default = "0.10.1";
        description = "Codewhale version. Pinned by default because the binary method verifies sha256 — bump hashes when bumping the version; 'latest' is not supported (release assets have no 'latest' URL).";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    dx.core.agentConfig.enable = lib.mkIf cfg.shareConfig true;

    packages = [
      (helpers.mkGithubBinary {
        pname = "codewhale";
        version = cfg.version;
        url = if cfg.version == "latest"
          then throw "dx.agents.codewhale: installMethod requires a pinned version (release assets have no 'latest' URL)"
          else "https://github.com/codewhale-hq/Codewhale/releases/download/v${cfg.version}/${asset}";
        inherit asset;
        sha256 = hashes.${cfg.version}.${pkgs.stdenv.hostPlatform.system} or lib.fakeHash;
        # The release binary is a dynamically-linked ELF pointing at the
        # host /lib64/ld-linux — wrap it through the nix dynamic loader.
        ldsoWrapper = true;
      })
    ];

    enterShell = lib.optionalString cfg.shareConfig (helpers.shareConfigHook {
      agentId = "codewhale";
      configPaths = [ "$HOME/.codewhale" "$HOME/.config/codewhale" ];
      agentConfigDir = toString agentConfigDir;
    });
  };
}
