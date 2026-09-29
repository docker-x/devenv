# dx.tools.paseo — Paseo CLI
# Migrated from: ghcr.io/docker-x/devcontainers/paseo
# Local-first AI development environment with daemon, web UI, and agent orchestration.
# npm package: @getpaseo/cli

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.tools.paseo;

  # Content hash identifying one exact patched web UI — covers the patch
  # template revision plus every value baked into the file (forceTls,
  # allowedHosts). Distinct configs produce distinct filenames, so
  # concurrent devenv shells with different dx.tools.paseo settings write
  # separate files instead of overwriting each other's patched UI.
  paseoPatchId = builtins.substring 0 12 (builtins.hashString "sha256" (builtins.toJSON {
    version = 11;
    forceTls = cfg.forceTls;
    allowedHosts = cfg.allowedHosts;
  }));

  # The Devin ACP provider is only registered when this project also
  # installs the Devin CLI (dx.agents.devin.enable); otherwise Paseo
  # would advertise a provider whose executable is not on PATH, so it is
  # emitted as disabled like the other non-installed providers.
  devinProviderJson =
    if config.dx.agents.devin.enable or false
    then ''"devin": { "extends": "acp", "label": "Devin CLI", "description": "Cognition's Devin for Terminal via Agent Client Protocol", "command": ["devin", "acp"], "env": {} },''
    else ''"devin": { "enabled": false },'';
