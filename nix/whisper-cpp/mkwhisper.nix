top @ {lib, ...}: let
  inherit
    (lib)
    cmakeBool
    cmakeFeature
    makeBinPath
    optionals
    optionalString
    ;
  inherit (builtins) toString;
in {
  perSystem = {pkgs, ...}: let
    inherit
      (pkgs)
      autoAddDriverRunpath
      cmakeMinimal
      cudaPackages
      darwinMinVersionHook
      ffmpeg
      gitMinimal
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
    llvm = pkgs.llvmPackages_22;
    inherit
      (pkgs.stdenv.hostPlatform)
      isAarch64
      isStatic
      isx86
      isDarwin
      isLinux
      ;

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
  in {
    options.mkWhisper = lib.mkOption {
      type = lib.types.functionTo lib.types.package;
      readOnly = true;
    };

    config.mkWhisper = {nativeSupport ? false}:
      with top.config; let
        cudaEnabled = cudaSupport && cudaSupported;
        rocmEnabled = rocmSupport && rocmSupported;
        metalEnabled = metalSupport && isDarwin;
        coreMLEnabled = coreMLSupport && isDarwin;
        ffmpegEnabled = ffmpegSupport && isLinux;
        vulkanEnabled =
          vulkanSupport
          && vulkanSupported
          && !(cudaEnabled || rocmEnabled);

        stdenv =
          if cudaEnabled
          then cudaPackages.backendStdenv
          else if isDarwin
          then llvm.stdenv
          else pkgs.stdenv;

        compileFlags =
          ["-pipe"]
          ++ optionals metalEnabled ["-D__ARM_FEATURE_DOTPROD=1"]
          ++ optionals nativeSupport [
            (
              if isx86
              then "-march=native"
              else "-mcpu=native"
            )
          ]
          ++ optionals (isDarwin && !nativeSupport) ["-mcpu=apple-m1"];

        rocmGpuTargets = builtins.concatStringsSep ";" rocmPackages.clr.gpuTargets;
      in
        stdenv.mkDerivation {
          pname = "whisper-cpp";
          inherit src version;

          nativeBuildInputs =
            [
              cmakeMinimal
              gitMinimal
              makeWrapper
              ninja
              which
            ]
            ++ optionals isDarwin (with llvm; [
              bintools
              clang
            ])
            ++ optionals cudaEnabled (
              [autoAddDriverRunpath]
              ++ (with cudaPackages; [cuda_nvcc])
            );

          buildInputs =
            optionals withSDL [SDL2]
            ++ optionals ffmpegEnabled [ffmpeg]
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
              llvm.openmp
              (darwinMinVersionHook "15.2")
            ];

          cmakeFlags =
            [
              (cmakeBool "WHISPER_BUILD_EXAMPLES" true)
              (cmakeBool "WHISPER_BUILD_TESTS" false)
              (cmakeBool "WHISPER_SDL2" withSDL)
              # TODO: requires llama.cpp rebuild
              # possibly enable when having custom llama.cpp flake
              (cmakeBool "WHISPER_TALK_LLAMA" false)
              (cmakeBool "GGML_CUDA" cudaEnabled)
              (cmakeBool "GGML_HIP" rocmEnabled)
              (cmakeBool "GGML_VULKAN" vulkanEnabled)
              (cmakeBool "GGML_LTO" true)
              (cmakeBool "GGML_NATIVE" nativeSupport)
              (cmakeBool "GGML_CCACHE" false)
              (cmakeBool "BUILD_SHARED_LIBS" (!isStatic))
            ]
            ++ optionals isLinux [
              (cmakeBool "WHISPER_COMMON_FFMPEG" ffmpegEnabled)
            ]
            ++ optionals (isx86 && !isStatic && !nativeSupport) [
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

          hardeningDisable = [
            "zerocallusedregs"
            "stackprotector"
            "libcxxhardeningfast"
            "strictoverflow"
          ];
          enableParallelBuilding = true;

          NIX_ENFORCE_NO_NATIVE =
            if nativeSupport
            then 0
            else 1;

          postInstall =
            ''
              install -v -D -m755 "$src/models/download-coreml-model.sh" "$out/bin/whisper-download-coreml-model"
              install -v -D -m755 "$src/models/download-ggml-model.sh" "$out/bin/whisper-download-ggml-model"
              install -v -D -m755 "$src/models/download-vad-model.sh" "$out/bin/whisper-download-vad-model"

              wrapProgram "$out/bin/whisper-download-coreml-model" \
                --prefix PATH : ${makeBinPath [wget]}

              wrapProgram "$out/bin/whisper-download-ggml-model" \
                --prefix PATH : ${makeBinPath [wget]}

              wrapProgram "$out/bin/whisper-download-vad-model" \
                --prefix PATH : ${makeBinPath [wget]}
            ''
            + optionalString ffmpegEnabled ''
              wrapProgram "$out/bin/whisper-server" \
                --prefix PATH : ${makeBinPath [ffmpeg]}
            '';

          # libcuda.so is provided by the driver at runtime, outside the sandbox.
          doInstallCheck = !(isLinux && isAarch64 && cudaEnabled);

          installCheckPhase = ''
            runHook preInstallCheck
            "$out/bin/whisper-cli" --help >/dev/null
            "$out/bin/parakeet-cli" --help >/dev/null
            runHook postInstallCheck
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
  };
}
