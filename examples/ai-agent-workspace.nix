# Example: AI agent workspace with shared config
#
# Copy this to your project, add docker-x/devenv as an input in devenv.yaml,
# and enable the features you need.

{ pkgs, ... }:

{
  # --- Core: shared agent config ---
  dx.core.agentConfig.enable = true;

  # --- Agents: AI coding CLIs ---
  dx.agents.devin = {
    enable = true;
    shareConfig = true;
  };

  dx.agents.claudeCode = {
    enable = true;        # delegates to native claude.code
    shareConfig = true;
  };

  dx.agents.codex = {
    enable = true;
    shareConfig = true;
  };

  dx.agents.gemini.enable = true;

  # --- Runtimes ---
  dx.runtimes.bun = {
    enable = true;        # delegates to native languages.javascript.bun
    shareConfig = true;
  };

  # --- Tools ---
  dx.tools.gascity = {
    enable = true;
    autoRegister = true;
  };

  dx.tools.playwright = {
    enable = true;
    browsers = [ "chromium" "firefox" ];
  };

  # --- Infra (for OpenShift deployments) ---
  # dx.infra.openshiftCompat = {
  #   enable = true;
  #   sshPort = 2222;
  # };
  # dx.infra.devsy.enable = true;
}
