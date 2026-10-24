# dx.agents.goose — Goose CLI (block/goose)
# Install method: platform binary tarball from GitHub releases.
# Release assets moved from aaif-goose/goose-linux-amd64.tar.gz to
# block/goose-<triple>.tar.gz — the old asset name now 404s at build time.

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.agents.goose;
  agentConfigDir = config.dx.core.agentConfig.dir or "\${AGENT_CONFIG_DIR:-$HOME/.local/share/agent-config}";

  asset = {
    x86_64-linux = "goose-x86_64-unknown-linux-gnu.tar.gz";
    aarch64-linux = "goose-aarch64-unknown-linux-gnu.tar.gz";
  }.${pkgs.stdenv.hostPlatform.system} or (throw "dx.agents.goose: unsupported system ${pkgs.stdenv.hostPlatform.system}");

  # sha256 of the GitHub release tarballs, keyed by version — same
  # fill-in-the-hash flow as dx.agents.opencode on version bumps.
  hashes = {
    "1.56.0" = {
      x86_64-linux = "sha256-IlqSmzW1Ew+2ker9tQviNvLAoVABm1OXN3WTj48ZwoE=";
      aarch64-linux = "sha256-Jry30/VarEhakdgcvezY2Q5a8ayt7KblgLTVi2SoiOQ=";
    };
  };
in
{
  options.dx.agents.goose = helpers.mkAgentOptions {
    agentId = "goose";
    name = "Goose CLI";
    extraOptions = {
      version = lib.mkOption {
        type = lib.types.str;
        default = "1.56.0";
        description = "Goose version. Pinned by default because the binary method verifies sha256 — bump hashes when bumping the version; 'latest' is not supported (release assets have no 'latest' URL).";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    dx.core.agentConfig.enable = lib.mkIf cfg.shareConfig true;

    packages = [
      (helpers.mkGithubBinary {
        pname = "goose";
        version = cfg.version;
        url = if cfg.version == "latest"
          then throw "dx.agents.goose: requires a pinned version (release assets have no 'latest' URL)"
          else "https://github.com/block/goose/releases/download/v${cfg.version}/${asset}";
        inherit asset;
        sha256 = hashes.${cfg.version}.${pkgs.stdenv.hostPlatform.system} or lib.fakeHash;
        # The release binary is a dynamically-linked ELF pointing at the
        # host /lib64/ld-linux — wrap it through the nix dynamic loader.
        ldsoWrapper = true;
      })
    ];

    enterShell = lib.optionalString cfg.shareConfig (helpers.shareConfigHook {
      agentId = "goose";
      configPaths = [ "$HOME/.goose" "$HOME/.config/goose" ];
      agentConfigDir = toString agentConfigDir;
    });
  };
}
