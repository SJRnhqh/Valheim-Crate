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
#   install   - First time installation (build image, create container, install server, start server)
#               首次安装（构建镜像、创建容器、安装服务器、启动服务器）
#   update    - Update server files only (no image rebuild, requires install first)
#               仅更新服务器文件（不重建镜像，需要先安装）
#   start     - Start the server (container level, auto-install if container doesn't exist)
#               启动服务器（容器层面，如果容器不存在会自动安装）
#   stop      - Stop the server (container level, container remains)
#               停止服务器（容器层面，容器保留）
#   restart   - Restart the server (container level, stop then start)
#               重启服务器（容器层面，先停止再启动）
#   status    - Show server status (container, process, files, ports)
#               显示服务器状态（容器、进程、文件、端口）
#   remove    - Remove container and image (game data preserved)
#               删除容器和镜像（游戏数据保留）
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
# Description: First time installation - build Docker image, create container,
#              install Valheim server files, and start the server
# 描述: 首次安装 - 构建 Docker 镜像、创建容器、安装 Valheim 服务器文件并启动服务器
# ============================================================================
install_server() {
    echo -e "${GREEN}📦 Valheim-Crate: Installing server...${NC}"
    echo -e "${GREEN}   Valheim-Crate: 正在安装服务器...${NC}"
    echo ""

    # Step 1: Build and start container / 步骤 1: 构建并启动容器
    echo -e "${YELLOW}📦 Step 1/3: Building Docker image and starting container...${NC}"
    echo -e "${YELLOW}   步骤 1/3: 构建 Docker 镜像并启动容器...${NC}"
    docker compose up -d --build --force-recreate valheim

    # Wait for container to fully start / 等待容器完全启动
    echo -e "${YELLOW}⏳ Waiting for container to start...${NC}"
    echo -e "${YELLOW}   等待容器启动...${NC}"
    sleep 3

    # Check if container is running / 检查容器是否运行
    if ! docker compose ps | grep -q "Up"; then
        echo -e "${RED}❌ Container failed to start${NC}"
        echo -e "${RED}   容器启动失败${NC}"
        docker compose logs
        exit 1
    fi

    echo -e "${GREEN}✅ Container started successfully${NC}"
    echo -e "${GREEN}   容器已启动${NC}"
    echo ""

    # Step 2: Install server / 步骤 2: 安装服务器
    echo -e "${YELLOW}📥 Step 2/3: Installing Valheim server...${NC}"
    echo -e "${YELLOW}   步骤 2/3: 正在安装 Valheim 服务器...${NC}"
    echo -e "${YELLOW}   This may take several minutes, please wait...${NC}"
    echo -e "${YELLOW}   这可能需要几分钟时间，请耐心等待...${NC}"
    
    if ! docker compose exec -T valheim /app/scripts/setup.sh; then
        echo -e "${RED}❌ Server installation failed${NC}"
        echo -e "${RED}   服务器安装失败${NC}"
        echo -e "${YELLOW}   View logs: docker compose logs valheim${NC}"
        echo -e "${YELLOW}   查看日志: docker compose logs valheim${NC}"
        exit 1
    fi

    echo -e "${GREEN}✅ Server installation completed!${NC}"
    echo -e "${GREEN}   服务器安装完成！${NC}"
    echo ""

    # Step 3: Start server after installation / 步骤 3: 安装完成后启动服务器
    echo -e "${YELLOW}🎮 Starting Valheim server...${NC}"
    echo -e "${YELLOW}   正在启动 Valheim 服务器...${NC}"
    docker compose exec -d valheim /app/scripts/start.sh
    sleep 2
    
    if docker compose exec -T valheim pgrep -f "valheim_server.x86_64" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Valheim server started successfully${NC}"
        echo -e "${GREEN}   Valheim 服务器已成功启动${NC}"
    else
        echo -e "${YELLOW}⚠️  Server process check failed, but it may still be starting${NC}"
        echo -e "${YELLOW}   服务器进程检查失败，但可能仍在启动中${NC}"
    fi
    echo ""
}

