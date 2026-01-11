#!/bin/bash
# ============================================================================
# Valheim Server Management Script / Valheim 服务器管理脚本
# ============================================================================
# This script provides a complete management interface for Valheim dedicated
# server running in Docker containers.
# 本脚本为运行在 Docker 容器中的 Valheim 专用服务器提供完整的管理接口
#
# Usage / 用法:
#   ./server.sh [install|update|start|stop|restart|status|remove]
#
# Commands / 命令:
#   install              - First time installation (build image, create container, install server, update environment)
#                        首次安装（构建镜像、创建容器、安装服务器、更新环境变量）
#   update               - Update server files only (no image rebuild, requires install first)
#                        仅更新服务器文件（不重建镜像，需要先安装）
#   start                - Start the server (container level)
#                        启动服务器（容器层面）
#   stop                 - Stop the server (container level, container remains)
#                        停止服务器（容器层面，容器保留）
#   restart              - Restart the server (container level, stop then start)
#                        重启服务器（容器层面，先停止再启动）
#   status               - Show server status (container, process, files, ports)
#                        显示服务器状态（容器、进程、文件、端口）
#   remove               - Remove container and image (game data preserved)
#                        删除容器和镜像（游戏数据保留）
# ============================================================================

set -e  # Exit immediately if a command exits with a non-zero status / 遇到错误立即退出

# ============================================================================
# Color definitions for terminal output / 终端输出颜色定义
# ============================================================================
RED='\033[0;31m'      # Error messages / 错误信息
GREEN='\033[0;32m'    # Success messages / 成功信息
YELLOW='\033[1;33m'   # Warning/Info messages / 警告/信息
BLUE='\033[0;34m'     # Action messages / 操作信息
NC='\033[0m'          # No Color (reset) / 无颜色（重置）

# ============================================================================
# Get script directory and change to it / 获取脚本目录并切换到该目录
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ============================================================================
# Function: check_docker
# 功能: 检查 Docker 环境
# Description: Verify Docker and Docker Compose are installed
# 描述: 验证 Docker 和 Docker Compose 是否已安装
# ============================================================================
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker is not installed. Please install Docker first.${NC}"
        echo -e "${RED}   Docker 未安装，请先安装 Docker${NC}"
        echo -e "${YELLOW}   Installation guide: https://docs.docker.com/get-docker/${NC}"
        echo -e "${YELLOW}   安装指南: https://docs.docker.com/get-docker/${NC}"
        exit 1
    fi

    # Check if Docker Compose is installed / 检查 Docker Compose 是否安装
    if ! command -v docker compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo -e "${RED}❌ Docker Compose is not installed. Please install Docker Compose first.${NC}"
        echo -e "${RED}   Docker Compose 未安装，请先安装 Docker Compose${NC}"
        echo -e "${YELLOW}   Installation guide: https://docs.docker.com/compose/install/${NC}"
        echo -e "${YELLOW}   安装指南: https://docs.docker.com/compose/install/${NC}"
        exit 1
    fi
}

# ============================================================================
# Function: install_server
# 功能: 安装服务器
# Description: Build Docker image, create container, and install server files
#              (Does NOT start the game process)
# 描述: 构建镜像、创建容器并安装服务器文件（不启动游戏进程）
# ============================================================================
install_server() {
    echo -e "${GREEN}📦 Valheim-Crate: Installing server...${NC}"
    echo -e "${GREEN}   Valheim-Crate: 正在安装服务器...${NC}"
    echo -e "${BLUE}ℹ️  Note: Game data in /opt/server/valheim will be preserved.${NC}"
    echo -e "${BLUE}   注意：/opt/server/valheim 中的游戏数据将会被保留。${NC}"
    echo ""

    # Step 1: Build and create environment / 步骤 1: 构建并创建环境
    echo -e "${YELLOW}📦 Step 1/2: Building Docker image and creating environment...${NC}"
    echo -e "${YELLOW}   步骤 1/2: 构建 Docker 镜像并创建运行环境...${NC}"
    
    # Force rebuild and recreate container / 强制重建镜像和容器
    docker compose up -d --build --force-recreate --remove-orphans valheim

    # 🧹 Auto-cleanup: Remove old dangling images (<none>)
    # 自动清理：删除因重建产生的旧悬空镜像
    echo -e "${YELLOW}🧹 Cleaning up old Docker images...${NC}"
    docker image prune -f --filter "dangling=true"

    echo -e "${YELLOW}⏳ Waiting for container to initialize...${NC}"
    sleep 3

    if ! docker compose ps | grep -q "Up"; then
        echo -e "${RED}❌ Container failed to start environment${NC}"
        docker compose logs
        exit 1
    fi

    # Step 2: Install/Update server files / 步骤 2: 安装/更新服务器文件
    echo -e "${YELLOW}📥 Step 2/2: Downloading/Updating Valheim server files...${NC}"
    echo -e "${YELLOW}   步骤 2/2: 下载/更新 Valheim 服务器文件...${NC}"
    
    if ! docker compose exec -T valheim /app/scripts/setup.sh; then
        echo -e "${RED}❌ Server installation failed${NC}"
        echo -e "${YELLOW}   View logs: docker compose logs valheim${NC}"
        exit 1
    fi

    echo -e "${GREEN}✅ Server installation completed successfully!${NC}"
    echo -e "${GREEN}   服务器安装成功！${NC}"
    echo ""
    
    # Guide user / 引导用户
    echo -e "${BLUE}👉 Next Step: Start the server${NC}"
    echo -e "   Run command: ${GREEN}./server.sh start${NC}"
}

