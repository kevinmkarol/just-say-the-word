#!/bin/zsh
# ABOUTME: Builds whisper.cpp's whisper-cli from its source at a pinned version and copies it to the path given: one
# ABOUTME: arm64 binary that needs nothing beyond macOS itself, so it can travel inside the app. Needs cmake.
set -euo pipefail
cd ${0:A:h}
version=1.9.5
sha256=ff1a9053feb509ff9d7729703355541ae9690073a6b1c40eb692c962e0dc1720
source=build/whisper.cpp-$version
built=$source/build/bin/whisper-cli

if [[ ! -x $built ]]; then
  if ! command -v cmake >/dev/null; then
    echo "cmake is required to build whisper-cli: brew install cmake" >&2
    exit 1
  fi
  mkdir -p build
  curl -fsSL -o build/whisper.cpp.tar.gz https://github.com/ggml-org/whisper.cpp/archive/refs/tags/v$version.tar.gz
  echo "$sha256  build/whisper.cpp.tar.gz" | shasum -a 256 -c - >/dev/null
  rm -rf $source
  tar -xzf build/whisper.cpp.tar.gz -C build
  rm build/whisper.cpp.tar.gz
  # The source's path on this Mac would otherwise be written into the binary by every assertion's __FILE__.
  # The Objective-C files are compiled with the C flags.
  flags="-ffile-prefix-map=$PWD/$source=whisper.cpp"
  cmake -S $source -B $source/build \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_FLAGS=$flags \
    -DCMAKE_CXX_FLAGS=$flags \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
    -DBUILD_SHARED_LIBS=OFF \
    -DGGML_NATIVE=OFF \
    -DGGML_OPENMP=OFF \
    -DGGML_METAL_EMBED_LIBRARY=ON \
    -DGGML_CCACHE=OFF \
    -DWHISPER_BUILD_TESTS=OFF \
    -DWHISPER_BUILD_SERVER=OFF >/dev/null
  # GGML_NATIVE=OFF: for every Apple silicon Mac, not only ones with this Mac's processor.
  # GGML_OPENMP=OFF: OpenMP would come from Homebrew, which the Mac the app lands on may not have.
  # GGML_METAL_EMBED_LIBRARY=ON: the Metal shaders are inside the binary instead of in a file beside it.
  cmake --build $source/build --target whisper-cli -j >/dev/null
  echo "built whisper-cli $version"
fi
cp $built $1
