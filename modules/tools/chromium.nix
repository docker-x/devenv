# dx.tools.chromium — headless Chromium baked into the image
#
# Why this exists alongside dx.tools.playwright: that module fetches browsers
# at shell entry with `npx playwright install`, which needs network at runtime
# and a writable browser cache under $HOME. Neither is dependable in a
# hardened container. On OpenShift's restricted SCC the pod also runs as an
# arbitrary UID that cannot write /nix/var/nix/profiles, so `nix profile add`
# fails at runtime too — the browser has to be part of the image.
#
# Use this when a workflow needs a browser deterministically: headless
# screenshots, visual regression, or render-and-compare verification.

{ lib, config, pkgs, ... }:

let
  cfg = config.dx.tools.chromium;

  # Chromium's setuid/namespace sandbox cannot start when user namespaces are
  # blocked, which is the case under the restricted SCC (seccomp denies
  # unshare). SwiftShader gives software rendering on nodes with no GPU.
  wrapper = pkgs.writeShellScriptBin "chromium-headless" ''
    exec ${cfg.package}/bin/chromium \
      --headless=new \
      --user-data-dir="${cfg.userDataDir}" \
      ${lib.optionalString cfg.noSandbox "--no-sandbox --disable-setuid-sandbox"} \
      ${lib.optionalString cfg.softwareRendering "--use-angle=swiftshader --enable-unsafe-swiftshader"} \
      ${lib.optionalString (cfg.softwareRendering && cfg.noSandbox) "--disable-gpu-sandbox"} \
      --disable-dev-shm-usage \
      "$@"
  '';
in
{
  options.dx.tools.chromium = {
    enable = lib.mkEnableOption "headless Chromium";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.chromium;
      defaultText = lib.literalExpression "pkgs.chromium";
      description = "Chromium package to install. Swap for pkgs.ungoogled-chromium if preferred.";
    };

    noSandbox = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Pass --no-sandbox in the wrapper. Required wherever user namespaces are
        unavailable (OpenShift restricted SCC, many hardened runtimes). Set to
        false only when the container can create user namespaces, because it
        drops a real security boundary.
      '';
    };

    softwareRendering = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Render through SwiftShader, for nodes without a GPU. When noSandbox is
        also set, --disable-gpu-sandbox is added because the GPU-process
        sandbox cannot start either; with noSandbox = false the flag is left
        off so the GPU-process sandbox stays intact.
      '';
    };

    userDataDir = lib.mkOption {
      type = lib.types.str;
      default = "\${XDG_RUNTIME_DIR:-/tmp}/chromium-profile";
      defaultText = lib.literalExpression ''"''${XDG_RUNTIME_DIR:-/tmp}/chromium-profile"'';
      description = ''
        Profile directory passed as --user-data-dir. The default resolves at
        runtime so the profile lands somewhere writable even when HOME is not
        (restricted SCC can run with an arbitrary UID and unwritable HOME).
      '';
    };

    setChromeEnv = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Export CHROME pointing at the wrapper. Many screenshot scripts honour
        $CHROME, so this makes them work without per-project patching.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    packages = [ cfg.package wrapper ];

    env = lib.mkIf cfg.setChromeEnv {
      CHROME = "${wrapper}/bin/chromium-headless";
    };
  };
}
