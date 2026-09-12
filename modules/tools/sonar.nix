# dx.tools.sonar — SonarScanner CLI
# Migrated from: ghcr.io/docker-x/devcontainers/sonar
# Install method: zip from binaries.sonarsource.com (per-asset .sha256 verified)
#
# NOTE: the version option is pinned because sha256 is verified.
# Bumping `version` requires updating the per-arch hashes below.

{ lib, config, pkgs, ... }:

let
  cfg = config.dx.tools.sonar;

  archSuffix = {
    x86_64-linux = "x64";
    aarch64-linux = "aarch64";
  }.${pkgs.stdenv.hostPlatform.system} or (throw "dx.tools.sonar: unsupported system ${pkgs.stdenv.hostPlatform.system}");

  # sha256 of the 8.1.0.6389 zips (from the publisher's .sha256 files)
  hashes = {
    x86_64-linux = "bb8f709f9cb73352f8d1260a3b3c506c0f41146754bc630762c126d795499d0b";
    aarch64-linux = "5e1c9328f4e261838de778c9e586ee608cca45ff7f0538108642219214628ba5";
  };

  sonarDir = "sonar-scanner-${cfg.version}-linux-${archSuffix}";

  sonarScanner = pkgs.stdenv.mkDerivation {
    pname = "sonar-scanner";
    version = cfg.version;

    src = pkgs.fetchurl {
      url = "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${cfg.version}-linux-${archSuffix}.zip";
      sha256 = hashes.${pkgs.stdenv.hostPlatform.system} or lib.fakeHash;
    };

    nativeBuildInputs = [ pkgs.unzip ];
    dontUnpack = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out/opt $out/bin
      unzip -q "$src" -d $out/opt
      chmod +x $out/opt/${sonarDir}/bin/sonar-scanner
      # The upstream script resolves its own symlink to find SONAR_SCANNER_HOME
      # and the bundled JRE — a plain symlink is sufficient.
      ln -sf $out/opt/${sonarDir}/bin/sonar-scanner $out/bin/sonar-scanner
      runHook postInstall
    '';

    meta.mainProgram = "sonar-scanner";
  };
in
{
  options.dx.tools.sonar = {
    enable = lib.mkEnableOption "SonarScanner CLI";

    version = lib.mkOption {
      type = lib.types.str;
      default = "8.1.0.6389";
      description = "SonarScanner CLI version. Pinned because sha256 is verified; bump hashes when bumping the version.";
    };
  };

  config = lib.mkIf cfg.enable {
    packages = [ sonarScanner ];
  };
}
