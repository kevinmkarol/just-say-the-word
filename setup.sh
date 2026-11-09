#!/bin/zsh
# ABOUTME: One-shot setup for building from a clone: installs cmake, fetches the Whisper Medium and Silero VAD models
# ABOUTME: into models/, then runs install.sh. Idempotent: every step is skipped when already done.
set -euo pipefail
here=${0:A:h}
models=$here/models

if ! command -v brew >/dev/null; then
  echo "Homebrew is required: https://brew.sh" >&2
  exit 1
fi
if ! command -v xcodebuild >/dev/null; then
  echo "Xcode is required for swift build (the Command Line Tools alone are not enough)" >&2
  exit 1
fi

# cmake builds whisper-cli (whisper-cli.sh).
if command -v cmake >/dev/null; then
  echo "cmake is installed"
else
  brew install cmake
fi

mkdir -p $models

# A download lands under another name until it is complete, so an interrupted one is never taken for the model.
# build.sh checks each model against its published SHA-256.
fetch() {
  if [[ -s $models/$1 ]]; then
    echo "models/$1 is in place"
  else
    curl -fL --progress-bar -o $models/$1.part $2
    mv $models/$1.part $models/$1
    echo "downloaded models/$1"
  fi
}
fetch ggml-medium.bin https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin   # 1.5 GB
fetch ggml-silero-v5.1.2.bin https://huggingface.co/ggml-org/whisper-vad/resolve/main/ggml-silero-v5.1.2.bin

exec $here/install.sh
