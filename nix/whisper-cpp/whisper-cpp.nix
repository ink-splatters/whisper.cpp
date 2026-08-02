top @ {lib, ...}: {
  perSystem = {pkgs, ...}: let
    inherit (top.config) src version;
    inherit
      (lib)
      cmakeBool
      cmakeFeature
      optional
      optionals
      optionalString
      ;
    inherit (builtins) toString;
    inherit
      (pkgs)
      autoAddDriverRunpath
      cmakeMinimal
      cudaPackages
      darwinMinVersionHook
      ffmpeg
      makeWrapper
      ninja
      rocmPackages
      shaderc
      SDL2
      vulkan-headers
      vulkan-loader
      wget
      which
      ;
    inherit (pkgs.llvmPackages_latest) bintools clang openmp;
    inherit (pkgs.stdenv.hostPlatform) isDarwin isLinux;

    available = lib.meta.availableOn pkgs.stdenv.hostPlatform;
    cudaSupported =
      isLinux
      && cudaPackages ? backendStdenv
      && cudaPackages ? cccl
      && cudaPackages ? cuda_cudart
      && cudaPackages ? cuda_nvcc
      && cudaPackages ? libcublas
      && builtins.all available (with cudaPackages; [
        cccl
        cuda_cudart
        cuda_nvcc
        libcublas
      ]);
    rocmSupported =
      isLinux
      && rocmPackages ? clr
      && rocmPackages ? hipblas
      && rocmPackages ? llvm
      && rocmPackages.llvm ? llvm
      && rocmPackages ? rocblas
      && builtins.all available (
        [rocmPackages.llvm.llvm]
        ++ (with rocmPackages; [
          clr
          hipblas
          rocblas
        ])
      );
    vulkanSupported =
      isLinux
      && builtins.all available [
        shaderc
        vulkan-headers
        vulkan-loader
      ];

    mkWhisper = {
      cudaSupport ? false,
      metalSupport ? isDarwin,
      nativeSupport ? false,
      rocmSupport ? false,
    }: let
      cudaEnabled = cudaSupport && cudaSupported;
      rocmEnabled = rocmSupport && rocmSupported;
      metalEnabled = metalSupport && isDarwin;
      coreMLEnabled = top.config.coreMLSupport && isDarwin;
      ffmpegEnabled = top.config.ffmpegSupport && isLinux;
      vulkanEnabled =
        top.config.vulkanSupport
        && vulkanSupported
        && !(cudaEnabled || rocmEnabled);

      stdenv =
        if cudaEnabled
        then cudaPackages.backendStdenv
        else if isDarwin
        then pkgs.llvmPackages_latest.stdenv
        else pkgs.stdenv;
      inherit (stdenv.hostPlatform) isStatic isx86;

      compileFlags =
        ["-pipe"]
        ++ optional metalEnabled "-D__ARM_FEATURE_DOTPROD=1"
        ++ optional nativeSupport "-mcpu=native";
      rocmGpuTargets = builtins.concatStringsSep ";" rocmPackages.clr.gpuTargets;
    in
      stdenv.mkDerivation {
        pname = "whisper-cpp";
        inherit src version;

        nativeBuildInputs =
          [
            cmakeMinimal
            pkgs.gitMinimal
            makeWrapper
            ninja
            which
          ]
          ++ optionals isDarwin [
            bintools
            clang
          ]
          ++ optionals cudaEnabled (
            [autoAddDriverRunpath]
            ++ (with cudaPackages; [cuda_nvcc])
          );

        buildInputs =
          optional top.config.withSDL SDL2
          ++ optional ffmpegEnabled ffmpeg
          ++ optionals cudaEnabled (with cudaPackages; [
            cccl
            cuda_cudart
            libcublas
          ])
          ++ optionals rocmEnabled (with rocmPackages; [
            clr
            hipblas
            rocblas
          ])
          ++ optionals vulkanEnabled [
            shaderc
            vulkan-headers
            vulkan-loader
          ]
          ++ optionals isDarwin [
            pkgs.apple-sdk_15
            openmp
            (darwinMinVersionHook "15.2")
          ];

        cmakeFlags =
          [
            (cmakeBool "WHISPER_BUILD_EXAMPLES" true)
            (cmakeBool "WHISPER_SDL2" top.config.withSDL)
            (cmakeBool "GGML_CUDA" cudaEnabled)
            (cmakeBool "GGML_HIPBLAS" rocmEnabled)
            (cmakeBool "GGML_VULKAN" vulkanEnabled)
            (cmakeBool "GGML_LTO" true)
            (cmakeBool "GGML_NATIVE" nativeSupport)
            (cmakeBool "GGML_CCACHE" false)
            (cmakeBool "BUILD_SHARED_LIBS" (!isStatic))
          ]
          ++ optionals isLinux [
            (cmakeBool "WHISPER_COMMON_FFMPEG" ffmpegEnabled)
          ]
          ++ optionals (isx86 && !isStatic) [
            (cmakeBool "GGML_BACKEND_DL" true)
            (cmakeBool "GGML_CPU_ALL_VARIANTS" true)
            (cmakeFeature "GGML_BACKEND_DIR" "${placeholder "out"}/lib")
          ]
          ++ optionals cudaEnabled [
            (cmakeFeature "CMAKE_CUDA_ARCHITECTURES" cudaPackages.flags.cmakeCudaArchitecturesString)
          ]
          ++ optionals rocmEnabled [
            (cmakeFeature "CMAKE_C_COMPILER" "hipcc")
            (cmakeFeature "CMAKE_CXX_COMPILER" "hipcc")
            (cmakeFeature "AMDGPU_TARGETS" rocmGpuTargets)
          ]
          ++ optionals coreMLEnabled [
            (cmakeBool "WHISPER_COREML" true)
            (cmakeBool "WHISPER_COREML_ALLOW_FALLBACK" true)
          ]
          ++ optionals metalEnabled [
            (cmakeBool "GGML_METAL" true)
            (cmakeBool "GGML_METAL_EMBED_LIBRARY" true)
          ];

        preConfigure =
          ''
            cmakeFlagsArray+=(
              "-DCMAKE_C_FLAGS=${toString compileFlags}"
              "-DCMAKE_CXX_FLAGS=${toString compileFlags}"
          ''
          + optionalString isDarwin ''
            "-DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=lld -Wl,-dead_strip"
          ''
          + ''
            )
          '';

        hardeningDisable = optionals top.config.noHardening ["all"];
        enableParallelBuilding = true;

        NIX_ENFORCE_NO_NATIVE = !nativeSupport;

        postInstall =
          ''
            install -v -D -m755 "$src/models/download-coreml-model.sh" "$out/bin/whisper-download-coreml-model"
            install -v -D -m755 "$src/models/download-ggml-model.sh" "$out/bin/whisper-download-ggml-model"
            install -v -D -m755 "$src/models/download-vad-model.sh" "$out/bin/whisper-download-vad-model"

            wrapProgram "$out/bin/whisper-download-coreml-model" \
              --prefix PATH : ${lib.makeBinPath [wget]}

            wrapProgram "$out/bin/whisper-download-ggml-model" \
              --prefix PATH : ${lib.makeBinPath [wget]}

            wrapProgram "$out/bin/whisper-download-vad-model" \
              --prefix PATH : ${lib.makeBinPath [wget]}
          ''
          + optionalString ffmpegEnabled ''
            wrapProgram "$out/bin/whisper-server" \
              --prefix PATH : ${lib.makeBinPath [ffmpeg]}
          '';

        requiredSystemFeatures = optionals rocmEnabled ["big-parallel"];

        meta = {
          description = "Port of OpenAI's Whisper model in C/C++";
          homepage = "https://github.com/ggml-org/whisper.cpp";
          license = lib.licenses.mit;
          mainProgram = "whisper-cli";
          platforms = lib.platforms.darwin ++ lib.platforms.linux;
        };
      };
  in {
    _module.args = {
      inherit mkWhisper;
      whisperSupport = {
        cuda = cudaSupported;
        rocm = rocmSupported;
      };
    };
  };
}
