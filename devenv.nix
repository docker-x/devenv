# docker-x/devenv — devenv.sh module library
#
# This is the entry point imported by devenv when a project adds
# `docker-x/devenv` as an input in devenv.yaml:
#
#   inputs:
#     docker-x:
#       url: github:docker-x/devenv
#       flake: false
#   imports:
#   - docker-x
#
# All modules are under the `dx.*` option namespace, organized by category:
#
#   dx.core.*       — shared infrastructure (agent-config)
#   dx.agents.*     — AI coding agents (devin, claude-code, codex, ...)
#   dx.runtimes.*   — language runtimes (bun)
#   dx.tools.*      — development tools (gascity, homebrew, playwright, ...)
#   dx.infra.*      — platform infrastructure (openshift-compat, devsy, devpod)
#
# Native devenv features are preferred where they exist (e.g. claude.code,
# languages.javascript.bun). The docker-x modules extend them with our
# shared-config and orchestration patterns.

{ lib, pkgs, config, ... }:

{
  imports = [
    # --- core: shared infrastructure ---
    ./modules/core/agent-config.nix

    # --- agents: AI coding agents ---
    ./modules/agents/devin.nix
    ./modules/agents/claude-code.nix
    ./modules/agents/claude.nix
    ./modules/agents/codex.nix
    ./modules/agents/cursor.nix
    ./modules/agents/copilot.nix
    ./modules/agents/cline.nix
    ./modules/agents/crush.nix
    ./modules/agents/gemini.nix
    ./modules/agents/goose.nix
    ./modules/agents/amp.nix
    ./modules/agents/bob.nix
    ./modules/agents/kilo.nix
    ./modules/agents/kimi.nix
    ./modules/agents/qwen-code.nix
    ./modules/agents/opencode.nix
    ./modules/agents/openclaw.nix
    ./modules/agents/cao.nix
    ./modules/agents/herdr.nix
    ./modules/agents/hermes.nix
    ./modules/agents/mastra-code.nix
    ./modules/agents/grok-build.nix
    ./modules/agents/docker-agent.nix
    ./modules/agents/agent-skills.nix

    # --- runtimes: language runtimes ---
    ./modules/runtimes/bun.nix

    # --- tools: development tools ---
    ./modules/tools/gascity.nix
    ./modules/tools/homebrew.nix
    ./modules/tools/playwright.nix
    ./modules/tools/sacp-conductor.nix
    ./modules/tools/caddy-proxy.nix
    ./modules/tools/paseo.nix

    # --- infra: platform infrastructure ---
    ./modules/infra/openshift-compat.nix
    ./modules/infra/devsy.nix
    ./modules/infra/devpod.nix
  ];
}