# ============================================================================
# Function: update_server
# 功能: 更新服务器
# Description: Update Valheim server files to latest version
#              Only updates game files, does not rebuild image or recreate container
#              Requires server to be installed first (will error if not)
# 描述: 更新 Valheim 服务器文件到最新版本
#       只更新游戏文件，不重新构建镜像或重新创建容器
#       需要先安装服务器（如果未安装会报错）
# ============================================================================
update_server() {
    echo -e "${GREEN}🔄 Valheim-Crate: Updating server...${NC}"
    echo -e "${GREEN}   Valheim-Crate: 正在更新服务器...${NC}"
    echo ""

    # Check if server was previously installed / 检查服务器是否已安装
    # Check if container exists or server files exist / 检查容器是否存在或服务器文件是否存在
    if ! docker compose ps | grep -q "valheim-server" && [ ! -f "/opt/server/valheim/valheim_server.x86_64" ]; then
        echo -e "${RED}❌ Server not installed. Please run './server.sh install' first${NC}"
        echo -e "${RED}   服务器未安装。请先运行 './server.sh install'${NC}"
        exit 1
    fi

    # Start container if not running / 如果容器未运行则启动
    if ! docker compose ps valheim | grep -q "Up"; then
        echo -e "${YELLOW}📦 Starting container...${NC}"
        echo -e "${YELLOW}   正在启动容器...${NC}"
        docker compose up -d valheim
        sleep 3
    fi

    # Update server files / 更新服务器文件
    echo -e "${YELLOW}📥 Updating Valheim server files...${NC}"
    echo -e "${YELLOW}   正在更新 Valheim 服务器文件...${NC}"
    echo -e "${YELLOW}   This may take several minutes, please wait...${NC}"
    echo -e "${YELLOW}   这可能需要几分钟时间，请耐心等待...${NC}"
    
    if ! docker compose exec -T valheim /app/scripts/setup.sh; then
        echo -e "${RED}❌ Server update failed${NC}"
        echo -e "${RED}   服务器更新失败${NC}"
        echo -e "${YELLOW}   View logs: docker compose logs valheim${NC}"
        echo -e "${YELLOW}   查看日志: docker compose logs valheim${NC}"
        exit 1
    fi

    echo -e "${GREEN}✅ Server update completed!${NC}"
    echo -e "${GREEN}   服务器更新完成！${NC}"
}

