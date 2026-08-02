{lib, ...}: {
  options = {
    version = lib.mkOption {
      type = lib.types.str;
    };
    src = lib.mkOption {
      type = lib.types.path;
    };
    coreMLSupport = lib.mkOption {
      type = lib.types.bool;
    };
    cudaSupport = lib.mkOption {
      type = lib.types.bool;
    };
    ffmpegSupport = lib.mkOption {
      type = lib.types.bool;
    };
    metalSupport = lib.mkOption {
      type = lib.types.bool;
    };
    rocmSupport = lib.mkOption {
      type = lib.types.bool;
    };
    vulkanSupport = lib.mkOption {
      type = lib.types.bool;
    };
    withSDL = lib.mkOption {
      type = lib.types.bool;
    };
  };
}
