# Base image with SteamCMD pre-installed / 基础镜像，已预装 SteamCMD
FROM steamcmd/steamcmd:latest

# Set working directory / 设置工作目录
WORKDIR /valheim

# Create app directory for scripts (不会被挂载覆盖) / 创建 app 目录存放脚本（不会被挂载覆盖）
RUN mkdir -p /app/scripts
COPY scripts/ /app/scripts/
RUN chmod +x /app/scripts/*.sh

# Expose Valheim server ports (UDP) / 暴露 Valheim 服务器端口（UDP）
EXPOSE 2456-2457/udp

# Keep container running / 保持容器运行
# External scripts will control the container via docker exec / 外部脚本将通过 docker exec 控制容器
CMD ["/bin/bash"]