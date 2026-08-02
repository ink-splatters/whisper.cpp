{lib, ...}: {
  perSystem = {
    mkWhisper,
    whisperSupport,
    ...
  }: let
    whisperCli = mkWhisper {};
  in {
    packages = lib.mkMerge [
      {
        default = whisperCli;
        whisper-cli = whisperCli;
        whisper-cli-native = mkWhisper {nativeSupport = true;};
      }
      (lib.mkIf whisperSupport.cuda {
        whisper-cli-cuda = mkWhisper {cudaSupport = true;};
        whisper-cli-cuda-native = mkWhisper {
          cudaSupport = true;
          nativeSupport = true;
        };
      })
      (lib.mkIf whisperSupport.rocm {
        whisper-cli-rocm = mkWhisper {rocmSupport = true;};
        whisper-cli-rocm-native = mkWhisper {
          nativeSupport = true;
          rocmSupport = true;
        };
      })
    ];
  };
}
