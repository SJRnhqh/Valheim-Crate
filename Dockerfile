# ==========================================
# Stage 1: Build the Go Tool
# 阶段 1: 构建 Go 补丁工具
# ==========================================
FROM golang:1.21-alpine AS builder

WORKDIR /build

# Copy the Go source file
# 复制 Go 源代码 (注意这里用的是 seed.go)
COPY scripts/seed.go .

# Build the binary
# 编译为静态二进制文件 (输出名为 valheim_seed)
RUN go build -o valheim_seed seed.go

# ==========================================
# Stage 2: Final Runtime Image
# 阶段 2: 最终运行镜像
# ==========================================
FROM steamcmd/steamcmd:latest

# Set working directory / 设置工作目录
WORKDIR /valheim

# Install required dependencies for Valheim server / 安装 Valheim 服务器所需的依赖
RUN apt-get update && \
    apt-get install -y libpulse-dev libatomic1 libc6 && \
    rm -rf /var/lib/apt/lists/*

# Setup scripts directory / 设置脚本目录
RUN mkdir -p /app/scripts

# Copy setup/start scripts / 复制 shell 脚本
COPY scripts/setup.sh scripts/start.sh /app/scripts/

# Copy the compiled Go binary from Stage 1 / 从第一阶段复制编译好的 Go 程序
COPY --from=builder /build/valheim_seed /app/scripts/valheim_seed

# Ensure executable permissions / 确保可执行权限
RUN chmod +x /app/scripts/*.sh /app/scripts/valheim_seed

# Expose Valheim server ports (UDP) / 暴露 Valheim 服务器端口（UDP）
EXPOSE 2456-2457/udp

# Keep container running / 保持容器运行
CMD ["/bin/bash"]
