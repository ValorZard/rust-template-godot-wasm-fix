#!/usr/bin/env bash
set -e
# Script to build the web assets for the project
# Assumes that the Rust toolchain and Emscripten are properly set up
# Usage: ./utils/web-build.sh [crate_name] [release|debug]
# Navigate to the root directory of the project
cd "$(dirname "$0")/.."

# Crate name argument
CRATE_NAME=${1:-grust}
# Optional profile argument (default: debug)
PROFILE=${2:-debug}

# Cargo only accepts --release flag; debug is the default and needs no flag
if [ "$PROFILE" = "release" ]; then
    PROFILE_FLAG="--release"
else
    PROFILE_FLAG=""
fi

echo "Building crate: $CRATE_NAME with profile: $PROFILE"

# std must be rebuilt with panic_abort so that panic_unwind is never linked in.
# Otherwise the prebuilt std imports the __cpp_exception tag, 
# which Godot's web export template does not provide. 
# See .cargo/config.toml for more context.
BUILD_STD="-Zbuild-std=std,panic_abort"

# Make thread build
RUSTFLAGS="-C link-args=-pthread \
-C target-feature=+atomics \
-C link-args=-sSIDE_MODULE=2 \
-Z default-visibility=hidden \
-Z link-native-libraries=no \
-C panic=abort" cargo +nightly build $BUILD_STD --features wasm,threads --target wasm32-unknown-emscripten $PROFILE_FLAG

# remove old build
rm -f target/wasm32-unknown-emscripten/$PROFILE/$CRATE_NAME.threads.wasm
mv target/wasm32-unknown-emscripten/$PROFILE/$CRATE_NAME.wasm \
   target/wasm32-unknown-emscripten/$PROFILE/$CRATE_NAME.threads.wasm

# Make non-thread build (rustflags come from .cargo/config.toml)
cargo +nightly build --features wasm-nothreads $BUILD_STD --target wasm32-unknown-emscripten $PROFILE_FLAG