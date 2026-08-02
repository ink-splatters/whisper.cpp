{
  perSystem = {
    config,
    pkgs,
    ...
  }: let
    inherit (config) pre-commit;
  in {
    devShells.default = pkgs.mkShell.override {stdenv = pkgs.llvmPackages_latest.stdenv;} {
      inputsFrom = [config.packages.whisper-cli-native];
      packages = pre-commit.settings.enabledPackages;

      shellHook = pre-commit.installationScript;
    };
  };
}