# ============================================================================
# Function: update_server
# 功能: 更新服务器
# Description: Update Valheim server files to latest version
#              Safely stops the server first to prevent data corruption
# 描述: 更新 Valheim 服务器文件到最新版本
#       为了防止数据损坏，会先安全地停止服务器
# ============================================================================
update_server() {
    echo -e "${GREEN}🔄 Valheim-Crate: Updating server...${NC}"
    echo -e "${GREEN}   Valheim-Crate: 正在更新服务器...${NC}"
    echo ""

    # 1. Check if installed / 检查是否安装
    if [ -z "$(docker compose ps -a -q valheim 2>/dev/null)" ]; then
        echo -e "${RED}❌ Server not installed. Please run './server.sh install' first${NC}"
        echo -e "${RED}   服务器未安装。请先运行 './server.sh install'${NC}"
        exit 1
    fi

    # 2. Stop server to ensure safe update / 停止服务器以确保存档安全
    # Even if it looks like it's not running, we stop the container to be sure no processes are locking files
    # 即使看起来没在运行，我们也停止容器，确保没有进程锁定文件
    if docker compose ps | grep -q "Up"; then
        echo -e "${YELLOW}🛑 Stopping server to perform safe update...${NC}"
        echo -e "${YELLOW}   正在停止服务器以执行安全更新...${NC}"
        docker compose stop valheim
        sleep 2
    fi

    # 3. Start container in idle mode / 以空闲模式启动容器
    # This starts the container (OS + Tools) but DOES NOT start the game server process
    # 这会启动容器（操作系统+工具），但【不会】启动游戏服务器进程
    echo -e "${YELLOW}📦 Starting container environment...${NC}"
    echo -e "${YELLOW}   正在启动容器环境...${NC}"
    docker compose up -d valheim
    
    # Wait for container to be ready
    sleep 2

    # 4. Run update script / 运行更新脚本
    echo -e "${YELLOW}📥 Downloading/Updating Valheim server files...${NC}"
    echo -e "${YELLOW}   正在下载/更新 Valheim 服务器文件...${NC}"
    echo -e "${YELLOW}   This may take a few minutes...${NC}"
    echo -e "${YELLOW}   这可能需要几分钟...${NC}"
    
    if ! docker compose exec -T valheim /app/scripts/setup.sh; then
        echo -e "${RED}❌ Server update failed${NC}"
        echo -e "${RED}   服务器更新失败${NC}"
        echo -e "${YELLOW}   View logs: docker compose logs valheim${NC}"
        exit 1
    fi

    echo -e "${GREEN}✅ Server update completed successfully!${NC}"
    echo -e "${GREEN}   服务器更新成功！${NC}"
    echo ""
    
    # Guide user / 引导用户
    echo -e "${BLUE}👉 Next Step: Start the server${NC}"
    echo -e "   Run command: ${GREEN}./server.sh start${NC}"
}

