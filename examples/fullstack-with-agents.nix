# Example: Full-stack development with AI agents
#
# A monorepo-style setup with multiple language runtimes,
# services, and AI agents sharing config.

{ pkgs, ... }:

{
  # --- Core ---
  dx.core.agentConfig.enable = true;

  # --- Native devenv languages ---
  languages.python.enable = true;
  languages.rust.enable = true;

  # --- docker-x runtimes ---
  dx.runtimes.bun.enable = true;

  # --- Native devenv services ---
  services.postgres.enable = true;

  # --- AI agents ---
  dx.agents.claudeCode.enable = true;
  dx.agents.claudeCode.shareConfig = true;
  dx.agents.devin.enable = true;
  dx.agents.devin.shareConfig = true;
  dx.agents.cursor.enable = true;

  # --- Tools ---
  dx.tools.paseo.enable = true;
  dx.tools.caddyProxy = {
    enable = true;
    listenPort = 3000;
  };

  # --- Processes ---
  processes.dev-server.exec = "bun run dev";
}
