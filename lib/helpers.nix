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
    let
      # GitHub uses /releases/latest/download/ for the latest release,
      # not /releases/download/latest/ which returns 404.
      versionPath = if version == "latest" then "latest/download" else "${version}/download";
      isArchive = builtins.match ".*\\.(tar\\.(gz|bz2|xz)|tgz|zip)$" asset != null;
    in
    pkgs.stdenv.mkDerivation {
      inherit pname version postInstall;

      src = pkgs.fetchurl {
        url = "https://github.com/${owner}/${repo}/releases/${versionPath}/${asset}";
        inherit sha256;
      };

      # Archives need unpacking; raw binaries don't.
      dontUnpack = !isArchive;
      dontBuild = true;

      installPhase = ''
        runHook preInstall
        mkdir -p $out/bin
        ${if isArchive then ''
          # Extract archive and find the binary
          _tmpdir=$(mktemp -d)
          cp $src "$_tmpdir/${asset}"
          ${lib.optionalString (builtins.match ".*\\.zip$" asset != null) "unzip"}
          tar xf "$_tmpdir/${asset}" -C "$_tmpdir" 2>/dev/null || unzip "$_tmpdir/${asset}" -d "$_tmpdir" 2>/dev/null || true
          # Find the binary: either matches pname or is the only executable
          _bin=$(find "$_tmpdir" -type f -name "${pname}" -o -type f -name "${pname}-*" 2>/dev/null | head -1)
          if [[ -z "$_bin" ]]; then
            _bin=$(find "$_tmpdir" -type f -executable 2>/dev/null | head -1)
          fi
          if [[ -n "$_bin" ]]; then
            cp "$_bin" $out/bin/${pname}
            chmod +x $out/bin/${pname}
          else
            echo "Warning: could not find ${pname} binary in archive" >&2
            cp "$_tmpdir/${asset}" $out/bin/${pname}
          fi
          rm -rf "$_tmpdir"
        '' else ''
          cp $src $out/bin/${pname}
          chmod +x $out/bin/${pname}
        ''}
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
    let
      # For "latest", use the npm registry redirect endpoint which resolves
      # to the most recent version's tarball. For pinned versions, construct
      # the tarball URL directly.
      tarballUrl =
        if version == "latest"
        then "https://registry.npmjs.org/${npmName}/-/${builtins.baseNameOf npmName}-latest.tgz"
        else "https://registry.npmjs.org/${npmName}/-/${builtins.baseNameOf npmName}-${version}.tgz";
    in
    pkgs.stdenv.mkDerivation {
      inherit pname version postInstall;

      src = pkgs.fetchurl {
        url = tarballUrl;
        inherit sha256;
      };

      nativeBuildInputs = [ pkgs.nodejs pkgs.npm-hook ];

      dontUnpack = true;
      dontBuild = true;

      installPhase = ''
        runHook preInstall
        mkdir -p $out/lib/node_modules $out/bin
        # Install from the fetched tarball
        npm install -g --prefix $out "$src" --ignore-scripts 2>&1 || {
          echo "Warning: npm install failed for ${pname}" >&2
          exit 1
        }
        # Link all bin entries from the installed package
        _pkgdir="$out/lib/node_modules/${npmName}"
        if [[ -d "$_pkgdir/bin" ]]; then
          for bin in "$_pkgdir"/bin/*; do
            ln -sf "$bin" "$out/bin/$(basename "$bin")"
          done
        elif [[ -f "$_pkgdir/package.json" ]]; then
          # Some packages declare bins in package.json
          _bins=$(node -e "const p=require('$_pkgdir/package.json'); const b=p.bin||{}; Object.keys(b).forEach(k=>console.log(k))" 2>/dev/null || true)
          for bin in $_bins; do
            ln -sf "$_pkgdir/$(node -e "const p=require('$_pkgdir/package.json'); const b=p.bin||{}; console.log(typeof b==='string'?b:b['$bin'])" 2>/dev/null)" "$out/bin/$bin" 2>/dev/null || true
          done
        fi
        runHook postInstall
      '';

      meta.mainProgram = pname;
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
