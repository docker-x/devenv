# Shared helper functions for docker-x/devenv modules.
#
# These helpers translate the devcontainer feature install patterns
# (npm install -g, GitHub release binaries, shared config symlinks)
# into idiomatic Nix derivations and devenv enterShell hooks.

{ lib, pkgs }:

let
  # ---------------------------------------------------------------------------
  # mkGithubBinary — fetch a single binary from a GitHub release.
  #
  # Example:
  #   mkGithubBinary {
  #     pname = "devsy";
  #     version = "v1.16.2";
  #     owner = "devsy-org";
  #     repo = "devsy";
  #     asset = "devsy-linux-amd64";
  #     sha256 = lib.fakeHash;  # fill in after first build
  #   }
  # ---------------------------------------------------------------------------
  mkGithubBinary =
    { pname
    , version
    , owner
    , repo ? owner
    , asset
    , sha256 ? lib.fakeHash
    , postInstall ? ""
    }:
    pkgs.stdenv.mkDerivation {
      inherit pname version postInstall;

      src = pkgs.fetchurl {
        url = "https://github.com/${owner}/${repo}/releases/download/${version}/${asset}";
        inherit sha256;
      };

      dontUnpack = true;
      dontBuild = true;

      installPhase = ''
        runHook preInstall
        mkdir -p $out/bin
        cp $src $out/bin/${pname}
        chmod +x $out/bin/${pname}
        runHook postInstall
      '';

      meta.mainProgram = pname;
    };

  # ---------------------------------------------------------------------------
  # mkNpmCli — build a global npm CLI package.
  #
  # Uses buildNpmPackage when a lockfile is available, otherwise falls back
  # to a simple nodejs-based derivation that runs `npm install --prefix`.
  #
  # Example:
  #   mkNpmCli {
  #     pname = "claude-code";
  #     npmName = "@anthropic-ai/claude-code";
  #     version = "latest";
  #   }
  # ---------------------------------------------------------------------------
  mkNpmCli =
    { pname
    , npmName
    , version ? "latest"
    , sha256 ? lib.fakeHash
    , postInstall ? ""
    }:
    pkgs.buildNpmPackage {
      inherit pname version postInstall;

      npmDepsHash = sha256;

      src = pkgs.fetchurl {
        url = "https://registry.npmjs.org/${npmName}/-/${builtins.baseNameOf npmName}-${version}.tgz";
        inherit sha256;
      };

      dontNpmBuild = true;

      installPhase = ''
        runHook preInstall
        mkdir -p $out/bin $out/lib/node_modules
        npm install --prefix $out/lib ${npmName}@${version} --ignore-scripts
        # Link all bin entries
        for bin in $out/lib/node_modules/${npmName}/bin/*; do
          ln -sf "$bin" "$out/bin/$(basename "$bin")"
        done
        runHook postInstall
      '';
    };

  # ---------------------------------------------------------------------------
  # mkScriptCli — install a CLI via an upstream install script.
  #
  # For tools that only provide a curl|bash installer (e.g. cursor, devin).
  # Creates a derivation that runs the installer in a FHS-like environment.
  #
  # Example:
  #   mkScriptCli {
  #     pname = "cursor";
  #     url = "https://cursor.com/install";
  #   }
  # ---------------------------------------------------------------------------
  mkScriptCli =
    { pname
    , url
    , sha256 ? lib.fakeHash
    , deps ? [ ]
    , postInstall ? ""
    }:
    pkgs.stdenv.mkDerivation {
      inherit pname postInstall;
      version = "latest";

      nativeBuildInputs = deps ++ [ pkgs.curl pkgs.bash ];

      dontUnpack = true;

      installPhase = ''
        runHook preInstall
        export HOME=$out/home
        mkdir -p $HOME $out/bin
        curl --proto =https -fsSL ${url} | bash || true
        # Move any installed binaries to $out/bin
        find $HOME -type f -executable -name "${pname}*" 2>/dev/null | while read -r bin; do
          cp "$bin" $out/bin/ 2>/dev/null || true
        done
        runHook postInstall
      '';

      meta.mainProgram = pname;
    };

  # ---------------------------------------------------------------------------
  # shareConfigHook — generate an enterShell snippet that symlinks an agent's
  # config directory into the shared AGENT_CONFIG_DIR.
  #
  # This mirrors the devcontainer `shareConfig` option: when enabled, the
  # agent's native config location is symlinked to a subdirectory under
  # AGENT_CONFIG_DIR so config persists and can be shared across agents.
  #
  # Example:
  #   shareConfigHook {
  #     agentId = "devin";
  #     configPaths = [ "$HOME/.devin" "$HOME/.config/devin" ];
  #   }
  # ---------------------------------------------------------------------------
  shareConfigHook =
    { agentId
    , configPaths
    , agentConfigDir ? "\${AGENT_CONFIG_DIR:-$HOME/.local/share/agent-config}"
    }:
    let
      paths = lib.concatMapStringsSep "\n" (p: "  ${p}") configPaths;
    in
    ''
      # docker-x: shareConfig for ${agentId}
      _AGENT_DIR="${agentConfigDir}/${agentId}"
      if [[ ! -d "$_AGENT_DIR" ]]; then
        mkdir -p "$_AGENT_DIR"
      fi
    '' + lib.concatMapStringsSep "\n" (path: ''
      if [[ ! -L "${path}" ]]; then
        if [[ -e "${path}" ]] && [[ ! -L "${path}" ]]; then
          mv "${path}" "$_AGENT_DIR/$(basename "${path}")-legacy" 2>/dev/null || true
        fi
        mkdir -p "$(dirname "${path}")"
        ln -sfn "$_AGENT_DIR" "${path}"
      fi
    '') configPaths;

  # ---------------------------------------------------------------------------
  # mkAgentOptions — generate the standard option set for an AI agent module.
  #
  # Every agent module in docker-x follows the same pattern: enable, version,
  # and optionally shareConfig. This helper reduces boilerplate.
  # ---------------------------------------------------------------------------
  mkAgentOptions =
    { agentId
    , name
    , description ? null
    , hasVersion ? true
    , hasShareConfig ? true
    , extraOptions ? { }
    }:
    let
      base = {
        enable = lib.mkEnableOption name;
      } // (lib.optionalAttrs hasVersion {
        version = lib.mkOption {
          type = lib.types.str;
          default = "latest";
          description = "Version of ${name} to install (e.g. 'latest' or a release tag).";
        };
      }) // (lib.optionalAttrs hasShareConfig {
        shareConfig = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "When true, symlink the agent's config dir to the shared AGENT_CONFIG_DIR.";
        };
      });
    in
    base // extraOptions;

in
{
  inherit
    mkGithubBinary
    mkNpmCli
    mkScriptCli
    shareConfigHook
    mkAgentOptions;
}
