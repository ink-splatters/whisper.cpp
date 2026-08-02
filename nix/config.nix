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
      default = true;
    };
    vulkanSupport = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    ffmpegSupport = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    withSDL = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    noHardening = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };
}
