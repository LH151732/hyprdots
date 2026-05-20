<div align="center">

# 【 Hyprland Config 】

**Intel Arrow Lake-S · RTX PRO 4000 · Dual Portable Monitors**

![Hyprland](https://img.shields.io/badge/Hyprland-58E1FF?style=for-the-badge&logo=hyprland&logoColor=white)
![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=for-the-badge&logo=archlinux&logoColor=white)
![NVIDIA](https://img.shields.io/badge/NVIDIA-RTX_PRO_4000-76B900?style=for-the-badge&logo=nvidia&logoColor=white)
![Wayland](https://img.shields.io/badge/Wayland-FFBC00?style=for-the-badge&logo=wayland&logoColor=black)

基于 [HyDE](https://github.com/prasanthrangan/hyprdots) 的 Hyprland 配置, 针对双便携屏上下排列 + NVIDIA 独显场景定制.

---

</div>

## • 硬件 •

| 组件   | 型号                                |
| :----- | :---------------------------------- |
| CPU    | Intel Arrow Lake-S                  |
| dGPU   | NVIDIA RTX PRO 4000 Blackwell SFF   |
| iGPU   | Intel Graphics                      |
| 显示器 | 2x RTK Monitor 2560x1600@240Hz (DP) |

## • 显示器布局 •

```
┌─────────────────┐
│                  │
│   上屏 (y=0)     │  2560x1600 @240Hz
│   1600x1000 eff  │  scale 1.6x
│                  │
├─────────────────┤
│                  │
│   下屏 (y=1000)  │  2560x1600 @240Hz
│   1600x1000 eff  │  scale 1.6x
│                  │
└─────────────────┘
```

> **已知问题**: 两个便携屏的 description / serial 完全相同, 且 DP 编号每次重启都会变化.
> 通过启动脚本动态检测 DP 编号并生成配置, 详见下方 [脚本说明](#-脚本-).

## • 目录结构 •

```
~/.config/hypr/
├── hyprland.conf            # 主配置 (环境变量, 输入, 布局, 手势)
├── monitors.conf            # 显示器配置 (source 动态配置 + fallback)
├── monitors_dynamic.conf    # [自动生成] 当前 DP 编号和位置
├── keybindings.conf         # 快捷键绑定
├── windowrules.conf         # 窗口规则
├── userprefs.conf           # 用户偏好
├── animations.conf          # 动画配置
├── animations/              # 动画预设
├── themes/                  # 主题配置
│   ├── common.conf
│   ├── theme.conf
│   └── colors.conf
├── Script/                  # 自定义脚本 (git 跟踪)
│   ├── install.sh           # 符号链接安装脚本
│   └── monitor_stack.sh     # 双屏上下排列检测脚本
├── CHANGELOG.md
└── README.md
```

## • 脚本 •

<details>
<summary><b>Script/install.sh</b> — 符号链接安装</summary>

遍历 `Script/` 下所有 `.sh` 脚本, 通过 `ln -s` 链接到 `~/.local/share/bin/`.

- 已有符号链接 → 更新指向
- 已有实体文件 → 跳过并警告
- 不存在 → 创建链接

```bash
./Script/install.sh
```

</details>

<details>
<summary><b>Script/monitor_stack.sh</b> — 双屏动态检测</summary>

启动时自动执行, 流程:

1. 等待显示器初始化 (sleep 1)
2. 通过 `hyprctl monitors -j` 检测所有 DP 开头的显示器
3. 将检测到的 DP 编号写入 `monitors_dynamic.conf`
4. 执行 `hyprctl reload` 使配置生效

生成的配置示例:

```conf
monitor = DP-6,2560x1600@240,0x1000,1.6
monitor = DP-8,2560x1600@240,0x0,1.6
```

</details>

## • 快速开始 •

```bash
# 1. 克隆配置
git clone ssh://git@100.96.87.78:30009/Config/hypr.git ~/.config/hypr
git checkout p3u-nv

# 2. 创建动态配置文件 (脚本启动时会自动填充)
touch ~/.config/hypr/monitors_dynamic.conf

# 3. 安装自定义脚本符号链接
~/.config/hypr/Script/install.sh

# 4. 重载 Hyprland
hyprctl reload
```

## • 分支 •

| 分支     | 设备                        | 说明                  |
| :------- | :-------------------------- | :-------------------- |
| `p3u-nv` | Arrow Lake-S + RTX PRO 4000 | 双便携屏, NVIDIA 驱动 |

## • 特殊配置说明 •

<details>
<summary><b>非整数缩放</b></summary>

Scale 1.6x 为非整数缩放, Hyprland 通过 fractional scaling 处理. 已启用:

```conf
# hyprland.conf
xwayland {
    force_zero_scaling = true
}
env = GDK_SCALE,1
```

XWayland 应用通过 `Xft.dpi` (`.Xresources`) 控制 DPI.

</details>

<details>
<summary><b>输入法</b></summary>

```conf
exec = fcitx5
env = XMODIFIERS, @im=fcitx
env = QT_IM_MODULE, fcitx
```

</details>

---

<div align="center">

_配置更新记录见 [CHANGELOG.md](CHANGELOG.md)_

</div>