# ============================================================================
# Function: start_server
# 功能: 启动服务器
# Description: Start Valheim server process
#              - Strict Mode: Requires 'install' to be run first
#              - Starts container if stopped, then starts game process
# 描述: 启动 Valheim 服务器进程
#        - 严格模式：要求必须先运行 'install'
#        - 如果容器已停止会自动启动容器，然后启动游戏进程
# ============================================================================
start_server() {
    echo -e "${GREEN}🚀 Valheim-Crate: Starting server...${NC}"
    echo -e "${GREEN}   Valheim-Crate: 正在启动服务器...${NC}"
    echo ""

    # 1. Strict Check: Is the server installed? (Container exists)
    # 1. 严格检查：服务器是否已安装？（容器是否存在）
    # Use 'ps -a' to check for stopped containers too / 使用 'ps -a' 检查包括已停止的容器
    if [ -z "$(docker compose ps -a -q valheim 2>/dev/null)" ]; then
        echo -e "${RED}❌ Server environment not found.${NC}"
        echo -e "${RED}   未找到服务器环境。${NC}"
        echo -e "${YELLOW}   This is the first run. Please install first:${NC}"
        echo -e "${YELLOW}   这是首次运行。请先执行安装:${NC}"
        echo -e "${GREEN}   ./server.sh install${NC}"
        exit 1
    fi

    # 2. Ensure container is running (Infrastructure level)
    # 2. 确保容器正在运行（基础设施层面）
    # If container exists but is stopped, start it / 如果容器存在但已停止，启动它
    if ! docker compose ps valheim | grep -q "Up"; then
        echo -e "${YELLOW}📦 Starting container environment...${NC}"
        echo -e "${YELLOW}   正在启动容器环境...${NC}"
        docker compose up -d valheim
        sleep 3
    fi

    # 3. Check for server binary (Application level)
    # 3. 检查服务器二进制文件（应用层面）
    if ! docker compose exec -T valheim test -f /valheim/valheim_server.x86_64 2>/dev/null; then
        echo -e "${RED}❌ Valheim server files are missing inside the container.${NC}"
        echo -e "${RED}   容器内缺少 Valheim 服务器文件。${NC}"
        echo -e "${YELLOW}   The environment exists but the game is not installed.${NC}"
        echo -e "${YELLOW}   环境存在但游戏未安装。${NC}"
        echo -e "${YELLOW}   Please run update to fix: ./server.sh update${NC}"
        echo -e "${YELLOW}   请运行更新以修复: ./server.sh update${NC}"
        exit 1
    fi

    # 4. Start the game process
    # 4. 启动游戏进程
    echo -e "${YELLOW}🎮 Starting Valheim server process...${NC}"
    echo -e "${YELLOW}   正在启动 Valheim 服务器进程...${NC}"
    
    # Check if server is already running / 检查服务器是否已在运行
    if docker compose exec -T valheim pgrep -f "valheim_server.x86_64" > /dev/null 2>&1; then
        echo -e "${YELLOW}ℹ️  Server is already running${NC}"
        echo -e "${YELLOW}   服务器已在运行${NC}"
        SERVER_PID=$(docker compose exec -T valheim pgrep -f "valheim_server.x86_64" | head -1)
        echo -e "${GREEN}   Server PID: $SERVER_PID / 服务器进程 ID: $SERVER_PID${NC}"
    else
        # Check required configuration / 检查必填配置
        echo -e "${BLUE}📋 Checking server configuration...${NC}"
        echo -e "${BLUE}   正在检查服务器配置...${NC}"
        
        # Verify required environment variables / 验证必填环境变量
        if ! docker compose exec -T valheim bash -c '[ -n "$SERVER_NAME" ] && [ -n "$SERVER_PASSWORD" ]' 2>/dev/null; then
            echo -e "${RED}❌ Missing required configuration (SERVER_NAME or SERVER_PASSWORD)${NC}"
            echo -e "${RED}   缺少必填配置（SERVER_NAME 或 SERVER_PASSWORD）${NC}"
            echo -e "${YELLOW}   Please edit docker compose.yml and set SERVER_NAME and SERVER_PASSWORD${NC}"
            echo -e "${YELLOW}   请编辑 docker compose.yml 并设置 SERVER_NAME 和 SERVER_PASSWORD${NC}"
            exit 1
        fi
        
        # Start server in background / 在后台启动服务器
        echo -e "${BLUE}🚀 Launching server process...${NC}"
        echo -e "${BLUE}   正在启动服务器进程...${NC}"
        
        if ! docker compose exec -d valheim /app/scripts/start.sh; then
            echo -e "${RED}❌ Failed to start server process${NC}"
            echo -e "${RED}   启动服务器进程失败${NC}"
            echo -e "${YELLOW}   View logs: docker compose logs valheim${NC}"
            echo -e "${YELLOW}   查看日志: docker compose logs valheim${NC}"
            exit 1
        fi
        
        # Wait for server to start with retry / 等待服务器启动（带重试）
        echo -e "${YELLOW}⏳ Waiting for server to start...${NC}"
        echo -e "${YELLOW}   等待服务器启动...${NC}"
        
        MAX_RETRIES=10
        RETRY_COUNT=0
        SERVER_STARTED=false
        
        while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
            sleep 2
            if docker compose exec -T valheim pgrep -f "valheim_server.x86_64" > /dev/null 2>&1; then
                SERVER_STARTED=true
                break
            fi
            RETRY_COUNT=$((RETRY_COUNT + 1))
            echo -e "${YELLOW}   Attempt $RETRY_COUNT/$MAX_RETRIES...${NC}"
        done
        
        # Check if server started successfully / 检查服务器是否成功启动
        if [ "$SERVER_STARTED" = true ]; then
            SERVER_PID=$(docker compose exec -T valheim pgrep -f "valheim_server.x86_64" | head -1)
            echo -e "${GREEN}✅ Valheim server started successfully${NC}"
            echo -e "${GREEN}   Valheim 服务器已成功启动${NC}"
            echo -e "${GREEN}   Server PID: $SERVER_PID / 服务器进程 ID: $SERVER_PID${NC}"
        else
            echo -e "${RED}❌ Server failed to start after ${MAX_RETRIES} attempts${NC}"
            echo -e "${RED}   服务器在 ${MAX_RETRIES} 次尝试后仍未能启动${NC}"
            echo -e "${YELLOW}   Checking logs for errors...${NC}"
            echo -e "${YELLOW}   正在检查日志中的错误...${NC}"
            echo ""
            # Show last few lines of logs / 显示最后几行日志
            docker compose logs --tail=20 valheim 2>/dev/null || true
            echo ""
            echo -e "${YELLOW}   View full logs: docker compose logs valheim${NC}"
            echo -e "${YELLOW}   查看完整日志: docker compose logs valheim${NC}"
            echo -e "${YELLOW}   Or check container logs: docker logs valheim-server${NC}"
            echo -e "${YELLOW}   或查看容器日志: docker logs valheim-server${NC}"
            exit 1
        fi
    fi
    echo ""

    # Show server configuration summary / 显示服务器配置摘要
    echo -e "${GREEN}📋 Server Configuration / 服务器配置:${NC}"
    SERVER_NAME=$(docker compose exec -T valheim bash -c 'echo "$SERVER_NAME"' 2>/dev/null || echo "N/A")
    SERVER_WORLD=$(docker compose exec -T valheim bash -c 'echo "${SERVER_WORLD:-Dedicated}"' 2>/dev/null || echo "N/A")
    SERVER_PORT=$(docker compose exec -T valheim bash -c 'echo "${SERVER_PORT:-2456}"' 2>/dev/null || echo "N/A")
    SERVER_PUBLIC=$(docker compose exec -T valheim bash -c 'echo "${SERVER_PUBLIC:-1}"' 2>/dev/null || echo "N/A")
    
    echo -e "   ${BLUE}Name:${NC}     ${SERVER_NAME}"
    echo -e "   ${BLUE}World:${NC}    ${SERVER_WORLD}"
    echo -e "   ${BLUE}Port:${NC}     ${SERVER_PORT}/udp"
    echo -e "   ${BLUE}Public:${NC}   ${SERVER_PUBLIC}"
    echo ""

    # Show container status / 显示容器状态
    echo -e "${GREEN}📊 Container Status / 容器状态:${NC}"
    docker compose ps valheim
    echo ""

    # Show helpful commands / 显示有用的命令
    echo -e "${GREEN}💡 Useful Commands / 有用命令:${NC}"
    echo -e "   ${BLUE}View logs:${NC}     docker compose logs -f valheim"
    echo -e "   ${BLUE}查看日志:${NC}      docker compose logs -f valheim"
    echo -e "   ${BLUE}Stop server:${NC}   ./server.sh stop"
    echo -e "   ${BLUE}停止服务器:${NC}   ./server.sh stop"
    echo -e "   ${BLUE}Check status:${NC} ./server.sh status"
    echo -e "   ${BLUE}查看状态:${NC}     ./server.sh status"
    echo ""

    echo -e "${GREEN}✅ Server started successfully!${NC}"
    echo -e "${GREEN}   服务器已成功启动！${NC}"
}

