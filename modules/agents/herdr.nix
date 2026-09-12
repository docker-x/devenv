# dx.agents.herdr — Herdr
# Migrated from: ghcr.io/docker-x/devcontainers/herdr
# Install method: GitHub release binary from herdrdev/herdr
# Version manifest at https://herdr.dev/latest.json
#
# NOTE: the version option is pinned because mkGithubBinary verifies sha256.
# Bumping `version` requires updating the per-arch hashes below.

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.agents.herdr;
  agentConfigDir = config.dx.core.agentConfig.dir or "\${AGENT_CONFIG_DIR:-$HOME/.local/share/agent-config}";

  assetSuffix = {
    x86_64-linux = "x86_64";
    aarch64-linux = "aarch64";
  }.${pkgs.stdenv.hostPlatform.system} or (throw "dx.agents.herdr: unsupported system ${pkgs.stdenv.hostPlatform.system}");

  # sha256 of the v0.9.0 release assets (from GitHub API asset digests)
  hashes = {
    x86_64-linux = "4fa1a01158dd8043da92d31b270780b0dcc10603038d9b61cac4d81ab63fb71f";
    aarch64-linux = "9c8db20fb7e7427b138d5367113f1621ffd319f2f65d6f009e2594029115f0d2";
  };
in
{
  options.dx.agents.herdr = helpers.mkAgentOptions {
    agentId = "herdr";
    name = "Herdr";
    extraOptions = {
      version = lib.mkOption {
        type = lib.types.str;
        default = "v0.9.0";
        description = "Herdr release tag. Pinned because sha256 hashes are verified; bump hashes when bumping the version.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    dx.core.agentConfig.enable = lib.mkIf cfg.shareConfig true;

    packages = [
      (helpers.mkGithubBinary {
        pname = "herdr";
        version = cfg.version;
        owner = "herdrdev";
        repo = "herdr";
        asset = "herdr-linux-${assetSuffix}";
        sha256 = hashes.${pkgs.stdenv.hostPlatform.system} or lib.fakeHash;
      })
    ];

    enterShell = lib.optionalString cfg.shareConfig (helpers.shareConfigHook {
      agentId = "herdr";
      configPaths = [ "$HOME/.herdr" "$HOME/.config/herdr" ];
      agentConfigDir = toString agentConfigDir;
    });
  };
}
