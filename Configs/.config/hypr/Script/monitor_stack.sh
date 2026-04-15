#!/bin/bash
# 将两个相同的外接显示器设为上下排列
# 由于 DP-x 编号每次变化, 动态检测并写入配置文件
#
# 生成文件: ~/.config/hypr/monitors_dynamic.conf
# 被 monitors.conf 通过 source 引入
#
# 工作方式:
#   1. 启动时立即检测一次
#   2. 后台监听 Hyprland monitoraddedv2 事件, 热插拔时自动重新检测

DYNAMIC_CONF="$HOME/.config/hypr/monitors_dynamic.conf"

apply_monitors() {
    sleep 0.5  # 等待显示器初始化

    mapfile -t monitors < <(hyprctl monitors -j | jq -r '.[].name' | grep '^DP-')

    if [[ ${#monitors[@]} -ge 2 ]]; then
        cat > "$DYNAMIC_CONF" <<EOF
# 自动生成 - 请勿手动编辑
# 由 monitor_stack.sh 在启动时根据当前 DP 编号生成
monitor = ${monitors[0]},2560x1600@240,0x1000,1.6
monitor = ${monitors[1]},2560x1600@240,0x0,1.6
EOF
        hyprctl reload
    fi
}

# 启动时立即执行一次
apply_monitors

# 后台监听显示器热插拔事件
SOCK="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
socat -U - "UNIX-CONNECT:$SOCK" | while IFS= read -r line; do
    if [[ "$line" == monitoraddedv2* ]]; then
        apply_monitors
    fi
done