# ============================================================================
# Function: stop_server
# 功能: 停止服务器
# Description: Stop Valheim server process and container
#              - Uses extended timeout to ensure world data is saved correctly
#              - Checks container status accurately
# 描述: 停止 Valheim 服务器进程和容器
#       - 使用延长的超时时间以确保世界数据正确保存
#       - 准确检查容器状态
# ============================================================================
stop_server() {
    echo -e "${YELLOW}🛑 Valheim-Crate: Stopping server...${NC}"
    echo -e "${YELLOW}   Valheim-Crate: 正在停止服务器...${NC}"
    echo ""

    # 1. Check if container exists / 检查容器是否存在
    local CONTAINER_ID
    CONTAINER_ID=$(docker compose ps -q valheim 2>/dev/null)
    
    if [ -z "$CONTAINER_ID" ]; then
        echo -e "${YELLOW}ℹ️  Server is not installed (Container not found).${NC}"
        echo -e "${YELLOW}   服务器未安装（未找到容器）。${NC}"
        return 0
    fi

    # 2. Check if actually running / 检查是否确实在运行
    if ! docker compose ps --filter "status=running" -q valheim >/dev/null 2>&1; then
        echo -e "${YELLOW}ℹ️  Server is already stopped.${NC}"
        echo -e "${YELLOW}   服务器已经是停止状态。${NC}"
        return 0
    fi

    # 3. Stop container with extended timeout / 带延长超时的停止容器
    # Valheim needs time to flush world data to disk. 
    # Default Docker timeout (10s) might kill it mid-save. 
    # increasing to 30s is safer.
    # Valheim 需要时间将世界数据写入磁盘。
    # Docker 默认超时 (10秒) 可能会在保存中途杀死进程。
    # 增加到 30秒 更安全。
    
    echo -e "${YELLOW}🛑 Stopping container (waiting up to 30s for world save)...${NC}"
    echo -e "${YELLOW}   正在停止容器（最多等待 30秒 以保存世界）...${NC}"
    
    # Use direct if condition to catch errors in 'set -e' mode
    # 在 'set -e' 模式下使用直接的 if 条件来捕获错误
    if docker compose stop -t 30 valheim; then
        echo -e "${GREEN}✅ Server stopped successfully (Data saved)${NC}"
        echo -e "${GREEN}   服务器已成功停止（数据已保存）${NC}"
    else
        echo -e "${RED}❌ Failed to stop server cleanly${NC}"
        echo -e "${RED}   未能正常停止服务器${NC}"
        exit 1
    fi
}