in
{
  options.dx.tools.paseo = {
    enable = lib.mkEnableOption "Paseo CLI";

    version = lib.mkOption {
      type = lib.types.str;
      default = "latest";
      description = ''
        Version of Paseo CLI to install. "latest" resolves the newest
        release on every invocation; pin an exact version (e.g. "0.9.0")
        for a deterministic build — the npx wrapper then fetches that
        tag once and serves it from the npx cache afterwards.
      '';
    };

    enableRelay = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Enable Paseo relay for remote connections (app.paseo.sh).
        Exported as PASEO_RELAY_ENABLED, a per-launch override that takes
        precedence over the shared per-HOME config.json — so two projects
        with different settings each get their own value without
        rewriting each other's config.
      '';
    };

    enableWebUi = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Serve the bundled web UI from the daemon.
        Exported as PASEO_WEB_UI_ENABLED, a per-launch override that takes
        precedence over the shared per-HOME config.json — so two projects
        with different settings each get their own value without
        rewriting each other's config.
      '';
    };

    forceTls = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Force the web UI daemon-connection hint to advertise TLS (wss/https)
        regardless of request headers or socket state. Enable when the daemon
        sits behind a TLS-terminating proxy that does not set
        X-Forwarded-Proto. Equivalent to exporting FORCE_TLS=true into the
        daemon's environment.
      '';
    };

    allowedHosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "127.0.0.1" "localhost" "[::1]" ];
      description = ''
        Allowlist of hostnames (or host:port pairs) the web UI's
        daemon-connection hint may echo back from the request's Host
        header. Requests whose Host is not listed receive no injected
        hint, which prevents Host header injection into the connection
        hint. The default allows only localhost variants; add your
        public hostname when the daemon is reached through a reverse
        proxy. Setting an empty list accepts any Host — security-
        sensitive, only for deployments where Host is already trusted.
        Entries may also be supplied at runtime via
        PASEO_ALLOWED_HOSTS (comma-separated); the two lists are merged.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    packages = [
      (helpers.mkNpmCli {
        pname = "paseo";
        npmName = "@getpaseo/cli";
        version = cfg.version;
      })
    ];

    # Path of this config's patched web UI, consumed by web-ui-loader.mjs.
    # env values are literal — "$HOME" is not shell-expanded (same
    # convention as dx.core.agentConfig.dir); the loader expands a leading
    # "$HOME"/"~" itself so the var also works for processes that never
    # ran enterShell.
    env.PASEO_WEB_UI_PATCH = "$HOME/.paseo/web-ui-patched-${paseoPatchId}.js";

    # Per-launch relay override. config.json is a shared per-HOME file, so
    # baking enableRelay into it would make projects with different
    # settings rewrite each other's config; the env var is authoritative
    # for daemons launched from this shell instead.
    env.PASEO_RELAY_ENABLED = lib.boolToString cfg.enableRelay;

    # Per-launch web UI override — same shared-config reasoning as
    # PASEO_RELAY_ENABLED above.
    env.PASEO_WEB_UI_ENABLED = lib.boolToString cfg.enableWebUi;

    enterShell = ''
      # dx.tools.paseo: ensure .paseo directory exists
      mkdir -p "$HOME/.paseo"

      # dx.tools.paseo: generate config.json if it doesn't exist or is outdated
      # The config sets relay enablement, web UI serving, MCP injection,
      # terminal agent hooks, and registers the Devin agent provider via
      # ACP when dx.agents.devin is enabled.
      # Uses a version marker so config is regenerated when we update the
      # template. The marker also carries the devin flag so projects
      # sharing ~/.paseo with different dx.agents.devin settings
      # regenerate instead of keeping a stale provider entry.
      # relay.enabled and features.webUi.enabled here are only
      # the fallback for launches outside a devenv shell —
      # PASEO_RELAY_ENABLED/PASEO_WEB_UI_ENABLED (env above) are the
      # authoritative per-project overrides. A stale or missing marker may
      # mean the existing config was customized by the user, so it is
      # preserved in a timestamped config.json.bak.* file rather than
      # silently overwritten.
      PASEO_CONFIG="$HOME/.paseo/config.json"
      PASEO_CONFIG_VERSION="5-${lib.boolToString (config.dx.agents.devin.enable or false)}"
      PASEO_VERSION_FILE="$HOME/.paseo/.config-version"
      CURRENT_VERSION=""
      [ -f "$PASEO_VERSION_FILE" ] && CURRENT_VERSION=$(cat "$PASEO_VERSION_FILE" 2>/dev/null || echo "")
      if [[ ! -f "$PASEO_CONFIG" || "$CURRENT_VERSION" != "$PASEO_CONFIG_VERSION" ]]; then
        # Back up before regenerating: a fresh timestamped destination each
        # run keeps every prior config (not just the last), the copy goes
        # through a PID-unique temp + atomic mv so the .bak file is never
        # observed partially written, and a destination already present as
        # a directory or symlink is rejected rather than written into or
        # through.
        PASEO_BAK="$PASEO_CONFIG.bak.$(date +%Y%m%d%H%M%S)"
        PASEO_BAK_TMP="$PASEO_BAK.tmp.$$"
        if [ -f "$PASEO_CONFIG" ] && {
          [ -e "$PASEO_BAK" ] || [ -L "$PASEO_BAK" ] ||
          ! cp -p "$PASEO_CONFIG" "$PASEO_BAK_TMP" ||
          ! mv -f "$PASEO_BAK_TMP" "$PASEO_BAK";
        }; then
          rm -f "$PASEO_BAK_TMP"
          echo "dx.tools.paseo: could not back up $PASEO_CONFIG; keeping existing config" >&2
        else
          [ -f "$PASEO_CONFIG" ] && echo "dx.tools.paseo: previous config preserved at $PASEO_BAK" >&2
          # Write via PID-unique temp + atomic mv so a concurrent reader
          # never observes a truncated or interleaved config.json. The temp
          # is pre-created with mode 600 — and the write only proceeds if
          # that pre-creation succeeded — so an interrupted write never
          # leaves a world-readable file at umask-default permissions.
          PASEO_CONFIG_TMP="$PASEO_CONFIG.tmp.$$"
          if ! install -m 600 /dev/null "$PASEO_CONFIG_TMP"; then
            echo "dx.tools.paseo: could not create secure temp file $PASEO_CONFIG_TMP; keeping existing config" >&2
          else
          cat > "$PASEO_CONFIG_TMP" << 'PASEOEOF'
{
  "version": 1,
  "daemon": {
    "listen": "127.0.0.1:6767",
    "mcp": {
      "injectIntoAgents": true
    },
    "browserTools": {
      "enabled": true
    },
    "enableTerminalAgentHooks": true,
    "appendSystemPrompt": "Use worktrees for parallel work\nAlways reply with refs (PRs, commits) instead of raw text\nUtilize own paseo capabilities\nAlways pull before starting new branch",
    "cors": {
      "allowedOrigins": [
        "https://app.paseo.sh"
      ]
    },
    "relay": {
      "enabled": ${builtins.toJSON cfg.enableRelay}
    }
  },
  "app": {
    "baseUrl": "https://app.paseo.sh"
  },
  "pluginsEnabled": true,
  "plugins": {},
  "agents": {
    "providers": {
      ${devinProviderJson}
      "pi": { "enabled": false },
      "opencode": { "enabled": false },
      "copilot": { "enabled": false },
      "codex": { "enabled": false },
      "claude": { "enabled": false }
    },
    "skills": {
      "selection": { "mode": "all" }
    }
  },
  "features": {
    "webUi": { "enabled": ${builtins.toJSON cfg.enableWebUi} },
    "dictation": { "enabled": false },
    "voiceMode": { "enabled": false }
  }
}
PASEOEOF
          # $? is cat's status — a failed heredoc must not rename a
          # partial temp into place. A directory at the destination is
          # rejected up front (`mv -f tmp dir` succeeds by moving the
          # temp inside it, so mv's exit status alone is not proof).
          if [ $? -eq 0 ] && [ ! -d "$PASEO_CONFIG" ] && chmod 600 "$PASEO_CONFIG_TMP" && mv -f "$PASEO_CONFIG_TMP" "$PASEO_CONFIG"; then
            echo "$PASEO_CONFIG_VERSION" > "$PASEO_VERSION_FILE"
          else
            rm -f "$PASEO_CONFIG_TMP"
            echo "dx.tools.paseo: could not write $PASEO_CONFIG" >&2
          fi
          fi
        fi
      fi

      # dx.tools.paseo: create workspace directory for projects
      mkdir -p "$HOME/workspace"

      # dx.tools.paseo: patch web UI to inject public host instead of 127.0.0.1
      # The original Paseo web UI hardcodes 127.0.0.1:6767 in the initial
      # daemon connection hint, which doesn't work when accessing the web UI
      # through a reverse proxy (OAuth proxy, OpenShift Route). The patch
      # uses the request's Host header so the browser connects to the
      # public URL, which is proxied back to the daemon.
      #
      # The file is content-addressed (paseoPatchId covers the template
      # revision and the baked-in config) and written once — different
      # projects get different filenames, identical projects share the same
      # immutable file. web-ui-loader.mjs picks the file via
      # PASEO_WEB_UI_PATCH, so a daemon serves the hint policy of the
      # project whose shell spawned it.
      PASEO_PATCHED_FILE="$HOME/.paseo/web-ui-patched-${paseoPatchId}.js"
      if [ ! -f "$PASEO_PATCHED_FILE" ]; then
        # Write via unique temp + atomic mv so concurrent enterShell runs and
        # a racing paseo import never see a partially-written file.
        cat > "$PASEO_PATCHED_FILE.tmp.$$" << 'WUIEOF'
