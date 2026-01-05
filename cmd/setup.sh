#!/bin/bash
# Setup script for Valheim server / Valheim 服务器安装/更新脚本
# Install or update Valheim dedicated server / 安装或更新 Valheim 专用服务器

set -e  # Exit on error / 遇到错误立即退出

# Constants / 常量
VALHEIM_APP_ID=896660
INSTALL_DIR="/valheim"

echo "📦 Valheim-Crate: Initializing SteamCMD..."
echo "   Valheim-Crate: 正在初始化 SteamCMD..."

# Ensure installation directory exists / 确保安装目录存在
mkdir -p "$INSTALL_DIR"

# Initialize SteamCMD configuration / 初始化 SteamCMD 配置
echo "🔧 Initializing SteamCMD configuration..."
echo "   正在初始化 SteamCMD 配置..."
steamcmd +quit

# Install/update Valheim server / 安装/更新 Valheim 服务器
echo "📥 Installing or updating Valheim server (App ID: $VALHEIM_APP_ID)..."
echo "   正在安装/更新 Valheim 服务器 (App ID: $VALHEIM_APP_ID)..."

# Use anonymous login / 使用匿名登录
echo "🔓 Using anonymous login..."
echo "   使用匿名登录..."

# Fetch app information first (helps with "Missing configuration" error) / 先获取应用信息（有助于解决 "Missing configuration" 错误）
echo "🔍 Fetching app information..."
echo "   正在获取应用信息..."
steamcmd +login anonymous +app_info_print $VALHEIM_APP_ID +quit > /dev/null 2>&1 || true

# Wait a bit to ensure Steam services are ready / 等待一下确保 Steam 服务就绪
sleep 1

# Install/update with anonymous login / 使用匿名登录安装/更新
steamcmd +force_install_dir "$INSTALL_DIR" +login anonymous +app_update $VALHEIM_APP_ID validate +quit

echo "✅ Valheim server installation/update completed!"
echo "   Valheim 服务器安装/更新完成！"