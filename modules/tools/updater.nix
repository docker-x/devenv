# dx.tools.updater — `devenv-update-all` dispatcher
#
# Two update domains coexist in a devenv shell:
#
#   * Store-baked tools (mkGithubBinary / mkNpmCli wrappers, pinned
#     versions) — immutable at runtime. The updater reports their drift
#     ("pinned X, latest Y") and points at the real update path
#     (bump the option / `devenv update` + rebuild).
#   * Runtime-installed tools — script installers (devin), npx `latest`
#     wrappers, npm/bun globals, Homebrew — updatable in place.
#
# Other modules register per-tool entries:
#
#   dx.tools.updater.entries = [{
#     name    = "devin";
#     current = "devin --version 2>/dev/null | head -1";   # prints installed version
#     latest  = "curl -fsSL ... | jq -r .version";          # prints latest version
#     update  = "curl -fsSL .../install.sh | bash";         # omit for report-only
#   }];

{ lib, config, pkgs, ... }:

let
  cfg = config.dx.tools.updater;

  entryType = lib.types.submodule {
    options = {
      name = lib.mkOption { type = lib.types.str; description = "Tool/display name."; };
      current = lib.mkOption {
        type = lib.types.str;
        default = "echo unknown";
        description = "Shell snippet printing the installed version.";
      };
      latest = lib.mkOption {
        type = lib.types.str;
        description = "Shell snippet printing the latest upstream version.";
      };
      update = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Shell snippet performing the in-place update. Empty = report-only (store-pinned).";
      };
    };
  };

  entryArrays = ''
    ${lib.concatMapStrings (e: ''
      _names+=( ${lib.escapeShellArg e.name} )
      _currents+=( ${lib.escapeShellArg e.current} )
      _latests+=( ${lib.escapeShellArg e.latest} )
      _updates+=( ${lib.escapeShellArg e.update} )
    '') cfg.entries}
  '';

  updateAll = pkgs.writeShellScriptBin "devenv-update-all" ''
    set -u
    CHECK_ONLY=0
    for arg in "$@"; do
      case "$arg" in
        --check|-n) CHECK_ONLY=1 ;;
        -h|--help) echo "usage: devenv-update-all [--check]"; exit 0 ;;
        *) echo "devenv-update-all: unknown flag '$arg'" >&2; exit 2 ;;
      esac
    done

    _names=() _currents=() _latests=() _updates=()
    ${entryArrays}

    _n_ok=0 _n_upd=0 _n_pin=0 _n_fail=0
    _row() { printf '%-18s %-14s %-14s %s\n' "$1" "$2" "$3" "$4"; }

    _sweep() { # name current_cmd latest_cmd update_cmd
      local name="$1" cur_cmd="$2" lat_cmd="$3" upd_cmd="$4" cur latest
      cur=$(eval "$cur_cmd" 2>/dev/null | tail -1)
      latest=$(eval "$lat_cmd" 2>/dev/null | tail -1)
      [ -z "$latest" ] && latest="?"
      if [ -n "$cur" ] && [ "$cur" = "$latest" ]; then
        _row "$name" "$cur" "$latest" "up to date"; _n_ok=$((_n_ok+1)); return
      fi
      if [ -z "$upd_cmd" ]; then
        _row "$name" "''${cur:-?}" "$latest" "pinned — bump devenv option + rebuild"; _n_pin=$((_n_pin+1)); return
      fi
      if [ "$CHECK_ONLY" -eq 1 ]; then
        _row "$name" "''${cur:-?}" "$latest" "would update"; _n_pin=$((_n_pin+1)); return
      fi
      if eval "$upd_cmd" >/dev/null 2>&1; then
        _row "$name" "''${cur:-?}" "$latest" "updated"; _n_upd=$((_n_upd+1))
      else
        _row "$name" "''${cur:-?}" "$latest" "FAILED"; _n_fail=$((_n_fail+1))
      fi
    }

    echo "== declarative entries =="
    _row TOOL CURRENT LATEST ACTION
    for i in "''${!_names[@]}"; do
      _sweep "''${_names[$i]}" "''${_currents[$i]}" "''${_latests[$i]}" "''${_updates[$i]}"
    done
    [ "''${#_names[@]}" -eq 0 ] && echo "(none registered)"

    # ---- auto-discovery: mkNpmCli npx wrappers ----
    echo
    echo "== npx wrappers (mkNpmCli) =="
    _row TOOL CURRENT LATEST ACTION
    _profile="''${DEVENV_PROFILE:-$HOME/.nix-profile}"
    _found=0
    if command -v npm >/dev/null 2>&1 && [ -d "$_profile/bin" ]; then
      for f in "$_profile"/bin/*; do
        spec=$(sed -n "s|.*npx --yes '\([^']*\)'.*|\1|p" "$f" 2>/dev/null | head -1)
        [ -z "$spec" ] && continue
        _found=1
        pkg="''${spec%@*}"; ver="''${spec##*@}"
        [ "$pkg" = "$spec" ] && { pkg="$spec"; ver="latest"; }
        name=$(basename "$f")
        if [ "$ver" = "latest" ]; then
          # Wrapper always resolves the latest tag — never invoke the tool
          # (npx fetch is heavy); "update" just re-warms the npx cache.
          _sweep "$name" "echo latest" "npm view '$pkg' version 2>/dev/null" \
            "npm exec --yes --prefer-online --package '$pkg@latest' -- true"
        else
          _sweep "$name" "echo $ver" "npm view '$pkg' version 2>/dev/null" ""
        fi
      done
    fi
    [ "$_found" -eq 0 ] && echo "(no npx wrappers found or npm missing)"

    # ---- package-manager sweeps ----
    if command -v brew >/dev/null 2>&1; then
      echo
      echo "== homebrew =="
      brew update >/dev/null 2>&1 || true
      _out=$(brew outdated 2>/dev/null || true)
      if [ -z "$_out" ]; then echo "(all brew packages current)"; _n_ok=$((_n_ok+1));
      elif [ "$CHECK_ONLY" -eq 1 ]; then echo "$_out"; _n_pin=$((_n_pin+1));
      elif brew upgrade >/dev/null 2>&1; then echo "brew: upgraded"; _n_upd=$((_n_upd+1));
      else echo "brew: upgrade FAILED"; _n_fail=$((_n_fail+1)); fi
    fi
    if command -v npm >/dev/null 2>&1; then
      _out=$(npm outdated -g --parseable 2>/dev/null || true)
      if [ -n "$_out" ]; then
        echo
        echo "== npm globals =="
        echo "$_out" | awk -F: '{print $3}' | sort -u
        if [ "$CHECK_ONLY" -eq 0 ] && npm update -g >/dev/null 2>&1; then
          _n_upd=$((_n_upd+1)); echo "npm -g: updated"
        fi
      fi
    fi

    echo
    printf 'summary: %d current, %d updated, %d pinned/report-only, %d failed\n' "$_n_ok" "$_n_upd" "$_n_pin" "$_n_fail"
    [ "$_n_fail" -eq 0 ]
  '';
in
{
  options.dx.tools.updater = {
    enable = lib.mkEnableOption "devenv-update-all — multi-source tool updater";

    entries = lib.mkOption {
      type = lib.types.listOf entryType;
      default = [ ];
      description = ''
        Per-tool update entries registered by other modules. `update` empty
        means the tool is store-pinned — reported as drift only.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    packages = [ updateAll ];
  };
}
