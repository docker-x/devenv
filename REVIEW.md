# Review policy — docker-x/devenv

This repo is the **public shared devenv module library**. The primary gate
is the boundary rule: modules must be general and configurable, never
personalized.

## Boundary rule (blocking)

Reject any change that hardcodes personal identifiers or configuration:

- Personal GitHub orgs/usernames or personal GHCR namespaces. (The repo's
  own `docker-x` publish namespace is fine as a default only when it is
  genuinely the shared namespace — not as an identity baked into
  option-free code.)
- Personal cluster names, kube contexts, hostnames, domains, registry URLs.
- Personal SSH key names, pod/workspace names, user-specific paths
  (`/home/<user>/...`, `~/.ssh/<personal-key>`).
- Secrets, tokens, credentials — always, in any form.

If a module needs such a value, the correct shape is a `dx.*` option with a
generic default (or a required option with no default). Personal values are
set downstream in each consumer's private config repo — never here. This
applies to docs too: `AGENTS.md`/`REVIEW.md`/`examples/` must not name a
specific private repo or org; use generic phrasing.

## Generality rule (blocking)

- A module that only works for one specific deployment is a defect.
  Parameterize the varying parts; keep defaults deployment-neutral.
- New options must live under `dx.<category>.<id>.*`. Agent modules use the
  `lib/helpers.nix` helpers (`mkAgentOptions` / `extraOptions`); other
  categories declare `options.dx.<category>.<id>.*` directly — matching the
  module structure in `AGENTS.md`.
- `examples/` must also be generic — no personal values in examples.

## Severity calibration

- **Critical:** committed secrets/credentials; hardcoded personal identifiers
  reachable by downstream consumers.
- **Major:** non-configurable behavior that forces a downstream fork or
  local patch; missing option where a value clearly varies per deployment.
- **Minor:** generic default that happens to match the author's deployment
  (still fix, but not a leak).

## Verification expectations

Mirror `.github/workflows/test.yaml` — the CI gate:

- `nix-instantiate --parse` on every `.nix` file (syntax).
- `devenv info` — base evaluation.
- `devenv info` again with a `devenv.local.nix` enabling a representative
  module set (catches broken derivations and option-type errors that base
  eval misses). CI enables a fixed set of four modules — when touching a
  module outside that set, verify it locally with `devenv.local.nix` and
  note the coverage gap in the PR.

Policy, not enforced by CI:

- `lib.fakeHash` must not remain in code intended for a tagged release.