import { createReadStream, readFileSync, statSync } from "node:fs";
import path from "node:path";
const EXCLUDED_PATH_PREFIXES = ["/api/", "/mcp/", "/public/"];
const EXCLUDED_PATHS = new Set(["/api", "/mcp", "/public"]);
const CONFIGURED_ALLOWED_HOSTS = ${builtins.toJSON cfg.allowedHosts};
function isExcludedPath(requestPath) {
    for (const prefix of EXCLUDED_PATH_PREFIXES) {
        if (requestPath.startsWith(prefix)) { return true; }
    }
    return EXCLUDED_PATHS.has(requestPath);
}
const CONTENT_TYPES = {
    ".html": "text/html; charset=utf-8", ".js": "application/javascript; charset=utf-8",
    ".mjs": "application/javascript; charset=utf-8", ".css": "text/css; charset=utf-8",
    ".json": "application/json; charset=utf-8", ".png": "image/png",
    ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".gif": "image/gif",
    ".svg": "image/svg+xml", ".ico": "image/x-icon",
    ".woff": "font/woff", ".woff2": "font/woff2", ".ttf": "font/ttf",
    ".otf": "font/otf", ".eot": "application/vnd.ms-fontobject",
    ".map": "application/json",
};
function getContentType(filePath) {
    const ext = path.extname(filePath).toLowerCase();
    return CONTENT_TYPES[ext] ?? "application/octet-stream";
}
function selectEncoding(acceptEncoding) {
    if (!acceptEncoding) { return null; }
    const qualities = new Map();
    for (const part of acceptEncoding.toLowerCase().split(",")) {
        const [token, ...params] = part.split(";");
        const qMatch = /(?:^|;)\s*q\s*=\s*([^\s;]*)/.exec(";" + params.join(";"));
        const q = qMatch ? Number(qMatch[1]) : 1;
        qualities.set(token.trim(), Number.isFinite(q) && q >= 0 && q <= 1 ? q : 0);
    }
    const wildcard = qualities.get("*") ?? 0;
    const brQ = qualities.get("br") ?? wildcard;
    const gzipQ = qualities.get("gzip") ?? wildcard;
    if (brQ <= 0 && gzipQ <= 0) { return null; }
    return brQ >= gzipQ ? "br" : "gzip";
}
function isHashedAsset(filePath) {
    const base = path.basename(filePath);
    return /[-.][0-9a-f]{16,}[-.]/i.test(base);
}
function isInsideDir(targetPath, dirPath) {
    const resolvedDir = path.resolve(dirPath);
    const resolvedTarget = path.resolve(targetPath);
    return resolvedTarget === resolvedDir || resolvedTarget.startsWith(resolvedDir + path.sep);
}
function safeStat(filePath) {
    try { return statSync(filePath); } catch { return null; }
}
function resolveTargetFile(distDir, requestPath) {
    const safePath = path.normalize(requestPath).replace(/^(\.\.[/\\])+/, "");
    let filePath = path.join(distDir, safePath);
    const stat = safeStat(filePath);
    if (stat?.isDirectory()) { filePath = path.join(filePath, "index.html"); }
    const finalStat = safeStat(filePath);
    if (!finalStat?.isFile()) {
        filePath = path.join(distDir, "index.html");
        const fallbackStat = safeStat(filePath);
        if (!fallbackStat?.isFile()) { return null; }
    }
    if (!isInsideDir(filePath, distDir)) { return null; }
    const resolvedFile = path.resolve(filePath);
    const isIndexHtml = path.basename(resolvedFile).toLowerCase() === "index.html";
    return { resolvedFile, isIndexHtml };
}
function resolveContentEncoding(resolvedFile, acceptEncoding) {
    const encoding = selectEncoding(acceptEncoding);
    if (!encoding) { return { finalFile: resolvedFile, contentEncoding: null }; }
    const compressedFile = `''\${resolvedFile}.''\${encoding === "br" ? "br" : "gz"}`;
    const compressedStat = safeStat(compressedFile);
    if (compressedStat?.isFile()) { return { finalFile: compressedFile, contentEncoding: encoding }; }
    return { finalFile: resolvedFile, contentEncoding: null };
}
function setResponseCacheHeaders(res, isIndexHtml, resolvedFile) {
    if (isIndexHtml) {
        res.setHeader("Cache-Control", "no-store, no-cache, must-revalidate, proxy-revalidate");
        res.setHeader("Pragma", "no-cache");
        res.setHeader("Expires", "0");
    } else if (isHashedAsset(resolvedFile)) {
        res.setHeader("Cache-Control", "public, max-age=31536000, immutable");
    } else {
        res.setHeader("Cache-Control", "no-cache");
    }
}
export function createWebUiMiddleware(options) {
    const { enabled, distDir, label, logger } = options;
    const childLogger = logger.child({ module: "web-ui" });
    if (!enabled || !distDir) {
        childLogger.info({ enabled, hasDistDir: !!distDir }, "Daemon web UI disabled or missing dist directory");
    } else {
        childLogger.info({ distDir }, "Daemon web UI mounted");
    }
    return (req, res, next) => {
        if (req.method !== "GET" && req.method !== "HEAD") { next(); return; }
        if (isExcludedPath(req.path)) { next(); return; }
        if (!enabled || !distDir) { res.status(404).end(); return; }
        serveWebUiFile({ distDir, requestPath: req.path, label, req, res });
    };
}
function serveWebUiFile(options) {
    const { distDir, requestPath, label, req, res } = options;
    const target = resolveTargetFile(distDir, requestPath);
    if (!target) { res.status(404).end(); return; }
    const { resolvedFile, isIndexHtml } = target;
    const acceptEncoding = isIndexHtml ? undefined : req.headers["accept-encoding"];
    const { finalFile, contentEncoding } = resolveContentEncoding(resolvedFile, acceptEncoding);
    res.setHeader("Content-Type", getContentType(resolvedFile));
    if (contentEncoding) {
        res.setHeader("Content-Encoding", contentEncoding);
        res.setHeader("Vary", "Accept-Encoding");
    }
    setResponseCacheHeaders(res, isIndexHtml, resolvedFile);
    if (req.method === "HEAD") { res.status(200).end(); return; }
    if (isIndexHtml) { sendIndexHtml(res, finalFile, req, label); return; }
    const stream = createReadStream(finalFile);
    stream.on("error", () => {
        if (!res.headersSent) { res.status(500).end(); } else { res.end(); }
    });
    stream.pipe(res);
}
function sendIndexHtml(res, filePath, req, label) {
    try {
        const html = readFileSync(filePath, "utf-8");
        const injected = injectConnectionHint(html, req, label);
        res.status(200).send(injected);
    } catch {
        res.status(500).end();
    }
}
function serializeInlineScriptJson(value) {
    return JSON.stringify(value)
        .replace(/</g, "\\u003C")
        .replace(/>/g, "\\u003E")
        .replace(/&/g, "\\u0026")
        .replace(/'/g, "\\u0027");
}
function injectConnectionHint(html, req, label) {
    // The Host header is client-controlled; echoing it unvalidated into the
    // connection hint enables Host header injection (CWE-644). When an
    // allowlist is configured (dx.tools.paseo.allowedHosts and/or the
    // PASEO_ALLOWED_HOSTS env var), a non-listed Host skips the injection
    // entirely so the UI falls back to its default daemon address.
    const allowedHosts = CONFIGURED_ALLOWED_HOSTS
        .concat((process.env.PASEO_ALLOWED_HOSTS || "").split(","))
        .map(h => h.trim().toLowerCase().replace(/^\[([^\]]+)\]$/, "$1"))
        .filter(Boolean);
    const requestHost = (typeof req.headers.host === "string" ? req.headers.host : "").trim().toLowerCase();
    const bracketedIp = /^\[([0-9a-f:.%]+)\](?::\d+)?$/i.exec(requestHost);
    const requestHostname = requestHost.startsWith("[")
        ? (bracketedIp ? bracketedIp[1] : requestHost)
        : (/^[^:]+:\d+$/.test(requestHost) ? requestHost.replace(/:\d+$/, "") : requestHost);
    if (!requestHost
        || (allowedHosts.length > 0 && !allowedHosts.includes(requestHost) && !allowedHosts.includes(requestHostname))) {
        return html;
    }
    const host = requestHost;
    const forwardedProto = req.headers["x-forwarded-proto"];
    const proto = (Array.isArray(forwardedProto) ? forwardedProto[0] : forwardedProto)?.split(",")[0].trim().toLowerCase();
    // A locally encrypted socket decides (the peer spoke TLS); only a
    // plain socket trusts X-Forwarded-Proto, since a direct client could
    // otherwise spoof the scheme. FORCE_TLS (or dx.tools.paseo.forceTls)
    // overrides for proxies that terminate TLS without setting the header.
    const useTls = ${if cfg.forceTls then "true" else "false"}
        || process.env.FORCE_TLS === "true"
        || req.socket?.encrypted === true
        || proto === "https";
    const defaultPort = useTls ? 443 : 80;
    const hostWithPort = host.includes(":") ? host : host + ":" + defaultPort;
    const hint = { listen: hostWithPort, useTls, label };
    const script = `<script>window.__PASEO_INITIAL_DAEMON_CONNECTION__=''\${serializeInlineScriptJson(hint)}</script>`;
    const headClose = /<\/head>/i;
    if (headClose.test(html)) { return html.replace(headClose, () => `''\${script}</head>`); }
    return script + html;
}
//# sourceMappingURL=web-ui.js.map
WUIEOF
        # $? is cat's status — a failed heredoc must not rename a partial
        # temp into place; file existence is the write-once guard, so a
        # partial file would be served permanently. A directory at the
        # destination is rejected up front: `mv -f tmp dir` succeeds by
        # moving the temp inside it, which is not a successful write.
        if [ $? -ne 0 ] || [ -d "$PASEO_PATCHED_FILE" ] || ! mv -f "$PASEO_PATCHED_FILE.tmp.$$" "$PASEO_PATCHED_FILE"; then
          rm -f "$PASEO_PATCHED_FILE.tmp.$$"
          echo "dx.tools.paseo: could not write $PASEO_PATCHED_FILE" >&2
        fi
      fi

      # The loader is config-free and shared by all projects: it forwards
      # paseo's web-ui module to $PASEO_WEB_UI_PATCH (set per project via
      # env above) and expands a leading "$HOME"/"~" so the literal env
      # value resolves. It fails closed — when the var is unset or the
      # file is absent, the upstream module passes through unpatched
      # rather than falling back to a shared path that could carry
      # another project's hint policy. Rewritten only when missing or
      # still on an older loader revision.
      PASEO_LOADER_VERSION="4"
      PASEO_LOADER_FILE="$HOME/.paseo/web-ui-loader.mjs"
      PASEO_LOADER_VERSION_FILE="$HOME/.paseo/.web-ui-loader-version"
      CURRENT_LOADER_VERSION=""
      [ -f "$PASEO_LOADER_VERSION_FILE" ] && CURRENT_LOADER_VERSION=$(cat "$PASEO_LOADER_VERSION_FILE" 2>/dev/null || echo "")
      if [ ! -f "$PASEO_LOADER_FILE" ] || [ "$CURRENT_LOADER_VERSION" != "$PASEO_LOADER_VERSION" ]; then
        cat > "$PASEO_LOADER_FILE.tmp.$$" << 'LOADEREOF'
