# dx.tools.mcpServers — MCP server registry applier
# Migrated from: ghcr.io/docker-x/devcontainers/mcp-servers
# Installs configure-mcp.sh — an idempotent applier that merges a JSON
# registry of MCP servers into each detected agent's native config.
# Runs from enterShell (the devenv equivalent of postStartCommand) so
# agent configs on the PVC get populated on container start.

{ lib, config, pkgs, ... }:

let
  cfg = config.dx.tools.mcpServers;

  registryFile = pkgs.writeText "mcp-servers.json" (builtins.toJSON cfg.servers);

  configureMcp = pkgs.writeShellScriptBin "configure-mcp.sh" ''
    set -euo pipefail
    export PATH="${lib.makeBinPath [ pkgs.jq pkgs.util-linux pkgs.gawk pkgs.gnugrep pkgs.coreutils ]}:$PATH"

    REGISTRY_FILE="${registryFile}"
    export HOME="''${HOME:-/env}"

    if ! command -v jq >/dev/null 2>&1; then
      echo "configure-mcp: jq not available, skipping"
      exit 0
    fi

    SERVER_COUNT=$(jq -r 'length' "$REGISTRY_FILE" 2>/dev/null || echo "0")
    if [ "$SERVER_COUNT" = "0" ]; then
      echo "configure-mcp: no servers in registry, skipping"
      exit 0
    fi

    echo "configure-mcp: applying $SERVER_COUNT servers from $REGISTRY_FILE"

    merge_into_json() {
      local config_file="$1" server_name="$2" entry_json="$3"
      local tmp tmp_file old_mode lock_file="''${config_file}.lock"

      mkdir -p "$(dirname "$config_file")"

      (
        flock -x 200

        if [ ! -f "$config_file" ]; then
          echo '{"mcpServers": {}}' > "$config_file"
        fi

        old_mode=$(stat -c '%a' "$config_file" 2>/dev/null || echo "644")
        tmp_file="''${config_file}.tmp.$$"

        if ! jq -e '.mcpServers' "$config_file" >/dev/null 2>&1; then
          tmp=$(jq '. + {"mcpServers": {}}' "$config_file")
          echo "$tmp" > "$tmp_file" && chmod "$old_mode" "$tmp_file" && mv "$tmp_file" "$config_file"
        fi

        if jq -e --arg name "$server_name" '.mcpServers[$name]' "$config_file" >/dev/null 2>&1; then
          : # already exists, skip
        else
          tmp=$(jq --arg name "$server_name" --argjson entry "$entry_json" \
            '.mcpServers[$name] = $entry' "$config_file")
          echo "$tmp" > "$tmp_file" && chmod "$old_mode" "$tmp_file" && mv "$tmp_file" "$config_file"
        fi
      ) 200>"$lock_file"
    }

    merge_into_toml() {
      local config_file="$1" server_name="$2" entry_json="$3"
      local has_url has_command toml_key lock_file="''${config_file}.lock"

      has_url=$(echo "$entry_json" | jq -r 'has("url")')
      has_command=$(echo "$entry_json" | jq -r 'has("command")')
      toml_key=$(printf '%s' "$server_name" | jq -Rr '@json')

      mkdir -p "$(dirname "$config_file")"

      (
        flock -x 200

        if [ ! -f "$config_file" ]; then
          touch "$config_file"
        fi

        local header="[mcp_servers.$toml_key]"
        local bare_header=""
        if printf '%s' "$server_name" | grep -qE '^[A-Za-z0-9_-]+$'; then
          bare_header="[mcp_servers.$server_name]"
        fi
        if HEADER="$header" BARE_HEADER="$bare_header" awk '
          { sub(/#.*$/, ""); gsub(/^[[:space:]]+|[[:space:]]+$/, ""); if ($0 == ENVIRON["HEADER"] || (ENVIRON["BARE_HEADER"] != "" && $0 == ENVIRON["BARE_HEADER"])) { found = 1; exit } }
          END { exit !found }
        ' "$config_file" 2>/dev/null; then
          return 0
        fi

        local tmp_file="''${config_file}.tmp.$$"
        cp -p "$config_file" "$tmp_file"
        {
          echo ""
          echo "[mcp_servers.$toml_key]"
          if [ "$has_url" = "true" ]; then
            echo "$entry_json" | jq -r '"url = " + (.url | @json)'
          fi
          if [ "$has_command" = "true" ]; then
            echo "$entry_json" | jq -r '"command = " + (.command | @json)'
            echo "$entry_json" | jq -r 'if .args then "args = [" + ([.args[] | @json] | join(", ")) + "]" else empty end'
            echo "$entry_json" | jq -r 'if .env then "env = { " + ([.env | to_entries[] | (.key | @json) + " = " + (.value | @json)] | join(", ")) + " }" else empty end' 2>/dev/null || true
          fi
        } >> "$tmp_file"
        mv "$tmp_file" "$config_file"
      ) 200>"$lock_file"
    }

    apply_claude() {
      local claude_config="$HOME/.claude.json"
      if ! command -v claude >/dev/null 2>&1 && [ ! -f "$claude_config" ]; then
        return 0
      fi
      echo "configure-mcp: configuring Claude Code"
      while IFS= read -r server_name; do
        entry=$(jq -c --arg name "$server_name" '.[$name]' "$REGISTRY_FILE")
        has_url=$(echo "$entry" | jq -r 'has("url")')
        if [ "$has_url" = "true" ]; then
          adapted=$(echo "$entry" | jq -c '. + {"type": "http"}')
        else
          adapted="$entry"
        fi
        merge_into_json "$claude_config" "$server_name" "$adapted"
      done < <(jq -r 'keys[]' "$REGISTRY_FILE")
    }

    apply_codex() {
      local codex_config="$HOME/.codex/config.toml"
      if ! command -v codex >/dev/null 2>&1 && [ ! -f "$codex_config" ]; then
        return 0
      fi
      echo "configure-mcp: configuring Codex"
      while IFS= read -r server_name; do
        entry=$(jq -c --arg name "$server_name" '.[$name]' "$REGISTRY_FILE")
        merge_into_toml "$codex_config" "$server_name" "$entry"
      done < <(jq -r 'keys[]' "$REGISTRY_FILE")
    }

    apply_devin() {
      local devin_config="$HOME/.config/devin/mcp_config.json"
      if ! command -v devin >/dev/null 2>&1 && [ ! -f "$devin_config" ]; then
        return 0
      fi
      echo "configure-mcp: configuring Devin"
      while IFS= read -r server_name; do
        entry=$(jq -c --arg name "$server_name" '.[$name]' "$REGISTRY_FILE")
        has_url=$(echo "$entry" | jq -r 'has("url")')
        if [ "$has_url" = "true" ]; then
          adapted=$(echo "$entry" | jq -c '. + {"transport": "http"}')
        else
          adapted="$entry"
        fi
        merge_into_json "$devin_config" "$server_name" "$adapted"
      done < <(jq -r 'keys[]' "$REGISTRY_FILE")
    }

    apply_cursor() {
      local cursor_config="$HOME/.cursor/mcp.json"
      if ! command -v cursor >/dev/null 2>&1 && [ ! -f "$cursor_config" ]; then
        return 0
      fi
      echo "configure-mcp: configuring Cursor"
      while IFS= read -r server_name; do
        entry=$(jq -c --arg name "$server_name" '.[$name]' "$REGISTRY_FILE")
        merge_into_json "$cursor_config" "$server_name" "$entry"
      done < <(jq -r 'keys[]' "$REGISTRY_FILE")
    }

    apply_copilot() {
      local copilot_config="$HOME/.copilot/mcp-config.json"
      if ! command -v copilot >/dev/null 2>&1 && [ ! -f "$copilot_config" ]; then
        return 0
      fi
      echo "configure-mcp: configuring GitHub Copilot"
      while IFS= read -r server_name; do
        entry=$(jq -c --arg name "$server_name" '.[$name]' "$REGISTRY_FILE")
        has_url=$(echo "$entry" | jq -r 'has("url")')
        if [ "$has_url" = "true" ]; then
          adapted=$(echo "$entry" | jq -c '. + {"type": "http"}')
        else
          adapted=$(echo "$entry" | jq -c '. + {"type": "local"}')
        fi
        merge_into_json "$copilot_config" "$server_name" "$adapted"
      done < <(jq -r 'keys[]' "$REGISTRY_FILE")
    }

    apply_claude
    apply_codex
    apply_devin
    apply_cursor
    apply_copilot

    echo "configure-mcp: done"
  '';
in
{
  options.dx.tools.mcpServers = {
    enable = lib.mkEnableOption "MCP server registry applier (configure-mcp.sh)";

    servers = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = ''
        MCP server registry. Entries with a `url` key are remote (HTTP/SSE)
        servers; entries with a `command` key are local (stdio) servers.
        Merged into each detected agent's native config on shell entry.
      '';
      example = {
        deepwiki = { url = "https://mcp.deepwiki.com/mcp"; };
      };
    };

    runOnShellEnter = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Apply the registry on every devenv shell entry (idempotent; mirrors postStartCommand).";
    };
  };

  config = lib.mkIf cfg.enable {
    packages = [ configureMcp pkgs.jq ];

    enterShell = lib.optionalString cfg.runOnShellEnter ''
      configure-mcp.sh || true
    '';
  };
}