# ============================================================================
# Function: restart_server
# 功能: 重启服务器
# Description: Stop then start the server to apply configuration changes
#              - Validates config before stopping (Safety first)
#              - Checks installation status
# 描述: 先停止再启动服务器以应用配置更改
#       - 停止前验证配置（安全第一）
#       - 检查安装状态
# ============================================================================
restart_server() {
    echo -e "${BLUE}🔄 Valheim-Crate: Restarting server...${NC}"
    echo -e "${BLUE}   Valheim-Crate: 正在重启服务器...${NC}"
    echo ""

    # 1. Pre-check: Is server installed? / 预检查：服务器是否安装？
    # Don't bother stopping if it doesn't exist
    if [ -z "$(docker compose ps -a -q valheim 2>/dev/null)" ]; then
        echo -e "${RED}❌ Server not installed. Cannot restart.${NC}"
        echo -e "${RED}   服务器未安装，无法重启。${NC}"
        echo -e "${YELLOW}   Please run './server.sh install' first.${NC}"
        exit 1
    fi

    # 2. Pre-check: Validate config syntax / 预检查：验证配置语法
    # Prevent stopping a healthy server if the new config is broken
    # 防止因为新配置有语法错误而误停了健康的服务器
    echo -e "${YELLOW}🔍 Validating configuration file...${NC}"
    if ! docker compose config -q; then
        echo -e "${RED}❌ Configuration error in compose.yml${NC}"
        echo -e "${RED}      compose.yml 中存在配置错误${NC}"
        echo -e "${YELLOW}   Restart aborted to protect the running server.${NC}"
        echo -e "${YELLOW}   重启已中止以保护正在运行的服务器。${NC}"
        echo ""
        # Print the actual error
        docker compose config
        exit 1
    fi
    echo -e "${GREEN}✅ Configuration is valid${NC}"
    echo ""

    # 3. Stop server / 停止服务器
    # Calls our improved stop_server which handles world saving safely
    # 调用我们改进过的 stop_server，它会安全地处理世界保存
    stop_server
    
    echo ""

    # 4. Start server / 启动服务器
    # start_server will recreate the container if config changed (up -d)
    # start_server 会在配置发生变化时重建容器 (up -d)
    start_server
}

