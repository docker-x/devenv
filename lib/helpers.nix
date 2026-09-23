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
    , # Set true for dynamically-linked binaries (e.g. CGO-enabled Go
      # releases) — rewrites the ELF interpreter to the nix glibc and
      # adds an rpath for libgcc/libstdc++. Implemented via explicit
      # patchelf (not autoPatchelfHook) so it works on any build host.
      autoPatchelf ? false
    , # Alternative to autoPatchelf for binaries that break when patchelf
      # rewrites their program headers (notably Go/CGO binaries — the Go
      # runtime re-reads its own ELF headers and segfaults). Keeps the
      # binary untouched in libexec/ and installs a bin/ wrapper that
      # execs it through the nix dynamic loader.
      ldsoWrapper ? false
    }:
    assert lib.assertMsg (!(autoPatchelf && ldsoWrapper))
      "mkGithubBinary ${pname}: autoPatchelf and ldsoWrapper are mutually exclusive — patchelfing before wrapping defeats the wrapper's purpose";
    let
      # GitHub release URL format:
      #   Pinned:  /releases/download/${version}/${asset}
      #   Latest:  /releases/latest/download/${asset}
      versionPath = if version == "latest" then "latest/download" else "download/${version}";
      isArchive = builtins.match ".*\\.(tar\\.(gz|bz2|xz)|tgz|zip)$" asset != null;
      isZip = builtins.match ".*\\.zip$" asset != null;
      ldso = "${pkgs.stdenv.cc.libc}/lib/" + ({
        x86_64-linux = "ld-linux-x86-64.so.2";
        aarch64-linux = "ld-linux-aarch64.so.1";
      }.${pkgs.stdenv.hostPlatform.system}
        or (throw "mkGithubBinary: autoPatchelf unsupported on ${pkgs.stdenv.hostPlatform.system}"));
    in
    pkgs.stdenv.mkDerivation {
      inherit pname version;

      postInstall = postInstall + lib.optionalString autoPatchelf ''
        patchelf --set-interpreter "${ldso}" \
          --set-rpath "${lib.makeLibraryPath [ pkgs.stdenv.cc.libc pkgs.stdenv.cc.cc.lib ]}" \
          "$out/bin/${pname}"
      '' + lib.optionalString ldsoWrapper ''
        mkdir -p "$out/libexec"
        mv "$out/bin/${pname}" "$out/libexec/${pname}"
        cat > "$out/bin/${pname}" <<WRAPPER
#!/bin/sh
exec "${ldso}" --library-path "${lib.makeLibraryPath [ pkgs.stdenv.cc.libc pkgs.stdenv.cc.cc.lib ]}" "$out/libexec/${pname}" "\$@"
WRAPPER
        chmod +x "$out/bin/${pname}"
      '';

      src = pkgs.fetchurl {
        url = "https://github.com/${owner}/${repo}/releases/${versionPath}/${asset}";
        inherit sha256;
      };

      # Always skip unpackPhase — installPhase handles extraction for archives.
      dontUnpack = true;
      dontBuild = true;

      # tar/gzip/xz come from stdenv; only .zip archives need unzip.
      nativeBuildInputs = lib.optional isZip pkgs.unzip
        ++ lib.optional autoPatchelf pkgs.patchelf;

      installPhase = ''
        runHook preInstall
        mkdir -p $out/bin
        ${if isArchive then ''
          # Extract archive to a temp dir and find the binary.
          # The archive itself is excluded from the search to avoid
          # matching it as the binary.
          _tmpdir=$(mktemp -d)
          _extractdir="$_tmpdir/extracted"
          mkdir -p "$_extractdir"
          ${if isZip then ''
            unzip "$src" -d "$_extractdir"
          '' else ''
            tar xf "$src" -C "$_extractdir"
          ''}
          # Find the binary: either matches pname or is the only executable.
          # Exclude the archive file itself from the search.
          _bin=$(find "$_extractdir" -type f -name "${pname}" 2>/dev/null | head -1)
          if [[ -z "$_bin" ]]; then
            _bin=$(find "$_extractdir" -type f -name "${pname}-*" 2>/dev/null | head -1)
          fi
          if [[ -z "$_bin" ]]; then
            _bin=$(find "$_extractdir" -type f -executable 2>/dev/null | sort | head -1)
          fi
          if [[ -n "$_bin" ]]; then
            cp "$_bin" $out/bin/${pname}
            chmod +x $out/bin/${pname}
          else
            echo "Error: could not find ${pname} binary in archive ${asset}" >&2
            exit 1
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
    , sha256 ? lib.fakeHash  # accepted for API compatibility; unused — see below
    , postInstall ? ""
    }:
    # All versions produce a runtime npx wrapper: a build-time `npm install`
    # cannot work inside the nix sandbox (no network), and a fixed-output
    # derivation would make the output hash churn on every dep change.
    # "latest" resolves the newest release on every invocation; a pinned
    # version resolves the exact tag — deterministic, and served from the
    # npx cache (~/.npm/_npx) after the first run.
    pkgs.stdenv.mkDerivation {
      inherit pname version postInstall;

      nativeBuildInputs = [ pkgs.nodejs ];

      dontUnpack = true;
      dontBuild = true;

      installPhase = ''
        runHook preInstall
        mkdir -p $out/bin
        cat > $out/bin/${pname} << 'WRAPPER'
#!/bin/sh
exec ${pkgs.nodejs}/bin/npx --yes ${npmName}@${version} "$@"
WRAPPER
        chmod +x $out/bin/${pname}
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
