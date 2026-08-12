#!/data/data/com.termux/files/usr/bin/bash
# TEESimulator WebUI 中文翻译一键替换脚本
# 用法: bash replace-webroot-zh.sh

set -e

# ── 颜色 ──
R='\033[1;31m' G='\033[1;32m' Y='\033[1;33m' C='\033[1;36m' B='\033[1m' N='\033[0m'

MODULE_DIR="/data/adb/modules/teesim"
WEBROOT_DIR="$MODULE_DIR/webroot"
REPO_URL="https://github.com/ce11kjw/TEESimulator-zh/archive/refs/heads/main.zip"
TMP_DIR="$PREFIX/tmp/teesim-zh-$$"

info()  { echo -e "${C}[信息]${N} $*"; }
ok()    { echo -e "${G}[完成]${N} $*"; }
warn()  { echo -e "${Y}[警告]${N} $*"; }
err()   { echo -e "${R}[错误]${N} $*"; exit 1; }

# ── 前置检查 ──
echo -e "\n${B}╔══════════════════════════════════════╗${N}"
echo -e "${B}║  TEESimulator WebUI 中文替换工具    ║${N}"
echo -e "${B}╚══════════════════════════════════════╝${N}\n"

# 检查 Termux 环境
[ -d "/data/data/com.termux" ] || err "请在 Termux 中运行此脚本"

# 检查模块是否安装
[ -d "$MODULE_DIR" ] || err "TEESimulator 模块未安装\n   请先在 Magisk/KernelSU 中安装 TEESimulator"

# 检查原始 webroot
[ -d "$WEBROOT_DIR" ] || err "原始 webroot 目录不存在: $WEBROOT_DIR"

# 检查是否有 root 权限
if [ ! -w "$MODULE_DIR" ]; then
    warn "没有直接写入权限，尝试通过 su 获取 root..."
    su -c "echo root_ok" >/dev/null 2>&1 || err "无法获取 root 权限"
    USE_SU=1
else
    USE_SU=0
fi

# ── 清理函数 ──
cleanup() {
    rm -rf "$TMP_DIR" 2>/dev/null
    rm -f "/tmp/teesim-zh.zip" 2>/dev/null
}
trap cleanup EXIT

# ── 开始替换 ──

# 1. 下载翻译包
info "正在下载中文翻译包..."
mkdir -p "$TMP_DIR"
if command -v curl >/dev/null 2>&1; then
    curl -sL "$REPO_URL" -o "$TMP_DIR/zh.zip" || err "下载失败，请检查网络连接"
elif command -v wget >/dev/null 2>&1; then
    wget -q "$REPO_URL" -O "$TMP_DIR/zh.zip" || err "下载失败，请检查网络连接"
else
    err "未找到 curl 或 wget，请先安装: pkg install curl"
fi

[ -s "$TMP_DIR/zh.zip" ] || err "下载的文件为空，请检查网络连接"

# 2. 解压
info "正在解压..."
cd "$TMP_DIR"
unzip -qo "zh.zip" -d "extracted" 2>/dev/null || err "解压失败"
EXTRACTED_DIR=$(find "$TMP_DIR/extracted" -maxdepth 1 -name "TEESimulator-zh-*" -type d | head -1)
[ -d "$EXTRACTED_DIR/webroot" ] || err "解压结构异常，找不到 webroot 目录"

# 3. 备份原文件
BACKUP_DIR="$PREFIX/tmp/teesim-zh-backup-$(date +%Y%m%d%H%M%S)"
info "正在备份原始 webroot..."
if [ "$USE_SU" = "1" ]; then
    su -c "cp -a '$WEBROOT_DIR' '$BACKUP_DIR'"
else
    cp -a "$WEBROOT_DIR" "$BACKUP_DIR"
fi
ok "已备份到: $BACKUP_DIR"

# 4. 替换 webroot
info "正在替换为中文版..."
if [ "$USE_SU" = "1" ]; then
    su -c "rm -rf '$WEBROOT_DIR'"
    su -c "cp -a '$EXTRACTED_DIR/webroot' '$WEBROOT_DIR'"
    su -c "chmod -R 755 '$WEBROOT_DIR'"
else
    rm -rf "$WEBROOT_DIR"
    cp -a "$EXTRACTED_DIR/webroot" "$WEBROOT_DIR"
    chmod -R 755 "$WEBROOT_DIR"
fi

# 5. 验证
[ -f "$WEBROOT_DIR/index.html" ] || err "替换后验证失败，index.html 不存在"
if grep -q 'lang="zh-CN"' "$WEBROOT_DIR/index.html" 2>/dev/null; then
    ok "验证通过 ✓ 中文版已就位"
else
    warn "lang 属性可能未修改，但文件已替换"
fi

# 6. 恢复 SELinux 上下文（可选）
if command -v restorecon >/dev/null 2>&1; then
    if [ "$USE_SU" = "1" ]; then
        su -c "restorecon -R '$WEBROOT_DIR'" 2>/dev/null || true
    else
        restorecon -R "$WEBROOT_DIR" 2>/dev/null || true
    fi
fi

echo ""
echo -e "${G}╔══════════════════════════════════════╗${N}"
echo -e "${G}║         替换完成！                   ║${N}"
echo -e "${G}╚══════════════════════════════════════╝${N}"
echo ""
echo -e "  ${B}备份位置:${N} $BACKUP_DIR"
echo -e "  ${B}翻译仓库:${N} https://github.com/ce11kjw/TEESimulator-zh"
echo ""
echo -e "  ${Y}提示:${N} 重启手机或重启 Magisk/KernelSU 服务即可生效"
echo -e "  ${Y}还原:${N} 恢复备份命令:"
echo -e "    ${C}su -c 'rm -rf $WEBROOT_DIR && cp -a $BACKUP_DIR $WEBROOT_DIR'${N}"
echo ""
