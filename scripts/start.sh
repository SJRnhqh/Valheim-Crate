#!/bin/bash
# Start script for Valheim server / Valheim 服务器启动脚本

set -e

# 1. 基础检查
if [ ! -f "/valheim/valheim_server.x86_64" ]; then
    echo "❌ Valheim server not found. Please run setup.sh first."
    exit 1
fi

if [ -z "$SERVER_NAME" ] || [ -z "$SERVER_PASSWORD" ]; then
    echo "❌ SERVER_NAME and SERVER_PASSWORD are required."
    exit 1
fi

# 2. 默认变量
: "${SERVER_PORT:=2456}"
: "${SERVER_WORLD:=Dedicated}"
: "${SERVER_PUBLIC:=1}"
: "${SERVER_SAVE_DIR:=/valheim/saves}"
: "${SERVER_LOGFILE:=}"

echo "🎮 Starting Valheim server: ${SERVER_NAME} (${SERVER_WORLD})"

# 3. 构建参数
SERVER_ARGS=(
    -name "${SERVER_NAME}"
    -port "${SERVER_PORT}"
    -world "${SERVER_WORLD}"
    -password "${SERVER_PASSWORD}"
    -public "${SERVER_PUBLIC}"
    -savedir "${SERVER_SAVE_DIR}"
)

# 日志文件处理 (增加目录检查)
if [ -n "$SERVER_LOGFILE" ]; then
    mkdir -p "$(dirname "$SERVER_LOGFILE")"
    SERVER_ARGS+=(-logfile "${SERVER_LOGFILE}")
fi

# 预设与修改器
[ -n "$SERVER_PRESET" ] && SERVER_ARGS+=(-preset "${SERVER_PRESET}")

if [ -n "$SERVER_MODIFIER" ]; then
    IFS=',' read -ra MODIFIERS <<< "$SERVER_MODIFIER"
    for m in "${MODIFIERS[@]}"; do
        m=$(echo "$m" | xargs)
        if [[ "$m" == *":"* ]]; then
            k=$(echo "$m" | cut -d':' -f1 | xargs)
            v=$(echo "$m" | cut -d':' -f2 | xargs)
            SERVER_ARGS+=(-modifier "$k" "$v")
        fi
    done
fi

if [ -n "$SERVER_SETKEY" ]; then
    IFS=',' read -ra SETKEYS <<< "$SERVER_SETKEY"
    for k in "${SETKEYS[@]}"; do
        k=$(echo "$k" | xargs)
        [ -n "$k" ] && SERVER_ARGS+=(-setkey "$k")
    done
fi

# 高级参数
[ -n "$SERVER_SAVEINTERVAL" ] && SERVER_ARGS+=(-saveinterval "${SERVER_SAVEINTERVAL}")
[ -n "$SERVER_BACKUPS" ] && SERVER_ARGS+=(-backups "${SERVER_BACKUPS}")
[ -n "$SERVER_BACKUPSHORT" ] && SERVER_ARGS+=(-backupshort "${SERVER_BACKUPSHORT}")
[ -n "$SERVER_BACKUPLONG" ] && SERVER_ARGS+=(-backuplong "${SERVER_BACKUPLONG}")
[ "$SERVER_CROSSPLAY" = "1" ] && SERVER_ARGS+=(-crossplay)
[ -n "$SERVER_INSTANCEID" ] && SERVER_ARGS+=(-instanceid "${SERVER_INSTANCEID}")

# 4. 环境变量
export templdpath=$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/valheim/linux64:$LD_LIBRARY_PATH
export SteamAppId=892970

# ==============================================================================
# Auto-Patcher Logic
# ==============================================================================
if [ -n "$SERVER_SEED" ]; then
    # 只要种子不为空，就无脑运行工具。
    # 工具内部会自己判断：
    # 1. 没文件？ -> 退出，让游戏随机生成。
    # 2. 有文件且种子一样？ -> 退出，正常启动。
    # 3. 有文件且种子不一样？ -> 改文件，删DB，重启生效。
    
    echo "⚙️  Checking World Seed..."
    /app/scripts/valheim_seed "$SERVER_WORLD" "$SERVER_SAVE_DIR" "$SERVER_SEED"
fi
# ==============================================================================

echo "🚀 Executing Valheim Server..."
exec /valheim/valheim_server.x86_64 "${SERVER_ARGS[@]}"