import { existsSync } from "node:fs";
export async function resolve(specifier, context, nextResolve) {
  const result = await nextResolve(specifier, context);
  if (result.url && result.url.includes("server/server/web-ui.js") && result.url.includes("@getpaseo")) {
    const configured = process.env.PASEO_WEB_UI_PATCH;
    if (!configured) { return result; }
    const patched = expandHome(configured);
    if (!existsSync(patched)) { return result; }
    return { url: "file://" + patched, shortCircuit: true };
  }
  return result;
}
function expandHome(p) {
  const home = process.env.HOME || "";
  if (p === "~" || p.startsWith("~/") || p === "$HOME" || p.startsWith("$HOME/")) {
    if (!home) { return p; }
    return home + p.replace(/^(~|\$HOME)/, "");
  }
  return p;
}
LOADEREOF
        # $? is cat's status — a failed heredoc must not mark a partial
        # loader as the current version. A directory at the destination
        # is rejected up front (`mv -f tmp dir` succeeds by moving the
        # temp inside it, so mv's exit status alone is not proof).
        if [ $? -eq 0 ] && [ ! -d "$PASEO_LOADER_FILE" ] && mv -f "$PASEO_LOADER_FILE.tmp.$$" "$PASEO_LOADER_FILE"; then
          echo "$PASEO_LOADER_VERSION" > "$PASEO_LOADER_VERSION_FILE"
        else
          rm -f "$PASEO_LOADER_FILE.tmp.$$"
          echo "dx.tools.paseo: could not write $PASEO_LOADER_FILE" >&2
        fi
      fi

      # dx.tools.paseo: sweep temp files orphaned by interrupted runs.
      # Age-gated — a blanket glob sweep could unlink a concurrent
      # enterShell's in-progress temp and make its mv fail. The 60-minute
      # horizon keeps the window unreachable for a stalled writer while
      # still sweeping orphans promptly. Backup temps are gated on ctime
      # (-cmin) not mtime: `cp -p` preserves the source mtime, so a backup
      # temp for an old config is born "old" by mtime and would be swept
      # mid-cp; its ctime is always fresh.
      find "$HOME/.paseo" -maxdepth 1 \( \( -name 'web-ui-*.tmp.*' -o -name 'config.json.tmp.*' \) -mmin +60 -o -name 'config.json.bak.*.tmp.*' -cmin +60 \) -delete 2>/dev/null || true
    '';
  };
}
