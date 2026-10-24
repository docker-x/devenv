# dx.agents.omp — oh-my-pi coding agent (omp.sh, can1357/oh-my-pi)
# Install method: upstream installer (https://omp.sh/install) in --source mode.
# Source mode installs @oh-my-pi/pi-coding-agent via bun — pure JS, so it
# runs under the nix-provided bun runtime. The --binary path ships a
# dynamically-linked ELF that cannot exec in Nix containers (no /lib64/ld-linux).

{ lib, config, pkgs, ... }:

let
  helpers = import ../../lib/helpers.nix { inherit lib pkgs; };
  cfg = config.dx.agents.omp;
  agentConfigDir = config.dx.core.agentConfig.dir or "\${AGENT_CONFIG_DIR:-$HOME/.local/share/agent-config}";
in
{
  options.dx.agents.omp = helpers.mkAgentOptions {
    agentId = "omp";
    name = "oh-my-pi";
  };

  config = lib.mkIf cfg.enable {
    dx.core.agentConfig.enable = lib.mkIf cfg.shareConfig true;

    enterShell = ''
      # dx.agents.omp: install via upstream installer (--source → bun, no ELF)
      if ! command -v omp &>/dev/null; then
        echo "dx.agents.omp: downloading upstream installer..."
        _omp_installer=$(mktemp)
        if curl --proto =https -fsSL https://omp.sh/install -o "$_omp_installer"; then
          if ! sh "$_omp_installer" --source ${lib.optionalString (cfg.version != "latest") "--ref ${lib.escapeShellArg cfg.version}"}; then
            echo "dx.agents.omp: installer execution failed" >&2
          fi
        else
          echo "dx.agents.omp: FAILED to download installer" >&2
        fi
        rm -f "$_omp_installer"
      fi
      ${lib.optionalString cfg.shareConfig (helpers.shareConfigHook {
        agentId = "omp";
        configPaths = [ "$HOME/.omp" "$HOME/.config/omp" ];
        agentConfigDir = toString agentConfigDir;
      })}
    '';
  };
}