# ============================================================================
# Function: start_server
# 功能: 启动服务器
# Description: Start Valheim server process
#              - Auto-installs if container doesn't exist
#              - Starts container if stopped
#              - Does NOT update server files (use 'update' for that)
# 描述: 启动 Valheim 服务器进程
#        - 如果容器不存在会自动安装
#        - 如果容器已停止会自动启动
#        - 不会更新服务器文件（使用 'update' 命令更新）
# ============================================================================
start_server() {
    echo -e "${GREEN}🚀 Valheim-Crate: Starting server...${NC}"
    echo -e "${GREEN}   Valheim-Crate: 正在启动服务器...${NC}"
    echo ""

    # Check if container exists / 检查容器是否存在
    if ! docker compose ps | grep -q "valheim-server"; then
        echo -e "${YELLOW}⚠️  Container not found, installing server first...${NC}"
        echo -e "${YELLOW}   未找到容器，先安装服务器...${NC}"
        install_server
        echo ""
    fi

    # Start container if not running / 如果容器未运行则启动
    if ! docker compose ps valheim | grep -q "Up"; then
        echo -e "${YELLOW}📦 Starting container...${NC}"
        echo -e "${YELLOW}   正在启动容器...${NC}"
        docker compose up -d valheim
        sleep 3
    fi

    # Check if server files exist / 检查服务器文件是否存在
    if ! docker compose exec -T valheim test -f /valheim/valheim_server.x86_64 2>/dev/null; then
        echo -e "${RED}❌ Server files not found. Please run './server.sh install' first${NC}"
        echo -e "${RED}   未找到服务器文件。请先运行 './server.sh install'${NC}"
        exit 1
    fi

    # Start server / 启动服务器
    echo -e "${YELLOW}🎮 Starting Valheim server...${NC}"
    echo -e "${YELLOW}   正在启动 Valheim 服务器...${NC}"
    
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
#              Container is preserved (not deleted) for faster restart
# 描述: 停止 Valheim 服务器进程和容器
#       容器会保留（不删除）以便快速重启
# ============================================================================
stop_server() {
    echo -e "${YELLOW}🛑 Valheim-Crate: Stopping server...${NC}"
    echo -e "${YELLOW}   Valheim-Crate: 正在停止服务器...${NC}"
    echo ""

    # Check if container is running / 检查容器是否运行
    if ! docker compose ps | grep -q "Up"; then
        echo -e "${YELLOW}ℹ️  Container is not running${NC}"
        echo -e "${YELLOW}   容器未运行${NC}"
        return 0
    fi

    # Stop container (this will stop all processes inside, including Valheim server) / 停止容器（这会停止容器内的所有进程，包括 Valheim 服务器）
    # Use service name to ensure only valheim service is stopped / 使用服务名确保只停止 valheim 服务
    echo -e "${YELLOW}🛑 Stopping container...${NC}"
    echo -e "${YELLOW}   正在停止容器...${NC}"
    docker compose stop valheim

    echo -e "${GREEN}✅ Server stopped successfully${NC}"
    echo -e "${GREEN}   服务器已成功停止${NC}"
}

# ============================================================================
# Function: restart_server
# 功能: 重启服务器
# Description: Stop then start the server (no update performed)
# 描述: 先停止再启动服务器（不执行更新）
# ============================================================================
restart_server() {
    echo -e "${BLUE}🔄 Valheim-Crate: Restarting server...${NC}"
    echo -e "${BLUE}   Valheim-Crate: 正在重启服务器...${NC}"
    echo ""

    # Stop server / 停止服务器
    stop_server
    echo ""

    # Wait a bit / 等待一下
    sleep 2

    # Start server / 启动服务器
    start_server
}

# ============================================================================
# Function: status_server
# 功能: 查看服务器状态
# Description: Display server status including container, process, and files
# 描述: 显示服务器状态，包括容器、进程和文件信息
# ============================================================================
status_server() {
    echo -e "${GREEN}📊 Valheim-Crate: Server Status${NC}"
    echo -e "${GREEN}   Valheim-Crate: 服务器状态${NC}"
    echo ""

    # Container status / 容器状态
    echo -e "${YELLOW}🐳 Container Status / 容器状态:${NC}"
    if docker compose ps | grep -q "valheim-server"; then
        if docker compose ps | grep -q "Up"; then
            echo -e "   ${GREEN}✅ Running / 运行中${NC}"
            docker compose ps
        else
            echo -e "   ${YELLOW}⏸️  Stopped / 已停止${NC}"
            docker compose ps
        fi
    else
        echo -e "   ${RED}❌ Not found / 未找到${NC}"
    fi
    echo ""

    # Server process status / 服务器进程状态
    if docker compose ps | grep -q "Up"; then
        echo -e "${YELLOW}🎮 Server Process Status / 服务器进程状态:${NC}"
        if docker compose exec -T valheim pgrep -f "valheim_server.x86_64" > /dev/null 2>&1; then
            SERVER_PID=$(docker compose exec -T valheim pgrep -f "valheim_server.x86_64" | head -1)
            echo -e "   ${GREEN}✅ Running (PID: $SERVER_PID) / 运行中 (PID: $SERVER_PID)${NC}"
        else
            echo -e "   ${YELLOW}⏸️  Not running / 未运行${NC}"
        fi
        echo ""

        # Server files status / 服务器文件状态
        echo -e "${YELLOW}📁 Server Files Status / 服务器文件状态:${NC}"
        if docker compose exec -T valheim test -f /valheim/valheim_server.x86_64 2>/dev/null; then
            echo -e "   ${GREEN}✅ Server files found / 服务器文件已找到${NC}"
            FILE_SIZE=$(docker compose exec -T valheim ls -lh /valheim/valheim_server.x86_64 2>/dev/null | awk '{print $5}' || echo "unknown")
            echo -e "   ${GREEN}   File size: $FILE_SIZE / 文件大小: $FILE_SIZE${NC}"
        else
            echo -e "   ${RED}❌ Server files not found / 服务器文件未找到${NC}"
        fi
        echo ""
    fi

    # Port status / 端口状态
    echo -e "${YELLOW}🔌 Port Status / 端口状态:${NC}"
    if docker compose ps | grep -q "Up"; then
        PORTS=$(docker compose ps valheim 2>/dev/null | tail -1 | awk '{for(i=NF;i>=1;i--) if($i ~ /udp/) print $i}' | head -1 || echo "N/A")
        if [ "$PORTS" != "N/A" ] && [ -n "$PORTS" ]; then
            echo -e "   ${GREEN}Ports: $PORTS / 端口: $PORTS${NC}"
        else
            echo -e "   ${GREEN}Ports: 2456-2457/udp (configured) / 端口: 2456-2457/udp (已配置)${NC}"
        fi
    else
        echo -e "   ${YELLOW}Ports: 2456-2457/udp (configured) / 端口: 2456-2457/udp (已配置)${NC}"
    fi
    echo ""

    # Data directory status / 数据目录状态
    echo -e "${YELLOW}💾 Data Directory Status / 数据目录状态:${NC}"
    if [ -d "/opt/server/valheim" ]; then
        DATA_SIZE=$(du -sh /opt/server/valheim 2>/dev/null | awk '{print $1}' || echo "unknown")
        echo -e "   ${GREEN}✅ Data directory exists / 数据目录存在${NC}"
        echo -e "   ${GREEN}   Location: /opt/server/valheim / 位置: /opt/server/valheim${NC}"
        echo -e "   ${GREEN}   Size: $DATA_SIZE / 大小: $DATA_SIZE${NC}"
    else
        echo -e "   ${YELLOW}⚠️  Data directory not found / 数据目录未找到${NC}"
    fi
    echo ""
}

# ============================================================================
# Function: remove_server
# 功能: 删除服务器
# Description: Remove container, volumes, and Docker image
#              Game data in /opt/server/valheim is preserved
# 描述: 删除容器、数据卷和 Docker 镜像
#       保留 /opt/server/valheim 中的游戏数据
# ============================================================================
remove_server() {
    echo -e "${RED}🗑️  Valheim-Crate: Uninstalling server...${NC}"
    echo -e "${RED}   Valheim-Crate: 正在卸载服务器...${NC}"
    echo ""

    # Stop server if running / 如果服务器正在运行则停止
    if docker compose ps | grep -q "Up"; then
        echo -e "${YELLOW}🛑 Stopping server first...${NC}"
        echo -e "${YELLOW}   先停止服务器...${NC}"
        stop_server
        echo ""
    fi

    # Remove container and volumes / 删除容器和数据卷
    echo -e "${YELLOW}🗑️  Removing container and volumes...${NC}"
    echo -e "${YELLOW}   正在删除容器和数据卷...${NC}"
    docker compose rm -sfv valheim 2>/dev/null || docker compose down -v 2>/dev/null || true

    # Remove image / 删除镜像
    echo -e "${YELLOW}🗑️  Removing Docker image...${NC}"
    echo -e "${YELLOW}   正在删除 Docker 镜像...${NC}"
    
    # Get project name from docker compose / 从 docker compose 获取项目名
    PROJECT_NAME=$(basename "$SCRIPT_DIR" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')
    IMAGE_NAME="${PROJECT_NAME}_valheim"
    
    # Try to find and remove image / 尝试查找并删除镜像
    IMAGE_ID=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -E "(valheim-crate_valheim|${IMAGE_NAME})" | head -1 || true)
    if [ -n "$IMAGE_ID" ]; then
        docker rmi -f "$IMAGE_ID" 2>/dev/null || true
    fi
    
    # Also try to remove by pattern / 也尝试按模式删除
    docker images | grep -E "(valheim-crate|${PROJECT_NAME})" | grep "valheim" | awk '{print $3}' | xargs -r docker rmi -f 2>/dev/null || true

    echo -e "${GREEN}✅ Server removed successfully${NC}"
    echo -e "${GREEN}   服务器已成功删除${NC}"
    echo ""
    echo -e "${YELLOW}ℹ️  Note: Game data in /opt/server/valheim is preserved${NC}"
    echo -e "${YELLOW}   注意: /opt/server/valheim 中的游戏数据已保留${NC}"
    echo -e "${YELLOW}   To completely remove, manually delete: /opt/server/valheim${NC}"
    echo -e "${YELLOW}   要完全删除，请手动删除: /opt/server/valheim${NC}"
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
    echo -e "${GREEN}Commands:${NC}"
    echo -e "${GREEN}命令:${NC}"
    echo -e "  ${BLUE}install${NC}  - Install server (build image, create container, install files, start server) / 安装服务器（构建镜像、创建容器、安装文件、启动服务器）"
    echo -e "  ${BLUE}update${NC}   - Update server files only (no image rebuild, requires install first) / 仅更新服务器文件（不重建镜像，需要先安装）"
    echo -e "  ${BLUE}start${NC}    - Start the server (container level) / 启动服务器（容器层面）"
    echo -e "  ${BLUE}stop${NC}     - Stop the server (container level) / 停止服务器（容器层面）"
    echo -e "  ${BLUE}restart${NC}  - Restart the server (container level) / 重启服务器（容器层面）"
    echo -e "  ${BLUE}status${NC}   - Show server status / 显示服务器状态"
    echo -e "  ${RED}remove${NC}   - Remove container and image (game data preserved) / 删除容器和镜像（游戏数据保留）"
    echo ""
    echo -e "${YELLOW}If no command is provided, 'start' will be used by default.${NC}"
    echo -e "${YELLOW}如果未提供命令，默认使用 'start'。${NC}"
}

# ============================================================================
# Main script execution / 主脚本执行
# ============================================================================

# Check Docker prerequisites / 检查 Docker 前置条件
check_docker

# Parse command line argument (default to 'start' if not provided)
# 解析命令行参数（如果未提供则默认为 'start'）
COMMAND="${1:-start}"

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
    uninstall)
        # Alias for remove (backward compatibility) / remove 的别名（向后兼容）
        remove_server
        ;;
    *)
        show_usage
        exit 1
        ;;
esac

