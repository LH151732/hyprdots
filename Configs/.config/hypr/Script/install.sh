#!/bin/bash
# 将 Script/ 下所有 .sh 脚本 ln -s 到 ~/.local/share/bin/
# 已存在的同名符号链接会被更新, 已存在的实体文件会跳过并警告

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$HOME/.local/share/bin"

mkdir -p "$TARGET_DIR"

for script in "$SCRIPT_DIR"/*.sh; do
    name="$(basename "$script")"
    [[ "$name" == "install.sh" ]] && continue

    target="$TARGET_DIR/$name"

    if [[ -L "$target" ]]; then
        # 已有符号链接, 更新指向
        ln -sf "$script" "$target"
        echo "[更新] $name -> $script"
    elif [[ -e "$target" ]]; then
        # 已有实体文件, 跳过
        echo "[跳过] $name (已存在实体文件, 请手动处理)"
    else
        ln -s "$script" "$target"
        echo "[链接] $name -> $script"
    fi
done
