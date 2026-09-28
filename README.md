# docker-x/devenv

devenv.sh module library migrating [docker-x/devcontainers](https://github.com/docker-x/devcontainers) features to native devenv modules. Construct your devenv from categorized feature modules — AI agents, runtimes, tools, and infrastructure.

## Why

[devenv.sh](https://devenv.sh/) provides declarative, reproducible developer environments using Nix. The `docker-x/devcontainers` repo shipped these features as devcontainer `install.sh` scripts. This repo re-expresses them as **native devenv Nix modules** — respecting devenv's native features (languages, services, processes) and extending them with docker-x patterns (shared agent config, orchestration).

## Quick start

Add `docker-x/devenv` as an input in your project's `devenv.yaml`:

```yaml
inputs:
  nixpkgs:
    url: github:cachix/devenv-nixpkgs/rolling
  docker-x:
    url: github:docker-x/devenv
    flake: false
imports:
- docker-x
```

Enable features in your `devenv.nix`:

```nix
{ pkgs, ... }:
{
  # Core: shared agent config directory
  dx.core.agentConfig.enable = true;

  # Agents: AI coding CLIs
  dx.agents.devin.enable = true;
  dx.agents.devin.shareConfig = true;
  dx.agents.claudeCode.enable = true;      # delegates to native claude.code
  dx.agents.codex.enable = true;

  # Runtimes
  dx.runtimes.bun.enable = true;            # delegates to native languages.javascript.bun

  # Tools
  dx.tools.gascity.enable = true;
  dx.tools.gascity.autoRegister = true;

  # Infra (OpenShift)
  dx.infra.openshiftCompat.enable = true;
  dx.infra.openshiftCompat.sshPort = 2222;
}
```

Then:

```bash
devenv shell
```

## Module categories

### `dx.core.*` — Shared infrastructure

| Module | Description | Migrated from |
| ------ | ----------- | ------------- |
| `agentConfig` | Shared `AGENT_CONFIG_DIR` for AI agent config | `agent-config` |

### `dx.agents.*` — AI coding agents (24)

| Module | Description | Native devenv? |
| ------ | ----------- | -------------- |
| `devin` | Devin CLI | — |
| `claudeCode` | Claude Code CLI | delegates to `claude.code` |
| `claude` | Anthropic Claude SDK config | — |
| `codex` | OpenAI Codex CLI | — |
| `cursor` | Cursor Agent CLI | — |
| `copilot` | GitHub Copilot CLI | — |
| `cline` | Cline CLI | — |
| `crush` | Crush CLI (Charm) | — |
| `gemini` | Google Gemini CLI | — |
| `goose` | Goose CLI (Block) | — |
| `amp` | Amp (Sourcegraph) | — |
| `bob` | Bob Shell | — |
| `kilo` | Kilo CLI | — |
| `kimi` | Kimi Code (Moonshot AI) | — |
| `qwenCode` | Qwen Code (Alibaba) | — |
| `opencode` | OpenCode AI | — |
| `openclaw` | OpenClaw | — |
| `cao` | CLI Agent Orchestrator (AWS Labs) | — |
| `herdr` | Herdr | — |
| `hermes` | Hermes Agent (Nous Research) | — |
| `mastraCode` | Mastra Code | — |
| `grokBuild` | Grok Build (xAI) | — |
| `dockerAgent` | Docker Agent | — |
| `agentSkills` | Agent skills sync from GitHub | — |

### `dx.runtimes.*` — Language runtimes

| Module | Description | Native devenv? |
| ------ | ----------- | -------------- |
| `bun` | Bun JavaScript runtime | delegates to `languages.javascript.bun` |

### `dx.tools.*` — Development tools

| Module | Description | Migrated from |
| ------ | ----------- | ------------- |
| `gascity` | Gas City — AI agent orchestration | `gascity` |
| `homebrew` | Homebrew on Linux | `homebrew` |
| `playwright` | Playwright browser deps | `playwright` |
| `chromium` | Headless Chromium baked into the image (no runtime download) | `chromium`, `chromium-headless` |
| `sacpConductor` | ACP proxy orchestration | `sacp-conductor` |
| `caddyProxy` | Caddy reverse proxy for dev previews | `caddy-proxy` |
| `paseo` | Paseo CLI | `paseo` |

### `dx.infra.*` — Platform infrastructure

| Module | Description | Migrated from |
| ------ | ----------- | ------------- |
| `openshiftCompat` | OpenShift restricted SCC compatibility | `openshift-compat` |
| `devsy` | Devsy agent binary (pre-install) | `devsy` |
| `devpod` | DevPod agent binary (legacy) | `devpod` |

## Shared agent config

All agent modules with `shareConfig = true` symlink their config directory into `AGENT_CONFIG_DIR`. This mirrors the devcontainer `shareConfig` pattern — config persists across rebuilds and can be shared between agents.

```nix
{
  dx.core.agentConfig.enable = true;
  dx.agents.devin.enable = true;
  dx.agents.devin.shareConfig = true;       # ~/.devin -> $AGENT_CONFIG_DIR/devin
  dx.agents.claudeCode.enable = true;
  dx.agents.claudeCode.shareConfig = true;  # ~/.claude -> $AGENT_CONFIG_DIR/claude-code
}
```

## Native devenv delegation

Where devenv has a native feature, docker-x modules delegate and extend:

| docker-x module | Native devenv | Extension |
| --------------- | ------------- | --------- |
| `dx.runtimes.bun` | `languages.javascript.bun` | `shareConfig` for AGENT_CONFIG_DIR |
| `dx.agents.claudeCode` | `claude.code` | `shareConfig` for AGENT_CONFIG_DIR |

This means you get all of devenv's native features (hooks, commands, skills for Claude Code; LSP, package management for Bun) **plus** docker-x's shared config pattern.

## Filling in hashes

Binary and npm derivations use `lib.fakeHash` as a placeholder. On first `devenv shell`, the build will fail with the correct hash — paste it into the module.

```nix
# Before:
sha256 = lib.fakeHash;

# After (from the error message):
sha256 = "sha256-abc123...";
```

This is the standard Nix development pattern. Future versions will pre-fill hashes for stable releases.

## Repo structure

```
modules/
  core/           # shared infrastructure (agent-config)
  agents/         # 24 AI coding agents
  runtimes/       # language runtimes (bun)
  tools/          # development tools (gascity, homebrew, ...)
  infra/          # platform infrastructure (openshift-compat, devsy, devpod)
lib/
  helpers.nix     # mkGithubBinary, mkNpmCli, mkScriptCli, shareConfigHook, mkAgentOptions
devenv.nix        # entry point — imports all modules
devenv.yaml       # inputs for this repo's own development
examples/         # example devenv.nix configurations
```

## License

MIT
