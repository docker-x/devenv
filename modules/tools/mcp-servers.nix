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

    jq -r 'to_entries[] | select(.value | type != "object") | .key' "$REGISTRY_FILE" \
      | while IFS= read -r skipped_name; do
          echo "configure-mcp: skipping $skipped_name: registry entry is not an object" >&2
        done
    OBJECT_KEYS=$(jq -r 'to_entries[] | select(.value | type == "object") | .key' "$REGISTRY_FILE")

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
        trap 'rm -f "$tmp_file"' EXIT

        if ! jq -e '.mcpServers' "$config_file" >/dev/null 2>&1; then
          tmp=$(jq '. + {"mcpServers": {}}' "$config_file")
          echo "$tmp" > "$tmp_file" && chmod "$old_mode" "$tmp_file" && mv "$tmp_file" "$config_file"
        fi

        tmp=$(jq --arg name "$server_name" --argjson entry "$entry_json" \
          '.mcpServers[$name] = $entry' "$config_file")
        echo "$tmp" > "$tmp_file" && chmod "$old_mode" "$tmp_file" && mv "$tmp_file" "$config_file"
      ) 200>"$lock_file"
    }

    merge_into_toml() {
      local config_file="$1" server_name="$2" entry_json="$3"
      local toml_key lock_file="''${config_file}.lock"

      toml_key=$(printf '%s' "$server_name" | jq -Rr '@json')

      mkdir -p "$(dirname "$config_file")"

      (
        flock -x 200

        if [ ! -f "$config_file" ]; then
          touch "$config_file"
        fi

        local header="[mcp_servers.$toml_key]" prefix="[mcp_servers.$toml_key."
        local bare_header="" bare_prefix=""
        if printf '%s' "$server_name" | grep -qE '^[A-Za-z0-9_-]+$'; then
          bare_header="[mcp_servers.$server_name]"
          bare_prefix="[mcp_servers.$server_name."
        fi

        local old_mode tmp_file="''${config_file}.tmp.$$"
        old_mode=$(stat -c '%a' "$config_file" 2>/dev/null || echo "644")
        trap 'rm -f "$tmp_file"' EXIT

        HEADER="$header" BARE_HEADER="$bare_header" \
          PREFIX="$prefix" BARE_PREFIX="$bare_prefix" \
          awk '
          BEGIN { dq = 0; sq = 0; ml = ""; pending = 0 }
          function cut_comment(s,   i, c) {
            for (i = 1; i <= length(s); i++) {
              c = substr(s, i, 1)
              if (ml != "") {
                if (substr(s, i, 3) == ml) { ml = ""; i += 2 }
                continue
              }
              if (dq == 0 && sq == 0 && substr(s, i, 3) == "\"\"\"") { ml = "\"\"\""; i += 2; continue }
              if (dq == 0 && sq == 0 && substr(s, i, 3) == "\047\047\047") { ml = "\047\047\047"; i += 2; continue }
              if (dq && c == "\\") { i++; continue }
              if (c == "\"" && sq == 0) { dq = !dq; continue }
              if (c == "\047" && dq == 0) { sq = !sq; continue }
              if (c == "#" && dq == 0 && sq == 0) return substr(s, 1, i - 1)
            }
            return s
          }
          {
            in_str = (ml != "")
            line = cut_comment($0)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
            if (!in_str && substr(line, 1, 1) == "[") {
              p = index(line, ENVIRON["PREFIX"])
              q = index(line, ENVIRON["BARE_PREFIX"])
              skip = (line == ENVIRON["HEADER"] ||
                (ENVIRON["BARE_HEADER"] != "" && line == ENVIRON["BARE_HEADER"]) ||
                p == 1 || p == 2 ||
                (ENVIRON["BARE_PREFIX"] != "" && (q == 1 || q == 2)))
            }
            if (!skip) {
              if ($0 ~ /^[[:space:]]*$/) { pending++ }
              else { for (i = 0; i < pending; i++) print ""; pending = 0; print }
            }
          }
        ' "$config_file" > "$tmp_file"
        chmod "$old_mode" "$tmp_file"

        local serialized
        serialized=$(echo "$entry_json" | jq -r '
          def toml_value:
            if type == "object" then
              "{ " + ([to_entries[] | select(.value != null)
                | (.key | @json) + " = " + (.value | toml_value)] | join(", ")) + " }"
            elif type == "array" then
              "[" + ([.[] | select(. != null) | toml_value] | join(", ")) + "]"
            elif type == "string" then @json
            else tostring end;
          (if (.headers | type) == "object" then
             .http_headers = (.headers + (.http_headers // {}))
           else . end)
          | ((if .command != null
              then ["command", "args", "env", "env_vars", "cwd"]
              else ["url", "bearer_token", "bearer_token_env_var", "http_headers", "env_http_headers"] end)
             + ["enabled", "required", "startup_timeout_sec", "startup_timeout_ms",
                "tool_timeout_sec", "enabled_tools", "disabled_tools", "scopes"]) as $keys
          | $keys[] as $k
          | select(.[$k] != null)
          | "\($k) = \(.[$k] | toml_value)"
        ' 2>/dev/null) || serialized=""

        if [ -n "$serialized" ]; then
          {
            if [ -s "$tmp_file" ]; then echo ""; fi
            echo "[mcp_servers.$toml_key]"
            echo "$serialized"
          } >> "$tmp_file"
        else
          echo "configure-mcp: skipping $server_name: no serializable Codex fields" >&2
        fi
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
        [ -n "$server_name" ] || continue;
        entry=$(jq -c --arg name "$server_name" '.[$name]' "$REGISTRY_FILE")
        has_url=$(echo "$entry" | jq -r 'has("url")')
        if [ "$has_url" = "true" ]; then
          adapted=$(echo "$entry" | jq -c '. + {"type": "http"}')
        else
          adapted="$entry"
        fi
        merge_into_json "$claude_config" "$server_name" "$adapted"
      done <<< "$OBJECT_KEYS"
    }

    apply_codex() {
      local codex_config="$HOME/.codex/config.toml"
      if ! command -v codex >/dev/null 2>&1 && [ ! -f "$codex_config" ]; then
        return 0
      fi
      echo "configure-mcp: configuring Codex"
      while IFS= read -r server_name; do
        [ -n "$server_name" ] || continue;
        entry=$(jq -c --arg name "$server_name" '.[$name]' "$REGISTRY_FILE")
        merge_into_toml "$codex_config" "$server_name" "$entry"
      done <<< "$OBJECT_KEYS"
    }

    apply_devin() {
      local devin_config="$HOME/.config/devin/mcp_config.json"
      if ! command -v devin >/dev/null 2>&1 && [ ! -f "$devin_config" ]; then
        return 0
      fi
      echo "configure-mcp: configuring Devin"
      while IFS= read -r server_name; do
        [ -n "$server_name" ] || continue;
        entry=$(jq -c --arg name "$server_name" '.[$name]' "$REGISTRY_FILE")
        has_url=$(echo "$entry" | jq -r 'has("url")')
        if [ "$has_url" = "true" ]; then
          adapted=$(echo "$entry" | jq -c '. + {"transport": "http"}')
        else
          adapted="$entry"
        fi
        merge_into_json "$devin_config" "$server_name" "$adapted"
      done <<< "$OBJECT_KEYS"
    }

    apply_cursor() {
      local cursor_config="$HOME/.cursor/mcp.json"
      if ! command -v cursor >/dev/null 2>&1 && [ ! -f "$cursor_config" ]; then
        return 0
      fi
      echo "configure-mcp: configuring Cursor"
      while IFS= read -r server_name; do
        [ -n "$server_name" ] || continue;
        entry=$(jq -c --arg name "$server_name" '.[$name]' "$REGISTRY_FILE")
        merge_into_json "$cursor_config" "$server_name" "$entry"
      done <<< "$OBJECT_KEYS"
    }

    apply_copilot() {
      local copilot_config="$HOME/.copilot/mcp-config.json"
      if ! command -v copilot >/dev/null 2>&1 && [ ! -f "$copilot_config" ]; then
        return 0
      fi
      echo "configure-mcp: configuring GitHub Copilot"
      while IFS= read -r server_name; do
        [ -n "$server_name" ] || continue;
        entry=$(jq -c --arg name "$server_name" '.[$name]' "$REGISTRY_FILE")
        has_url=$(echo "$entry" | jq -r 'has("url")')
        if [ "$has_url" = "true" ]; then
          adapted=$(echo "$entry" | jq -c '. + {"type": "http"}')
        else
          adapted=$(echo "$entry" | jq -c '. + {"type": "local"}')
        fi
        merge_into_json "$copilot_config" "$server_name" "$adapted"
      done <<< "$OBJECT_KEYS"
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
        Registry entries are authoritative: a same-named entry in the agent
        config is replaced, so registry changes propagate on the next run.
        For Codex (config.toml) all fields supported by its transport schema
        are written; `headers` maps to `http_headers` on url servers. Fields
        Codex does not support for a transport are omitted.
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
