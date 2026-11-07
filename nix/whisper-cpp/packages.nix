{
  perSystem = {config, ...}: let
    inherit (config) mkWhisper;
    whisper-cli = mkWhisper {};
  in {
    packages = {
      inherit whisper-cli;
      default = whisper-cli;
      whisper-cli-native = mkWhisper {nativeSupport = true;};
    };
  };
}
