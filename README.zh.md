# Valheim-Crate

<img src="image/Valheim-Crate.png" alt="Valheim-Crate Logo" width="250">

> 🐳 **基于 Docker 的 Valheim 专用服务器** — 零配置，在 Linux 上运行。

[**English Documentation**](README.md)

---

## 功能特性

- ✅ 一键安装
- ✅ 自动更新
- ✅ 完整配置支持（所有 Valheim 服务器选项）
- ✅ 世界修改器（预设、自定义修改器、种子）
- ✅ 数据持久化
- ✅ 双语支持（中英文）

## 系统要求

- Linux（在 Ubuntu/Debian 上测试）
- Docker 和 Docker Compose
- 2GB+ 可用磁盘空间
- 网络访问

## 快速开始

```bash
git clone <repository-url>
cd Valheim-Crate
cp compose.example.yml compose.yml
nano compose.yml  # 设置 SERVER_NAME 和 SERVER_PASSWORD
```

# 1. 安装环境并下载游戏（不会自动启动）
./server.sh install

# 2. 启动服务器
./server.sh start

## 命令

| 命令 | 说明 |
|-----|------|
| `install` | 首次安装：构建环境并下载游戏（**不自动启动**） |
| `update` | 安全更新：停止服务器 -> 更新文件 -> 准备就绪 |
| `start` | 启动服务器（需先运行 `install`） |
| `stop` | 安全停止（等待世界保存） |
| `restart` | 验证配置 -> 停止 -> 启动 |
| `status` | 显示资源占用、配置和端口状态 |
| `remove` | 卸载容器/镜像（数据保留） |

**默认：** `./server.sh`（显示帮助菜单）

## 配置

编辑 `compose.yml`（从 `compose.example.yml` 复制）。所有设置通过环境变量完成。

**注意：** `compose.yml` 已被 gitignore 忽略，以保护您的密码。

### 必填

```yaml
environment:
  SERVER_SAVE_DIR: "/valheim/saves"
  SERVER_LOGFILE: "/valheim/log.txt"
```

### 基础

```yaml
environment:
  SERVER_PORT: 2456               # 默认：2456
  SERVER_WORLD: "Dedicated"       # 默认：Dedicated
  SERVER_PUBLIC: 1                # 1=公开，0=私有
  SERVER_SAVE_DIR: "/valheim/saves"
  SERVER_LOGFILE: "/valheim/log.txt"
  SERVER_SEED: "your-seed"        #  可选。⚠️ 注意：首次运行后需要执行 './server.sh restart' 才能生效！
```

⚠️ 关于自定义种子： 服务器在首次启动时会生成一个随机世界。如果您设置了 SERVER_SEED，内置补丁工具会检测到不匹配。您必须在初始化完成后执行一次 ./server.sh restart，工具将自动应用您的种子并重新生成世界。

### 世界修改器

**选项 1：预设（推荐新手）**
```yaml
SERVER_PRESET: "hard"  # Normal, Casual, Easy, Hard, Hardcore, Immersive, Hammer
```
默认：Normal（如果不设置）

**选项 2：自定义修改器**
```yaml
SERVER_MODIFIER: "raids:none,combat:hard,resources:more"
```
| 可用 | 值 |
|-----|------|
| combat | veryeasy, easy, hard, veryhard |
| deathpenalty | casual, veryeasy, easy, hard, hardcore |
| resources | muchless, less, more, muchmore, most |
| raids | none, muchless, less, more, muchmore |
| portals | casual, hard, veryhard |

**选项 3：复选框键**
```yaml
SERVER_SETKEY: "nomap,nobuildcost"  # nobuildcost, playerevents, passivemobs, nomap
```

**组合：**
- ✅ `SERVER_MODIFIER` + `SERVER_SETKEY`（推荐）
- ⚠️ `SERVER_PRESET` + `SERVER_MODIFIER`（预设会覆盖修改器）

### 高级

```yaml
SERVER_SAVEINTERVAL: 1800    # 保存间隔（秒，默认：1800）
SERVER_BACKUPS: 4            # 备份数量（默认：4）
SERVER_BACKUPSHORT: 7200     # 短期备份间隔（默认：7200）
SERVER_BACKUPLONG: 43200     # 长期备份间隔（默认：43200）
SERVER_CROSSPLAY: 1          # 启用跨平台（0=仅 Steam，1=跨平台）
SERVER_INSTANCEID: "1"       # 多个服务器的唯一 ID
```

## 数据与端口

**数据位置：** `/opt/server/valheim`（删除容器后仍保留）

**端口转发：**
- Steam 后端（默认）：转发 UDP 2456-2457
- 跨平台（`SERVER_CROSSPLAY: 1`）：不需要

## 日志

```bash
docker compose logs -f valheim                    # 容器日志
docker compose exec valheim cat /valheim/log.txt  # 服务器日志（如果配置了）
```

## 项目结构

```
📦 Valheim-Crate/
├── 🐳 Dockerfile                  # Docker 镜像定义
├── 📝 compose.example.yml         # 示例配置文件（复制为 compose.yml）
├── 🚫 compose.yml                 # 您的本地配置（已 gitignore）
├── 🎮 server.sh                   # 主管理脚本
├── 📚 README.md                   # 英文文档
├── 📚 README.zh.md                # 中文文档
├── 🚫 .gitignore                  # Git 忽略规则
└── 📁 scripts/
    ├── ⚙️  setup.sh               # 安装/更新服务器文件
    └── 🚀 start.sh                # 启动 Valheim 服务器
```

## 🗺️ 开发路线图

### 第一阶段：工程化与发布 🛠️
* [ ] **CI/CD 集成**：使用 GitHub Actions 实现自动化测试（ShellCheck, Go Test）以及 Docker 镜像的自动构建。
* [ ] **发布 Docker 镜像**：将镜像发布至 Docker Hub 和 GHCR，支持用户直接使用 `docker pull` 拉取。
* [ ] **单元测试**：为二进制补丁工具 (`seed.go`) 添加完善的 Go 单元测试，并为 Shell 脚本添加 BATS 测试。

### 第二阶段：功能增强 ✨
* [ ] **云端备份**：支持将游戏存档自动同步上传至云存储（S3、MinIO、WebDAV）。
* [ ] **Webhook 通知**：集成 Discord、Telegram 和钉钉的 Webhook，实现服务器状态变更（启动/停止/IP变化）的实时通知。
* [ ] **日志可视化**：优化启动日志的输出格式，提供更直观的进度展示。

### 第三阶段：极客探索 🧪
* [ ] **原生 FWL 生成器**：深入研究 Valheim 文件结构，尝试使用 Go 直接生成 `.fwl` 世界文件，彻底摆脱对游戏进程的依赖（实现真正的无需重启、即刻生效）。