# dx.agents.agent-skills — Agent Skills
# Migrated from: ghcr.io/docker-x/devcontainers/agent-skills
# Installs agent skills from GitHub repos using existing gh auth.
# Per-agent symlink targets mirror the devcontainer skills-sync.sh
# KNOWN_AGENTS map — each agent reads skills from its own config dir.

{ lib, config, pkgs, ... }:

let
  cfg = config.dx.agents.agentSkills;

  # Agent ID -> skills dir relative to $HOME (mirrors devcontainer
  # skills-sync.sh KNOWN_AGENTS).
  knownAgents = {
    devin = ".config/devin/skills";
    claude-code = ".claude/skills";
    claude = ".claude/skills";
    github-copilot = ".copilot/skills";
    codex = ".codex/skills";
    cursor = ".cursor/skills";
    opencode = ".config/opencode/skills";
    gemini-cli = ".gemini/skills";
    gemini = ".gemini/skills";
    goose = ".config/goose/skills";
    windsurf = ".codeium/windsurf/skills";
    kilo = ".kilocode/skills";
  };
in
{
  options.dx.agents.agentSkills = {
    enable = lib.mkEnableOption "agent skills sync";

    agents = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "claude" "cursor" "codex" ];
      description = ''
        Agent IDs to install skills for (creates per-agent symlinks).
        Known IDs map to their native skills dir (e.g. devin -> .config/devin/skills);
        unknown IDs fall back to ~/.<id>/skills.
      '';
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

      # Create per-agent symlinks (native skills dir per agent)
      ${lib.concatMapStrings (agent: ''
        _agent_skills="$HOME/${knownAgents.${agent} or ".${agent}/skills"}"
        if [[ ! -L "$_agent_skills" ]]; then
          mkdir -p "$(dirname "$_agent_skills")"
          ln -sfn "$_SKILLS_DIR" "$_agent_skills" 2>/dev/null || true
        fi
      '') cfg.agents}
    '';
  };
}