# ============================================================================
# Function: status_server
# 功能: 查看服务器状态
# Description: Display detailed server status (Container, Resources, Config)
# 描述: 显示详细的服务器状态（容器、资源、配置）
# ============================================================================
status_server() {
    echo -e "${GREEN}📊 Valheim-Crate: Server Status${NC}"
    echo -e "${GREEN}   Valheim-Crate: 服务器状态${NC}"
    echo ""

    local CONTAINER_ID
    CONTAINER_ID=$(docker compose ps -q valheim 2>/dev/null)
    local IS_RUNNING=false

    echo -e "${YELLOW}🐳 Container Status / 容器状态:${NC}"
    if [ -n "$CONTAINER_ID" ]; then
        if docker compose ps --filter "status=running" -q valheim >/dev/null 2>&1; then
            echo -e "   ${GREEN}✅ Running / 运行中${NC}"
            IS_RUNNING=true
        else
            echo -e "   ${YELLOW}⏸️  Stopped / 已停止${NC}"
        fi
    else
        echo -e "   ${RED}❌ Not installed / 未安装${NC}"
    fi
    echo ""

    # Only show details if running / 仅在运行时显示详情
    if [ "$IS_RUNNING" = true ]; then
        echo -e "${YELLOW}🎮 Runtime Performance / 运行性能:${NC}"
        
        if docker compose exec -T valheim pgrep -f "valheim_server.x86_64" > /dev/null 2>&1; then
            local SERVER_PID
            SERVER_PID=$(docker compose exec -T valheim pgrep -f "valheim_server.x86_64" | head -1)
            echo -e "   ${GREEN}Process: ✅ Running (PID: $SERVER_PID)${NC}"
            
            # Resource Usage / 资源占用
            local STATS
            STATS=$(docker stats --no-stream --format "CPU: {{.CPUPerc}} / RAM: {{.MemUsage}}" "$CONTAINER_ID")
            echo -e "   ${BLUE}Resources: $STATS${NC}"
            
            # Uptime / 运行时间
            local UPTIME
            UPTIME=$(docker compose ps --format "{{.RunningFor}}" valheim)
            echo -e "   ${BLUE}Uptime:    $UPTIME${NC}"
        else
            echo -e "   ${YELLOW}Process: ⏳ Starting... (Wait for it)${NC}"
        fi
        echo ""

        # Show actual loaded config / 显示实际加载的配置
        echo -e "${YELLOW}⚙️  Active Configuration / 当前配置:${NC}"
        local ENV_VARS
        ENV_VARS=$(docker compose exec -T valheim env)
        local NAME
        NAME=$(echo "$ENV_VARS" | grep "^SERVER_NAME=" | cut -d= -f2-)
        local PORT
        PORT=$(echo "$ENV_VARS" | grep "^SERVER_PORT=" | cut -d= -f2-)
        
        echo -e "   ${BLUE}Name:${NC} $NAME"
        echo -e "   ${BLUE}Port:${NC} $PORT/udp"
        echo ""
    fi

    # Storage Check / 存储检查
    echo -e "${YELLOW}💾 Storage Status / 存储状态:${NC}"
    if [ -d "/opt/server/valheim" ]; then
        local DATA_SIZE
        DATA_SIZE=$(du -sh /opt/server/valheim 2>/dev/null | awk '{print $1}' || echo "unknown")
        echo -e "   ${GREEN}✅ Data Location: /opt/server/valheim ($DATA_SIZE)${NC}"
    else
        echo -e "   ${YELLOW}⚠️  Data directory not found${NC}"
    fi
    echo ""
}

