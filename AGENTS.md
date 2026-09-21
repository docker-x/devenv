# AGENTS.md — Conventions for agents working in this repo

## Repository purpose

devenv.sh module library migrating `docker-x/devcontainers` features to native
devenv Nix modules. Consumed by downstream projects via `devenv.yaml` inputs.

## Boundary: shared public library vs private config

This repo is **public** and consumed by many downstream projects. Personal
configuration lives in each consumer's own private config repo — never here.

Hard rules for everything committed here:

- **No personal identifiers or configuration.** Never hardcode personal
  GitHub orgs/usernames, cluster names, registry namespaces, hostnames, SSH
  key names, credentials, or user-specific paths. Anything that differs per
  deployment must be an option with a generic default (or no default).
- **Every component is for general, configurable use.** A module that only
  works for one specific deployment is a bug. Parameterize via `options.dx.*`
  and helper args — not hardcoded strings.
- **If you need a personal value, you need an option.** Add the option here,
  set the value in your private config repo — never the reverse.

Review policy: see `REVIEW.md`. The boundary rule is a blocking finding.

## Repo layout

```
modules/
  <category>/<id>.nix   # one Nix module per feature
lib/
  helpers.nix            # shared helper functions (mkGithubBinary, mkNpmCli, ...)
devenv.nix               # entry point — imports all modules under dx.* namespace
devenv.yaml              # inputs for this repo's own development
examples/                # example devenv.nix configurations
```

Categories: `core`, `agents`, `runtimes`, `tools`, `infra`.

## Option namespace

All options are under `dx.<category>.<id>.*`:

- `dx.core.agentConfig.*`
- `dx.agents.devin.*`
- `dx.runtimes.bun.*`
- `dx.tools.gascity.*`
- `dx.infra.openshiftCompat.*`

## Writing / modifying a module

### Structure

Every module follows this pattern:

```nix
{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.<category>.<id>;
  agentConfigDir = config.dx.core.agentConfig.dir or "...";
in
{
  options.dx.<category>.<id> = helpers.mkAgentOptions {
    agentId = "<id>";
    name = "<Name>";
    # extraOptions = { ... };
  };

  config = lib.mkIf cfg.enable {
    # packages, env, enterShell, processes, etc.
  };
}
```

### Native devenv delegation

When devenv has a native equivalent, **delegate and extend**:
- Use the native option (e.g. `claude.code.enable`, `languages.javascript.bun.enable`)
- Add docker-x extensions (e.g. `shareConfig` for AGENT_CONFIG_DIR)

### shareConfig pattern

Agent modules with `shareConfig` use `helpers.shareConfigHook` in `enterShell`:

```nix
enterShell = lib.optionalString cfg.shareConfig (helpers.shareConfigHook {
  agentId = "devin";
  configPaths = [ "$HOME/.devin" "$HOME/.config/devin" ];
  agentConfigDir = toString agentConfigDir;
});
```

When `shareConfig = true`, also enable `dx.core.agentConfig`:

```nix
dx.core.agentConfig.enable = lib.mkIf cfg.shareConfig true;
```

### Hashes

Binary and npm derivations use `lib.fakeHash` as a placeholder. This is the
standard Nix development pattern — the first build fails with the correct
hash, which you paste in. Do NOT commit `lib.fakeHash` in released versions;
fill in the real hash before tagging a release.

### Helper functions (lib/helpers.nix)

- `mkGithubBinary` — fetch a single binary from a GitHub release
- `mkNpmCli` — build a global npm CLI package
- `mkScriptCli` — install a CLI via an upstream curl|bash installer
- `shareConfigHook` — generate an enterShell snippet for AGENT_CONFIG_DIR symlinking
- `mkAgentOptions` — generate standard options (enable, version, shareConfig) for agent modules

## Lessons from docker-x/devcontainers

The `${HOME:-fallback}` lesson from the devcontainer repo does not apply here
in the same form — devenv manages `HOME` correctly. However, the
`AGENT_CONFIG_DIR` sharing pattern is preserved via `enterShell` hooks
instead of build-time symlinks.

The OpenShift restricted SCC concerns (random UID, group-writable home,
fake sudo) are partially handled by devenv's non-root model. The
`openshiftCompat` module provides the SSH server and entrypoint hooks
for container deployments where devenv runs inside a pod.
