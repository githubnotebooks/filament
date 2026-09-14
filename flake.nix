{
  description = "A basic Nix flake providing development shells";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-stable.follows = "nixpkgs";
    nixpkgs-unstable.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nixpkgs-v2511.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-v2505.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-v2411.url = "github:NixOS/nixpkgs/nixos-24.11";
    nur = {
      url = "github:nix-community/NUR";
    };
  };

  outputs =
    { self
    , nixpkgs
    , nixpkgs-stable
    , nixpkgs-unstable
    , nixpkgs-v2511
    , nixpkgs-v2505
    , nixpkgs-v2411
    , nur
    , ...
    }@inputs:
    let
      pkg-settings = rec {
        allowed-unfree-packages =
          pkg:
          builtins.elem (nixpkgs.lib.getName pkg) [
            "cudnn"
            "libcublas"
            "cuda_nvrtc"
            "cuda_cudart"
            "cuda_nvcc"
            "cuda_cccl"
            "cudatoolkit"
            "nvidia-driver"
            "cuda-toolkit"
            "cuda-stubs"
          ];
        allowed-insecure-packages = [
          "electron-11.5.0"
          "openssl-1.1.1w"
        ];
      };

      eachSystem = nixpkgs.lib.genAttrs [ "x86_64-linux" ] (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfreePredicate = pkg-settings.allowed-unfree-packages;
            config.permittedInsecurePackages = pkg-settings.allowed-insecure-packages;
            overlays = [
              nur.overlays.default
              (final: prev: {
                unstable = import nixpkgs-unstable {
                  inherit system;
                  config.allowUnfreePredicate = pkg-settings.allowed-unfree-packages;
                  config.permittedInsecurePackages = pkg-settings.allowed-insecure-packages;
                  overlays = [ nur.overlays.default ];
                };
              })
              (final: prev: {
                v2511 = import nixpkgs-v2511 {
                  inherit system;
                  config.allowUnfreePredicate = pkg-settings.allowed-unfree-packages;
                  config.permittedInsecurePackages = pkg-settings.allowed-insecure-packages;
                  overlays = [ nur.overlays.default ];
                };
              })
              (final: prev: {
                v2505 = import nixpkgs-v2505 {
                  inherit system;
                  config.allowUnfreePredicate = pkg-settings.allowed-unfree-packages;
                  config.permittedInsecurePackages = pkg-settings.allowed-insecure-packages;
                  overlays = [ nur.overlays.default ];
                };
              })
              (final: prev: {
                v2411 = import nixpkgs-v2411 {
                  inherit system;
                  config.allowUnfreePredicate = pkg-settings.allowed-unfree-packages;
                  config.permittedInsecurePackages = pkg-settings.allowed-insecure-packages;
                  overlays = [ nur.overlays.default ];
                };
              })
            ];
          };

          withPkgs = pkgs: rec {
            # Glad OpenGL 加载器生成器
            # @param spec 图形 API 规范类型："gl", "gles", "egl", "glx", "wgl", "vk"
            # @param api_version API 版本号，如 "4.6", "3.3", "3.2" 等
            # @param profile OpenGL 配置文件："core" 或 "compatibility"（仅 gl/gles 有效）
            # @param extensions 需要包含的扩展，逗号分隔
            # @param generator 生成的代码语言："c", "c-debug", "d", "nim", "pascal", "volt"
            makeGlad =
              { spec
              , api_version
              , profile ? "core"
              , extensions ? ""
              , generator ? "c"
              ,
              }:
              pkgs.stdenv.mkDerivation {
                pname = "glad-${spec}";
                version = api_version;

                nativeBuildInputs = [ pkgs.python314Packages.glad ];
                buildInputs = [ ];

                buildCommand = ''
                  mkdir -p $out/include $out/lib/pkgconfig

                  glad --profile ${profile} \
                    --out-path build \
                    --api "${spec}=${api_version}" \
                    --generator ${generator} \
                    --spec ${spec} \
                    --reproducible \
                    ${if extensions != "" then "--extensions " + extensions else ""}

                  $CC -c build/src/glad.c -o build/glad.o -Ibuild/include -fPIC
                  $AR rcs $out/lib/libglad.a build/glad.o
                  cp -r build/include/* $out/include/

                  cat > $out/lib/pkgconfig/glad.pc <<EOF
                  prefix=$out
                  includedir=$out/include
                  libdir=$out/lib
                  Name: Glad
                  Description: GL/GLES/EGL/GLX/WGL/Vulkan Loader
                  Version: ${api_version}
                  Cflags: -I$out/include
                  Libs: -L$out/lib -lglad
                  EOF
                '';
              };

            # 构建工具
            buildTools = with pkgs; [
              pkg-config
              bear
              gnumake
              ninja
              cmake
              xmake
              scons
              python314Packages.glad2 # GL/GLES/EGL/GLX/WGL/Vulkan 加载器生成器
            ];

            # 编译器和调试工具
            # 注意：必须用 clang 而不是 clangNoLibcxx。
            # clangNoLibcxx 的 wrapper 会加 -nostdlib++（链接时不带任何 C++ 标准库），
            # 而编译用的是 gcc 的 libstdc++ 头文件，结果是大量 undefined reference。
            # Linux 上普通的 llvmPackages_XX.clang 默认链 gcc 的 libstdc++（不是 libc++），
            # 与 nixpkgs 里其他 C++ 库（boost/fmt 等都是 libstdc++ ABI）兼容。
            compilers = with pkgs; [
              llvmPackages_22.clang
              gcc16
              gdb
            ];

            # C++ 库
            cppLibs = with pkgs; [
              boost
              spdlog
              fmt
              cli11
              cpptrace
              gtest
              gbenchmark
            ];

            # 系统库
            systemLibs = with pkgs; [
              # stdenv.cc.cc.lib
              openssl
              cacert
              libdwarf
              glib
              pcre
              libffi
              libz
              xz
              bzip2
              zlib
              zip
              zstd
              expat
              libiconv
              dbus
            ];

            # 图形/数学库
            graphicsLibs = with pkgs; [
              assimp
              eigen
              glew
              glfw

              # Glad OpenGL 加载器
              (makeGlad {
                spec = "gl";
                api_version = "4.5";
                profile = "core";
                extensions = "";
                generator = "c";
              })

              # ImGui - 需要手动包含 backends 头文件
              (
                (pkgs.imgui.override {
                  IMGUI_BUILD_GLFW_BINDING = true;
                  IMGUI_BUILD_OPENGL3_BINDING = true;
                }).overrideAttrs
                  (old: {
                    postInstall = (old.postInstall or "") + ''
                      # 移动 backends 头文件到正确位置
                      mkdir -p $out/include/backends
                      for f in $out/include/imgui_impl_*.h; do
                        if [ -f "$f" ]; then
                          mv "$f" $out/include/backends/
                        fi
                      done
                    '';
                  })
              )

              glm
              libGL

              vulkan-headers # Vulkan API 头文件
              vulkan-loader.dev # Vulkan ICD 加载器（运行时）
              vulkan-tools # 实用工具（vulkaninfo 等），只有exe，非开发包
              vulkan-validation-layers # 验证层（调试用），只有so和json，非开发包

              # VMA 内存分配库（缺少 pc 文件，手动补丁）
              (vulkan-memory-allocator.overrideAttrs (old: {
                postInstall = ''
                  mkdir -p $out/lib/pkgconfig
                  cat > $out/lib/pkgconfig/vulkan-memory-allocator.pc <<EOF
                  prefix=$out
                  includedir=$out/include
                  Name: VulkanMemoryAllocator
                  Description: Vulkan Memory Allocation Library
                  Version: ${old.version}
                  Cflags: -I$out/include
                  EOF
                ''
                + (old.postInstall or "");
              }))
              # 官方工具库（缺少 pc 文件，手动补丁）
              (vulkan-utility-libraries.overrideAttrs (old: {
                postInstall = ''
                  mkdir -p $out/lib/pkgconfig
                  cat > $out/lib/pkgconfig/vulkan-utility-libraries.pc <<EOF
                  prefix=$out
                  includedir=$out/include
                  libdir=$out/lib
                  Name: VulkanUtilityLibraries
                  Description: Vulkan Utility Libraries
                  Version: ${old.version}
                  Cflags: -I$out/include
                  Libs: -L$out/lib -lVulkanLayerSettings -lVulkanSafeStruct
                  EOF
                ''
                + (old.postInstall or "");
              }))
            ];

            # Wayland 库（Qt wayland 后端需要）
            waylandLibs = with pkgs; [
              wayland
              wayland-protocols
              libdrm
              wayland-scanner
            ];

            xorgLibs = with pkgs; [
              libX11
              libXrandr
              libXinerama
              libXi
              libXxf86vm
              libXcursor
              libxkbcommon
              xorgproto
              libxcb
              libXext
              libXfixes
              libXrender
              libXcomposite
              libXdamage
              libXres
            ];

            # CUDA 运行时库（PyTorch CUDA 需要）
            cudaLibs = with pkgs; [
              # CUDA 基础库
              cudaPackages_12.cuda_nvrtc
              cudaPackages_12.cuda_cudart
              # cuDNN 和 cuBLAS
              cudaPackages_12.cudnn
              cudaPackages_12.libcublas
            ];

            # SDL 库
            sdlLibs = with pkgs; [
              SDL2
              SDL2_gfx
              SDL2_net
              SDL2_mixer
              SDL2_ttf
              SDL2_sound
              SDL2_image
              SDL2_Pango
              sdl3
              sdl3-image
              sdl3-ttf
            ];

            # Qt 库
            qtLibs = with pkgs; [
              qt6.qtbase
              qt6.qtmultimedia
              qt6.qtdeclarative
              qt6.qttools
              qt6.qtnetworkauth
              qt6.qtwebchannel
              qt6.qtpositioning
              qt6.qt5compat
              qt6.qtsensors
              qt6.qtserialport
              qt6.qtremoteobjects
              qt6.qtimageformats
              qt6.qtsvg
              qt6.qtscxml
              qt6.qtwayland
            ];

            # GTK 库
            gtkLibs = with pkgs; [
              gtk2
              gtk3
              gtk4
            ];

            # 媒体库
            mediaLibs = with pkgs; [
              stb
              (opencv.override {
                enableFfmpeg = true;
                enablePython = false;
                enableContrib = true;
              })
              ffmpeg_7-full
              fontconfig
              freetype
              dav1d
              libaom
              libglibutil
              flac
            ];

            pythonEnv = with pkgs; [
              python314
              python314Packages.uv
              python314Packages.opencv4Full
            ];
          };

          pkgSets = withPkgs pkgs;

          allLibraries = pkgs.lib.flatten [
            pkgSets.systemLibs
            pkgSets.buildTools
            pkgSets.compilers
            pkgSets.graphicsLibs
            pkgSets.waylandLibs
            pkgSets.xorgLibs
            pkgSets.mediaLibs
            pkgSets.gtkLibs
            pkgSets.cppLibs
            pkgSets.cudaLibs
            pkgSets.sdlLibs
            pkgSets.qtLibs
          ];

        in
        {
          default = pkgs.mkShellNoCC {
            name = "proj";
            hardeningDisable = [ "fortify" ];

            packages = pkgs.lib.flatten [
              allLibraries
              pkgSets.pythonEnv
            ];

            shellHook = ''
              # for vscode
              # ln -sf "${pkgs.gdb}/bin/gdb" ./.vscode/gdb
              # NVIDIA 驱动库（PyTorch 需要 libcuda.so.1）
              export LD_LIBRARY_PATH=/run/opengl-driver/lib:$LD_LIBRARY_PATH
              # 添加系统 opencv4Full 到 PYTHONPATH（优先于 venv，有 AV1 支持）
              export PYTHONPATH=${pkgs.python314Packages.opencv4Full}/lib/python3.14/site-packages:$PYTHONPATH
              # Vulkan 验证层路径
              export VK_LAYER_PATH=${pkgs.vulkan-validation-layers}/share/vulkan/explicit_layer.d:$VK_LAYER_PATH
            '';

            # env.LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath allLibraries;
          };
        }
      );

    in
    {
      devShells = eachSystem;
    };
}