# ============================================================================
# Function: remove_server
# 功能: 删除服务器
# Description: Remove container and Docker image (Safe & Clean)
#              - Modified to ONLY remove the valheim service/image
#              - Prevents accidental deletion of other services in the same compose project
# 描述: 删除容器和 Docker 镜像（安全且彻底）
#       - 已修改为【仅】删除 valheim 服务/镜像
#       - 防止意外删除同一 Compose 项目中的其他服务
# ============================================================================
remove_server() {
    # Define variables separately to avoid ShellCheck SC2155 warning
    local HAS_CONTAINERS
    local HAS_IMAGE

    # Check existence before attempting removal / 删除前检查是否存在
    # We specifically look for the 'valheim' service container
    HAS_CONTAINERS=$(docker compose ps -a -q valheim 2>/dev/null)
    HAS_IMAGE=$(docker images -q valheim:latest 2>/dev/null)

    if [ -z "$HAS_CONTAINERS" ] && [ -z "$HAS_IMAGE" ]; then
        echo -e "${YELLOW}ℹ️  Server is not installed (no containers or images found).${NC}"
        echo -e "${YELLOW}   服务器未安装（未发现容器或镜像）。${NC}"
        return 0
    fi

    echo -e "${RED}🗑️  Valheim-Crate: Uninstalling server...${NC}"
    echo -e "${RED}   Valheim-Crate: 正在卸载服务器...${NC}"
    echo ""
    
    echo -e "${YELLOW}🗑️  Removing valheim container...${NC}"
    echo -e "${YELLOW}   正在删除 valheim 容器...${NC}"
    
    # FIXED: Use 'rm' instead of 'down' to protect other services
    # 修正：使用 'rm' 代替 'down' 以保护其他服务
    # -s: Stop the container if it is running / 如果正在运行先停止
    # -f: Force removal / 强制删除
    # -v: Remove anonymous volumes attached to the container / 删除关联的匿名卷
    docker compose rm -s -f -v valheim

    # Remove the specific image / 删除特定镜像
    if docker image inspect valheim:latest >/dev/null 2>&1; then
        echo -e "${YELLOW}🗑️  Removing valheim image...${NC}"
        echo -e "${YELLOW}   正在删除 valheim 镜像...${NC}"
        
        # Try to remove the image. If it's used by another container, docker will error out safely.
        # 尝试删除镜像。如果被其他容器占用，Docker 会安全地报错。
        if ! docker rmi valheim:latest; then
             echo -e "${YELLOW}⚠️  Could not remove image 'valheim:latest' (It might be in use by another container).${NC}"
        fi
    fi

    echo -e "${GREEN}✅ Server removed successfully${NC}"
    echo -e "${GREEN}   服务器已成功删除${NC}"
    echo ""
    
    echo -e "${YELLOW}ℹ️  Note: Game data in /opt/server/valheim is preserved (Bind Mount)${NC}"
    echo -e "${YELLOW}   注意: /opt/server/valheim 中的游戏数据已保留（绑定挂载）${NC}"
}

# ============================================================================
# Function: show_usage
# 功能: 显示用法
# Description: Display help message with available commands
# 描述: 显示帮助信息和使用说明
# ============================================================================
show_usage() {
    echo -e "${YELLOW}Usage: $0 [install|update|start|stop|restart|status|remove]${NC}"
    echo -e "${YELLOW}用法: $0 [install|update|start|stop|restart|status|remove]${NC}"
    echo ""
    echo -e "${GREEN}Commands / 命令:${NC}"
    echo -e "  ${BLUE}install${NC}  - Build image & install files (Does NOT start server) / 构建镜像并安装文件（不启动服务器）"
    echo -e "  ${BLUE}update${NC}   - Update game files only / 仅更新游戏文件"
    echo -e "  ${BLUE}start${NC}    - Start the server / 启动服务器"
    echo -e "  ${BLUE}stop${NC}     - Stop the server / 停止服务器"
    echo -e "  ${BLUE}restart${NC}  - Restart the server / 重启服务器"
    echo -e "  ${BLUE}status${NC}   - Show detailed status / 显示详细状态"
    echo -e "  ${RED}remove${NC}   - Remove all (Preserves data) / 删除所有（保留数据）"
}

# ============================================================================
# Main script execution / 主脚本执行
# ============================================================================

# Check Docker prerequisites / 检查 Docker 前置条件
check_docker

# Parse command line argument
# 解析命令行参数
COMMAND="$1"

case "$COMMAND" in
    install)
        install_server
        ;;
    update)
        update_server
        ;;
    start)
        start_server
        ;;
    stop)
        stop_server
        ;;
    restart)
        restart_server
        ;;
    status)
        status_server
        ;;
    remove)
        remove_server
        ;;
    *)
        show_usage
        exit 0
        ;;
esac

