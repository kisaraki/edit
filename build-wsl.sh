#!/usr/bin/env bash
# Modifications Copyright (c) 2026 KOSMOS, Tzushih.K.
# Licensed under the MIT License.

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${MSEDIT_TZK_REPO_ROOT:-$SCRIPT_DIR}"
SHARED_ROOT="${MSEDIT_TZK_WSL_SHARED_ROOT:-/mnt/wsl-mount}"
TARGET_DIR="${MSEDIT_TZK_WSL_TARGET_DIR:-$SHARED_ROOT/msedit-tzk-target}"
BUILD_DIR="$SHARED_ROOT/msedit-tzk-build"
TRANSCRIPT_PATH="$BUILD_DIR/build-transcript.txt"
RESULT_PATH="$BUILD_DIR/build-result.txt"
SKIP_TESTS="${MSEDIT_TZK_SKIP_TESTS:-0}"

# EN: Keep native Linux artifacts on the shared data drive and show every command in the WSL terminal.
# 中文：Linux 原生產物固定留在共用資料碟，所有命令均顯示於 WSL 終端機。
mkdir -p "$BUILD_DIR" "$TARGET_DIR"
exec > >(tee "$TRANSCRIPT_PATH") 2>&1

write_failure() {
    local exit_code=$?
    printf 'success=false\nexit_code=%s\ntimestamp=%s\n' \
        "$exit_code" "$(date --iso-8601=seconds)" > "$RESULT_PATH"
    echo "WSL BUILD FAILED (exit $exit_code)" >&2
    exit "$exit_code"
}
trap write_failure ERR

if ! mountpoint -q "$SHARED_ROOT"; then
    echo "Shared mount is unavailable: $SHARED_ROOT" >&2
    exit 1
fi
if [[ ! -f "$REPO_ROOT/Cargo.toml" ]]; then
    echo "Repository not found: $REPO_ROOT" >&2
    exit 1
fi
if [[ ! -f "$HOME/.cargo/env" ]]; then
    echo "The Ubuntu Rust environment is missing: $HOME/.cargo/env" >&2
    exit 1
fi
source "$HOME/.cargo/env"
for command_name in cargo rustc rustup gcc pkg-config; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Required WSL build command is missing: $command_name" >&2
        exit 1
    fi
done

export CARGO_TARGET_DIR="$TARGET_DIR"
cd "$REPO_ROOT"

echo '=== msedit-tzk visible WSL/Ubuntu build ==='
echo "Ubuntu    : $(. /etc/os-release; echo "$PRETTY_NAME")"
echo "Repository: $REPO_ROOT"
echo "Shared    : $SHARED_ROOT"
echo "Target    : $CARGO_TARGET_DIR"
echo "Rust      : $(rustc --version)"
echo "Cargo     : $(cargo --version)"
RUSTC_VERBOSE="$(rustc -vV)"
if ! grep -Fqx 'host: x86_64-unknown-linux-gnu' <<< "$RUSTC_VERBOSE"; then
    echo 'The active Rust compiler is not the native WSL/Linux toolchain.' >&2
    exit 1
fi

rustup component add rustfmt
cargo fmt --all --check
if [[ "$SKIP_TESTS" != '1' ]]; then
    cargo test --workspace
    cargo test -p edit icu::tests::init -- --ignored --exact
fi
cargo build -p edit --release

RELEASE_EXE="$CARGO_TARGET_DIR/release/edit"
if [[ ! -x "$RELEASE_EXE" ]]; then
    echo "WSL release executable not found: $RELEASE_EXE" >&2
    exit 1
fi

mapfile -t VERSION_LINES < <("$RELEASE_EXE" --version)
if [[ "${#VERSION_LINES[@]}" -ne 2 ]] ||
    [[ ! "${VERSION_LINES[0]}" =~ ^edit\ original\ version:\ [0-9]+\.[0-9]+\.[0-9]+$ ]] ||
    [[ ! "${VERSION_LINES[1]}" =~ ^tzk\ version:\ [0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo 'Unexpected WSL version declaration.' >&2
    exit 1
fi

SHA256="$(sha256sum "$RELEASE_EXE" | awk '{print $1}')"
printf 'success=true\ntimestamp=%s\nrelease=%s\nsha256=%s\n%s\n%s\n' \
    "$(date --iso-8601=seconds)" "$RELEASE_EXE" "$SHA256" \
    "${VERSION_LINES[0]}" "${VERSION_LINES[1]}" > "$RESULT_PATH"
trap - ERR

echo
echo '=== WSL build completed successfully ==='
printf '%s\n%s\n' "${VERSION_LINES[0]}" "${VERSION_LINES[1]}"
echo "SHA-256: $SHA256"
echo "Release : $RELEASE_EXE"
echo "Log     : $TRANSCRIPT_PATH"
