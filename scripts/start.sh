#!/bin/bash
# Start script for Valheim server / Valheim 服务器启动脚本
# Start the Valheim dedicated server / 启动 Valheim 专用服务器

set -e  # 遇到错误立即退出

# 检查服务器文件是否存在 / Check if server files exist
if [ ! -f "/valheim/valheim_server.x86_64" ]; then
    echo "❌ Valheim server not found. Please run setup.sh first."
    echo "   服务器文件未找到，请先运行 setup.sh"
    exit 1
fi

# Required environment variables (must be set in docker-compose.yml) / 必填环境变量（必须在 docker-compose.yml 中设置）
if [ -z "$SERVER_NAME" ]; then
    echo "❌ SERVER_NAME is required. Please set it in docker-compose.yml"
    echo "   SERVER_NAME 是必填项，请在 docker-compose.yml 中设置"
    exit 1
fi

if [ -z "$SERVER_PASSWORD" ]; then
    echo "❌ SERVER_PASSWORD is required. Please set it in docker-compose.yml"
    echo "   SERVER_PASSWORD 是必填项，请在 docker-compose.yml 中设置"
    exit 1
fi

# Optional environment variables with defaults / 可选环境变量（带默认值）
: "${SERVER_PORT:=2456}"
: "${SERVER_WORLD:=Dedicated}"
: "${SERVER_PUBLIC:=1}"
: "${SERVER_SAVE_DIR:=/valheim/saves}"
: "${SERVER_LOGFILE:=}"

echo "🎮 Starting Valheim server:"
echo "   Name:     ${SERVER_NAME}"
echo "   World:    ${SERVER_WORLD}"
echo "   Port:     ${SERVER_PORT}/udp"
echo "   Password: [hidden]"
echo "   Public:   ${SERVER_PUBLIC}"

# Build server command arguments / 构建服务器命令参数
SERVER_ARGS=(
    -name "${SERVER_NAME}"
    -port "${SERVER_PORT}"
    -world "${SERVER_WORLD}"
    -password "${SERVER_PASSWORD}"
    -public "${SERVER_PUBLIC}"
)

# Add save directory / 添加存档目录
SERVER_ARGS+=(-savedir "${SERVER_SAVE_DIR}")
echo "   Save dir: ${SERVER_SAVE_DIR}"

# Add log file if specified / 如果指定了日志文件则添加
if [ -n "$SERVER_LOGFILE" ]; then
    SERVER_ARGS+=(-logfile "${SERVER_LOGFILE}")
    echo "   Log file: ${SERVER_LOGFILE}"
fi

# Add seed if specified / 如果指定了种子则添加
if [ -n "$SERVER_SEED" ]; then
    SERVER_ARGS+=(-seed "${SERVER_SEED}")
    echo "   Seed:     ${SERVER_SEED}"
fi

# Add preset if specified / 如果指定了预设则添加
if [ -n "$SERVER_PRESET" ]; then
    SERVER_ARGS+=(-preset "${SERVER_PRESET}")
    echo "   Preset:   ${SERVER_PRESET}"
fi

# Add modifiers if specified / 如果指定了修改器则添加
# Format: "modifier1:value1,modifier2:value2" / 格式: "modifier1:value1,modifier2:value2"
if [ -n "$SERVER_MODIFIER" ]; then
    IFS=',' read -ra MODIFIERS <<< "$SERVER_MODIFIER"
    for modifier_pair in "${MODIFIERS[@]}"; do
        modifier_pair=$(echo "$modifier_pair" | xargs)  # Trim whitespace / 去除空格
        if [[ "$modifier_pair" == *":"* ]]; then
            # Format: modifier:value / 格式: modifier:value
            modifier=$(echo "$modifier_pair" | cut -d':' -f1 | xargs)
            value=$(echo "$modifier_pair" | cut -d':' -f2 | xargs)
            SERVER_ARGS+=(-modifier "${modifier}" "${value}")
            echo "   Modifier: ${modifier} ${value}"
        fi
    done
fi

# Add setkey if specified / 如果指定了 setkey 则添加
# Format: "key1,key2,key3" / 格式: "key1,key2,key3"
if [ -n "$SERVER_SETKEY" ]; then
    IFS=',' read -ra SETKEYS <<< "$SERVER_SETKEY"
    for key in "${SETKEYS[@]}"; do
        key=$(echo "$key" | xargs)  # Trim whitespace / 去除空格
        if [ -n "$key" ]; then
            SERVER_ARGS+=(-setkey "${key}")
            echo "   SetKey:   ${key}"
        fi
    done
fi

# Add advanced settings if specified / 如果指定了高级设置则添加
if [ -n "$SERVER_SAVEINTERVAL" ]; then
    SERVER_ARGS+=(-saveinterval "${SERVER_SAVEINTERVAL}")
    echo "   Save interval: ${SERVER_SAVEINTERVAL}s"
fi

if [ -n "$SERVER_BACKUPS" ]; then
    SERVER_ARGS+=(-backups "${SERVER_BACKUPS}")
    echo "   Backups: ${SERVER_BACKUPS}"
fi

if [ -n "$SERVER_BACKUPSHORT" ]; then
    SERVER_ARGS+=(-backupshort "${SERVER_BACKUPSHORT}")
    echo "   Backup short: ${SERVER_BACKUPSHORT}s"
fi

if [ -n "$SERVER_BACKUPLONG" ]; then
    SERVER_ARGS+=(-backuplong "${SERVER_BACKUPLONG}")
    echo "   Backup long: ${SERVER_BACKUPLONG}s"
fi

if [ -n "$SERVER_CROSSPLAY" ] && [ "$SERVER_CROSSPLAY" = "1" ]; then
    SERVER_ARGS+=(-crossplay)
    echo "   Crossplay: enabled"
fi

if [ -n "$SERVER_INSTANCEID" ]; then
    SERVER_ARGS+=(-instanceid "${SERVER_INSTANCEID}")
    echo "   Instance ID: ${SERVER_INSTANCEID}"
fi

echo ""

# Set environment variables for Valheim server / 设置 Valheim 服务器环境变量
# Save original LD_LIBRARY_PATH / 保存原始的 LD_LIBRARY_PATH
export templdpath=$LD_LIBRARY_PATH

# Set LD_LIBRARY_PATH to include linux64 directory / 设置 LD_LIBRARY_PATH 包含 linux64 目录
# This is required for the server to find its libraries / 这是服务器查找库文件所必需的
export LD_LIBRARY_PATH=/valheim/linux64:$LD_LIBRARY_PATH

# Set Steam App ID for Valheim server runtime / 设置 Valheim 服务器运行时的 Steam App ID
# Note: 892970 is the runtime App ID (from official script), 896660 is the dedicated server App ID for SteamCMD
# 注意：892970 是运行时 App ID（来自官方脚本），896660 是 SteamCMD 下载专用服务器的 App ID
export SteamAppId=892970

# Start Valheim server (foreground) / 启动 Valheim 服务器（前台运行）
exec /valheim/valheim_server.x86_64 "${SERVER_ARGS[@]}"

