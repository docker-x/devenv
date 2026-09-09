# dx.agents.agent-skills — Agent Skills
# Migrated from: ghcr.io/docker-x/devcontainers/agent-skills
# Installs agent skills from GitHub repos using existing gh auth.

{ lib, config, pkgs, ... }:

let
  cfg = config.dx.agents.agentSkills;
in
{
  options.dx.agents.agentSkills = {
    enable = lib.mkEnableOption "agent skills sync";

    agents = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "claude" "cursor" "codex" ];
      description = "Agent IDs to install skills for (creates per-agent symlinks).";
    };

    skills = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "GitHub repos (owner/repo format) to install skills from.";
    };
  };

  config = lib.mkIf cfg.enable {
    dx.core.agentConfig.enable = true;

    packages = [ pkgs.gh pkgs.jq ];

    enterShell = ''
      # dx.agents.agent-skills: sync skills on first login
      _SKILLS_DIR="''${AGENT_CONFIG_DIR:-$HOME/.local/share/agent-config}/skills"
      mkdir -p "$_SKILLS_DIR"

      ${lib.concatMapStrings (repo: ''
        _repo_dir="$_SKILLS_DIR/${builtins.baseNameOf repo}"
        if [[ ! -d "$_repo_dir" ]] && command -v gh &>/dev/null; then
          echo "dx.agents.agent-skills: cloning ${repo}..."
          gh repo clone ${repo} "$_repo_dir" -- --depth 1 2>/dev/null || true
        fi
      '') cfg.skills}

      # Create per-agent symlinks
      ${lib.concatMapStrings (agent: ''
        _agent_skills="$HOME/.${agent}/skills"
        if [[ ! -L "$_agent_skills" ]]; then
          mkdir -p "$(dirname "$_agent_skills")"
          ln -sfn "$_SKILLS_DIR" "$_agent_skills" 2>/dev/null || true
        fi
      '') cfg.agents}
    '';
  };
}
