# dx.tools.caddy-proxy — Caddy reverse proxy for dev server previews
# Migrated from: ghcr.io/docker-x/devcontainers/caddy-proxy
# Caddy listens on a single port and routes to multiple dev servers.

{ lib, config, pkgs, ... }:

let
  cfg = config.dx.tools.caddyProxy;
in
{
  options.dx.tools.caddyProxy = {
    enable = lib.mkEnableOption "Caddy reverse proxy for dev server previews";

    listenPort = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port Caddy listens on.";
    };

    adminPort = lib.mkOption {
      type = lib.types.port;
      default = 2019;
      description = "Caddy admin API port.";
    };
  };

  config = lib.mkIf cfg.enable {
    packages = [ pkgs.caddy ];

    processes.caddy-proxy.exec = ''
      caddy run --adapter caddyfile --config <(echo '{
        admin :${toString cfg.adminPort}
        :${toString cfg.listenPort} {
          reverse_proxy /* {
            dynamic_suffix
          }
        }
      }')
    '';
  };
}
