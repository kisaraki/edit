#!/usr/bin/env bash
# Modifications Copyright (c) 2026 KOSMOS, Tzushih.K.
# Licensed under the MIT License.

set -Eeuo pipefail

SCRIPT_PATH="$(readlink -f -- "${BASH_SOURCE[0]}")"
if [[ "${1:-}" == '--root' ]]; then
    REPO_ROOT="$2"
    SHARED_ROOT="$3"
else
    REPO_ROOT="${MSEDIT_TZK_REPO_ROOT:-$(cd -- "$(dirname -- "$SCRIPT_PATH")" && pwd)}"
    SHARED_ROOT="${MSEDIT_TZK_WSL_SHARED_ROOT:-/mnt/wsl-mount}"
fi

TARGET_DIR="${MSEDIT_TZK_WSL_TARGET_DIR:-$SHARED_ROOT/msedit-tzk-target}"
SOURCE_EXE="$TARGET_DIR/release/edit"
DEPLOY_ROOT="$SHARED_ROOT/msedit-tzk-deploy"
DEPLOY_BIN="$DEPLOY_ROOT/bin/edit"

if [[ ! -x "$SOURCE_EXE" ]]; then
    echo "WSL release executable not found: $SOURCE_EXE" >&2
    exit 1
fi

if [[ "$EUID" -ne 0 ]]; then
    # EN: Warn before sudo requests the user's password in the visible WSL terminal.
    # 中文：sudo 在可見的 WSL 終端機要求密碼前，先明確提醒使用者。
    echo 'NOTICE / 提醒：即將執行 sudo，以更新 /usr/local/bin 的 WSL 命令連結。'
    echo 'The WSL terminal may request your Ubuntu password. / WSL 終端機可能要求輸入 Ubuntu 密碼。'
    exec sudo bash "$SCRIPT_PATH" --root "$REPO_ROOT" "$SHARED_ROOT"
fi

for command_name in edit msedit msedit-tzk; do
    command_path="/usr/local/bin/$command_name"
    if [[ -e "$command_path" || -L "$command_path" ]]; then
        resolved="$(readlink -f -- "$command_path" || true)"
        # EN: -ef recognizes the same inode through /mnt/wsl-mount and /mnt/d/wsl-mount aliases.
        # 中文：使用 -ef 辨識 /mnt/wsl-mount 與 /mnt/d/wsl-mount 別名所指向的同一實體檔案。
        if [[ ! -e "$DEPLOY_BIN" || ! "$command_path" -ef "$DEPLOY_BIN" ]]; then
            echo "Refusing to replace unrelated command: $command_path -> $resolved" >&2
            exit 1
        fi
    fi
done

echo '=== msedit-tzk visible WSL/Ubuntu deployment ==='
echo "Source : $SOURCE_EXE"
echo "Deploy : $DEPLOY_ROOT"

install -d -m 0755 "$DEPLOY_ROOT/bin"
install -m 0755 "$SOURCE_EXE" "$DEPLOY_BIN"
install -m 0644 "$REPO_ROOT/LICENSE" "$DEPLOY_ROOT/LICENSE.txt"
ln -sfn edit "$DEPLOY_ROOT/bin/msedit"
ln -sfn edit "$DEPLOY_ROOT/bin/msedit-tzk"
for command_name in edit msedit msedit-tzk; do
    ln -sfn "$DEPLOY_BIN" "/usr/local/bin/$command_name"
done

SOURCE_HASH="$(sha256sum "$SOURCE_EXE" | awk '{print $1}')"
DEPLOY_HASH="$(sha256sum "$DEPLOY_BIN" | awk '{print $1}')"
if [[ "$SOURCE_HASH" != "$DEPLOY_HASH" ]]; then
    echo 'WSL deployed executable hash mismatch.' >&2
    exit 1
fi

"$DEPLOY_BIN" --version
echo "SHA-256: $DEPLOY_HASH"
for command_name in edit msedit msedit-tzk; do
    echo "$command_name -> $(readlink -f -- "/usr/local/bin/$command_name")"
done
echo 'WSL deployment completed successfully.'
