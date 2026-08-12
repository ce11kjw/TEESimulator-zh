#!/system/bin/sh
# TEESimulator WebUI 中文翻译一键替换脚本
# 适配: Android Root Shell / APatch / Magisk / KernelSU
# 用法: sh replace-webroot-zh.sh

set -e

# ── 路径 ──
MODULE_DIR="/data/adb/modules/teesim"
WEBROOT_DIR="$MODULE_DIR/webroot"
REPO_URL="https://github.com/ce11kjw/TEESimulator-zh/archive/refs/heads/main.zip"
WORK_DIR="/data/local/tmp/teesim-zh"
BACKUP_DIR="/data/local/tmp/teesim-zh-backup-$(date +%Y%m%d%H%M%S)"

# ── 工具检测 ──
download() {
    # 尝试 curl
    if command -v curl >/dev/null 2>&1; then
        curl -sL "$1" -o "$2"
        return $?
    fi
    # 尝试 wget
    if command -v wget >/dev/null 2>&1; then
        wget -q "$1" -O "$2"
        return $?
    fi
    # 尝试 Termux 的 curl
    if [ -x "/data/data/com.termux/files/usr/bin/curl" ]; then
        /data/data/com.termux/files/usr/bin/curl -sL "$1" -o "$2"
        return $?
    fi
    # 尝试 Termux 的 wget
    if [ -x "/data/data/com.termux/files/usr/bin/wget" ]; then
        /data/data/com.termux/files/usr/bin/wget -q "$1" -O "$2"
        return $?;
    fi
    echo "[错误] 未找到下载工具 (curl/wget)"
    echo "  安装方法 (任选其一):"
    echo "  1. Termux: pkg install curl"
    echo "  2. 直接下载: 在浏览器打开下面的链接，把 zip 放到 /data/local/tmp/"
    echo "     $REPO_URL"
    return 1
}

extract_zip() {
    # 尝试 unzip
    if command -v unzip >/dev/null 2>&1; then
        unzip -qo "$1" -d "$2"
        return $?
    fi
    # 尝试 Termux 的 unzip
    if [ -x "/data/data/com.termux/files/usr/bin/unzip" ]; then
        /data/data/com.termux/files/usr/bin/unzip -qo "$1" -d "$2"
        return $?
    fi
    # 尝试 toybox
    if command -v toybox >/dev/null 2>&1; then
        toybox unzip -qo "$1" -d "$2" 2>/dev/null
        return $?
    fi
    echo "[错误] 未找到解压工具 (unzip)"
    echo "  安装方法: Termux 中运行 pkg install unzip"
    return 1
}

# ── 开始 ──
echo ""
echo "╔══════════════════════════════════════╗"
echo "║  TEESimulator WebUI 中文替换工具    ║"
echo "╚══════════════════════════════════════╝"
echo ""

# 检查模块是否安装
if [ ! -d "$MODULE_DIR" ]; then
    echo "[错误] TEESimulator 模块未安装: $MODULE_DIR"
    echo "  请先在 Magisk/KernelSU/APatch 中安装 TEESimulator"
    exit 1
fi

# 检查原始 webroot
if [ ! -d "$WEBROOT_DIR" ]; then
    echo "[错误] 原始 webroot 目录不存在: $WEBROOT_DIR"
    exit 1
fi

echo "[信息] 模块目录: $MODULE_DIR"
echo "[信息] webroot: $WEBROOT_DIR"

# 1. 清理旧的工作目录
echo ""
echo "[步骤 1/6] 准备工作目录..."
rm -rf "$WORK_DIR" 2>/dev/null
mkdir -p "$WORK_DIR"

# 2. 下载
echo "[步骤 2/6] 下载中文翻译包..."
if [ -f "$WORK_DIR/zh.zip" ]; then
    echo "  已有缓存，跳过下载"
else
    download "$REPO_URL" "$WORK_DIR/zh.zip"
    if [ ! -s "$WORK_DIR/zh.zip" ]; then
        echo "[错误] 下载失败"
        echo ""
        echo "  手动安装方法:"
        echo "  1. 在浏览器下载: $REPO_URL"
        echo "  2. 放到: $WORK_DIR/zh.zip"
        echo "  3. 重新运行此脚本"
        exit 1
    fi
fi
echo "  下载完成 ✓"

# 3. 解压
echo "[步骤 3/6] 解压..."
rm -rf "$WORK_DIR/extracted" 2>/dev/null
mkdir -p "$WORK_DIR/extracted"
extract_zip "$WORK_DIR/zh.zip" "$WORK_DIR/extracted"

# 找到解压后的目录
EXTRACTED_DIR=$(find "$WORK_DIR/extracted" -maxdepth 1 -name "TEESimulator-zh-*" -type d | head -1)
if [ ! -d "$EXTRACTED_DIR/webroot" ]; then
    echo "[错误] 解压结构异常，找不到 webroot"
    exit 1
fi
echo "  解压完成 ✓"

# 4. 备份
echo "[步骤 4/6] 备份原始 webroot..."
rm -rf "$BACKUP_DIR" 2>/dev/null
cp -a "$WEBROOT_DIR" "$BACKUP_DIR"
echo "  已备份到: $BACKUP_DIR ✓"

# 5. 替换
echo "[步骤 5/6] 替换为中文版..."
rm -rf "$WEBROOT_DIR"
cp -a "$EXTRACTED_DIR/webroot" "$WEBROOT_DIR"
chmod -R 755 "$WEBROOT_DIR" 2>/dev/null
echo "  替换完成 ✓"

# 6. 验证
echo "[步骤 6/6] 验证..."
if grep -q 'lang="zh-CN"' "$WEBROOT_DIR/index.html" 2>/dev/null; then
    echo "  验证通过 ✓ 中文版已就位"
else
    echo "  [警告] lang 属性可能未修改，但文件已替换"
fi

# 清理
rm -rf "$WORK_DIR" 2>/dev/null

echo ""
echo "╔══════════════════════════════════════╗"
echo "║         替换完成！                   ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "  备份位置: $BACKUP_DIR"
echo "  翻译仓库: https://github.com/ce11kjw/TEESimulator-zh"
echo ""
echo "  提示: 重启手机或重启 Magisk/KernelSU 服务即可生效"
echo "  还原: sh -c 'rm -rf $WEBROOT_DIR && cp -a $BACKUP_DIR $WEBROOT_DIR'"
echo ""
