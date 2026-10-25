# dx.agents.opencode — OpenCode AI
# Migrated from: ghcr.io/docker-x/devcontainers/opencode
# Install methods: npm or binary

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.agents.opencode;
  agentConfigDir = config.dx.core.agentConfig.dir or "\${AGENT_CONFIG_DIR:-$HOME/.local/share/agent-config}";

  # npm ships the real binary as platform optional-deps tarballs
  # (opencode-linux-x64 etc.) — the GitHub releases repo's asset scheme
  # went stale, so the binary install path fetches the npm tarball.
  # OpenCode 2.x moved the npm packages under the @opencode org
  npmPkg = if lib.versionAtLeast cfg.version "2.0.0" then {
    x86_64-linux = "@opencode/cli-linux-x64";
    aarch64-linux = "@opencode/cli-linux-arm64";
  } else {
    x86_64-linux = "opencode-linux-x64";
    aarch64-linux = "opencode-linux-arm64";
  };
  npmPkgName = npmPkg.${pkgs.stdenv.hostPlatform.system} or (throw "dx.agents.opencode: unsupported system ${pkgs.stdenv.hostPlatform.system}");

  # sha256 of the npm platform tarballs, keyed by version — same
  # fill-in-the-hash flow as dx.agents.kilo on version bumps.
  hashes = {
    "1.18.32" = {
      x86_64-linux = "sha256-2ggDyF64ZwnE8ISty/sLUymTZnC/5D0jZ/DKA0vgwd4=";
      aarch64-linux = "sha256-KastYacOmdEiTSiRFcO4GU/yVJaOJglTEYYie+ObIAE=";
    };
    "2.1.4" = {
      x86_64-linux = "sha256-zgWr4tzhBBORyOyM242gZvZA/UcecqyEbcsInEQeEeE=";
      aarch64-linux = "sha256-6ay04jqaxDITlpOqFmRVpq3YlGUzOUy+CDRZpI54iGE=";
    };
  };
in
{
  options.dx.agents.opencode = helpers.mkAgentOptions {
    agentId = "opencode";
    name = "OpenCode AI";
    extraOptions = {
      installMethod = lib.mkOption {
        type = lib.types.enum [ "npm" "binary" ];
        # Binary is the default: the npm path's postinstall cannot exec the
        # bundled ELF in Nix containers (no /lib64/ld-linux) and fails
        # silently in verifyBinary() — the npm tarball path runs the same
        # binary through the nix dynamic loader.
        default = "binary";
        description = "Install OpenCode via npm (npx wrapper) or the platform binary tarball.";
      };
      version = lib.mkOption {
        type = lib.types.str;
        default = "2.1.4";
        description = "OpenCode version. Pinned by default because the binary method verifies sha256 — bump hashes when bumping the version; 'latest' is valid only with installMethod = \"npm\".";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    dx.core.agentConfig.enable = lib.mkIf cfg.shareConfig true;

    packages = lib.optional (cfg.installMethod == "npm")
      (helpers.mkNpmCli {
        pname = "opencode";
        npmName = "opencode-ai";
        version = cfg.version;
        sha256 = lib.fakeHash;
      }) ++ lib.optional (cfg.installMethod == "binary")
      (helpers.mkGithubBinary {
        pname = "opencode";
        version = cfg.version;
        url = if cfg.version == "latest"
          then throw "dx.agents.opencode: installMethod \"binary\" requires a pinned version (npm registry has no 'latest' tarball URL)"
          else "https://registry.npmjs.org/${npmPkgName}/-/${lib.last (lib.splitString "/" npmPkgName)}-${cfg.version}.tgz";
        asset = "${lib.last (lib.splitString "/" npmPkgName)}-${cfg.version}.tgz";
        sha256 = hashes.${cfg.version}.${pkgs.stdenv.hostPlatform.system} or lib.fakeHash;
        # OpenCode is a bun single-executable: ldsoWrapper execs via ld.so
        # so /proc/self/exe resolves to the linker — the SEA still loads
        # (opencode serve works) but self-locating features break (e.g.
        # `opencode upgrade` detects the install dir as the ldso path and
        # reports "unknown installation method"). autoPatchelf --set-rpath
        # relocates headers the runtime re-reads → segfault. interpOnly
        # keeps /proc/self/exe pointing at the real binary.
        interpOnly = true;
      });

    enterShell = lib.optionalString cfg.shareConfig (helpers.shareConfigHook {
      agentId = "opencode";
      configPaths = [ "$HOME/.opencode" "$HOME/.config/opencode" ];
      agentConfigDir = toString agentConfigDir;
    });
  };
}
