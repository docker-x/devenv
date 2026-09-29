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

    packages = [ pkgs.gh pkgs.jq pkgs.coreutils ];

    enterShell = ''
      # dx.agents.agent-skills: sync skills on first login.
      # AGENT_CONFIG_DIR may hold a literal "$HOME/..." (env vars are not
      # shell-expanded) and derives from user-controllable cfg.dir — never
      # eval it (command injection, CWE-78); resolve only a leading "$HOME",
      # matching dx.core.agentConfig's normalization.
      _SKILLS_DIR="''${AGENT_CONFIG_DIR:-$HOME/.local/share/agent-config}"
      case "$_SKILLS_DIR" in
        "\$HOME" | "\$HOME/"*) _SKILLS_DIR="$HOME''${_SKILLS_DIR#\$HOME}" ;;
      esac
      _SKILLS_DIR="$_SKILLS_DIR/skills"
      mkdir -p "$_SKILLS_DIR"

      ${lib.concatMapStrings (repo: ''
        _repo_dir="$_SKILLS_DIR/${builtins.baseNameOf repo}"
        if [[ ! -d "$_repo_dir" ]] && command -v gh &>/dev/null; then
          echo "dx.agents.agent-skills: cloning ${repo}..."
          gh repo clone ${repo} "$_repo_dir" -- --depth 1 2>/dev/null || true
        fi
      '') cfg.skills}

      # Create per-agent symlinks (native skills dir per agent).
      # ln -sfn into a real dir nests the link inside it instead of
      # replacing it — move a real dir aside first. The backup name is
      # reserved (suffixed until free) and mv -T can never nest into an
      # existing backup dir, so reruns never clobber an earlier backup
      # (mirrors skills-sync.sh). A regular file is left untouched.
      ${lib.concatMapStrings (agent: ''
        _agent_skills="$HOME/${knownAgents.${agent} or ".${agent}/skills"}"
        if [[ "$_agent_skills" -ef "$_SKILLS_DIR" ]]; then
          : # agent's skills path already is the shared dir — nothing to link
        elif [[ -d "$_agent_skills" && ! -L "$_agent_skills" ]]; then
          _bak_base="$_agent_skills.bak.$(date +%Y%m%d%H%M%S)"
          _agent_bak="$_bak_base"
          _n=0
          while [[ -e "$_agent_bak" || -L "$_agent_bak" ]]; do
            _n=$((_n + 1))
            _agent_bak="$_bak_base.$_n"
          done
          echo "dx.agents.agent-skills: backing up $_agent_skills -> $_agent_bak"
          mv -T "$_agent_skills" "$_agent_bak" 2>/dev/null \
            || echo "dx.agents.agent-skills: WARNING: could not replace $_agent_skills; skills not linked" >&2
        elif [[ -e "$_agent_skills" && ! -L "$_agent_skills" ]]; then
          echo "dx.agents.agent-skills: WARNING: $_agent_skills is not a directory; leaving untouched, skills not linked" >&2
        fi
        if [[ ! -e "$_agent_skills" || -L "$_agent_skills" ]]; then
          mkdir -p "$(dirname "$_agent_skills")"
          ln -sfn "$_SKILLS_DIR" "$_agent_skills" 2>/dev/null || true
        fi
      '') cfg.agents}
    '';
  };
}
