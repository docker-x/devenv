# dx.tools.paseo — Paseo CLI
# Migrated from: ghcr.io/docker-x/devcontainers/paseo
# Local-first AI development environment with daemon, web UI, and agent orchestration.
# npm package: @getpaseo/cli

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.tools.paseo;
in
{
  options.dx.tools.paseo = {
    enable = lib.mkEnableOption "Paseo CLI";

    version = lib.mkOption {
      type = lib.types.str;
      default = "latest";
      description = "Version of Paseo CLI to install.";
    };

    enableRelay = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Paseo relay for remote connections (app.paseo.sh).";
    };

    enableWebUi = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Serve the bundled web UI from the daemon.";
    };
  };

  config = lib.mkIf cfg.enable {
    packages = [
      (helpers.mkNpmCli {
        pname = "paseo";
        npmName = "@getpaseo/cli";
        version = cfg.version;
        sha256 = lib.fakeHash;
      })
    ];

    enterShell = ''
      # dx.tools.paseo: ensure .paseo directory exists
      mkdir -p "$HOME/.paseo"

      # dx.tools.paseo: generate config.json if it doesn't exist or is outdated
      # The config enables relay, MCP injection, terminal agent hooks,
      # and configures the Devin agent provider via ACP.
      # Uses a version marker so config is regenerated when we update the template.
      PASEO_CONFIG="$HOME/.paseo/config.json"
      PASEO_CONFIG_VERSION="2"
      PASEO_VERSION_FILE="$HOME/.paseo/.config-version"
      CURRENT_VERSION=""
      [ -f "$PASEO_VERSION_FILE" ] && CURRENT_VERSION=$(cat "$PASEO_VERSION_FILE" 2>/dev/null || echo "")
      if [ ! -f "$PASEO_CONFIG" ] || [ "$CURRENT_VERSION" != "$PASEO_CONFIG_VERSION" ]; then
        cat > "$PASEO_CONFIG" << 'PASEOEOF'
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
      "enabled": true
    }
  },
  "app": {
    "baseUrl": "https://app.paseo.sh"
  },
  "pluginsEnabled": true,
  "plugins": {},
  "agents": {
    "providers": {
      "devin": {
        "extends": "acp",
        "label": "Devin CLI",
        "description": "Cognition's Devin for Terminal via Agent Client Protocol",
        "command": ["devin", "acp"],
        "env": {}
      },
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
    "dictation": { "enabled": false },
    "voiceMode": { "enabled": false }
  }
}
PASEOEOF
        chmod 600 "$PASEO_CONFIG"
        echo "$PASEO_CONFIG_VERSION" > "$PASEO_VERSION_FILE"
      fi

      # dx.tools.paseo: create workspace directory for projects
      mkdir -p "$HOME/workspace"

      # dx.tools.paseo: patch web UI to inject public host instead of 127.0.0.1
      # The original Paseo web UI hardcodes 127.0.0.1:6767 in the initial
      # daemon connection hint, which doesn't work when accessing the web UI
      # through a reverse proxy (OAuth proxy, OpenShift Route). The patch
      # uses the request's Host header so the browser connects to the
      # public URL, which is proxied back to the daemon.
      PASEO_PATCH_VERSION="1"
      PASEO_PATCH_VERSION_FILE="$HOME/.paseo/.patch-version"
      CURRENT_PATCH_VERSION=""
      [ -f "$PASEO_PATCH_VERSION_FILE" ] && CURRENT_PATCH_VERSION=$(cat "$PASEO_PATCH_VERSION_FILE" 2>/dev/null || echo "")
      if [ "$CURRENT_PATCH_VERSION" != "$PASEO_PATCH_VERSION" ]; then
        cat > "$HOME/.paseo/web-ui-patched.js" << 'WUIEOF'
import { createReadStream, readFileSync, statSync } from "node:fs";
import path from "node:path";
const EXCLUDED_PATH_PREFIXES = ["/api/", "/mcp/", "/public/"];
const EXCLUDED_PATHS = new Set(["/api", "/mcp", "/public"]);
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
    const normalized = acceptEncoding.toLowerCase();
    if (normalized.includes("br")) { return "br"; }
    if (normalized.includes("gzip")) { return "gzip"; }
    return null;
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
    const compressedFile = `${resolvedFile}.${encoding === "br" ? "br" : "gz"}`;
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
        .replace(/&/g, "\\u0026");
}
function injectConnectionHint(html, req, label) {
    const host = typeof req.headers.host === "string" ? req.headers.host : "";
    const useTls = req.protocol === "https";
    const defaultPort = useTls ? 443 : 80;
    const hostWithPort = host.includes(":") ? host : host + ":" + defaultPort;
    const hint = { listen: hostWithPort, useTls, label };
    const script = `<script>window.__PASEO_INITIAL_DAEMON_CONNECTION__=${serializeInlineScriptJson(hint)}</script>`;
    const headClose = /<\/head>/i;
    if (headClose.test(html)) { return html.replace(headClose, `${script}</head>`); }
    return script + html;
}
//# sourceMappingURL=web-ui.js.map
WUIEOF

        cat > "$HOME/.paseo/web-ui-loader.mjs" << 'LOADEREOF'
export async function resolve(specifier, context, nextResolve) {
  const result = await nextResolve(specifier, context);
  if (result.url && result.url.includes("server/server/web-ui.js") && result.url.includes("@getpaseo")) {
    return { url: "file://" + process.env.HOME + "/.paseo/web-ui-patched.js", shortCircuit: true };
  }
  return result;
}
LOADEREOF

        echo "$PASEO_PATCH_VERSION" > "$PASEO_PATCH_VERSION_FILE"
      fi
    '';
  };
}
