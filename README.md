# Valheim-Crate

![Valheim-Crate Logo](image/Valheim-Crate.png)

> 🐳 **Valheim dedicated server in Docker** — Zero setup, runs on Linux.

[**中文文档 / Chinese Documentation**](README.zh.md)

---

## Features

- ✅ One-command installation
- ✅ Automatic updates
- ✅ Full configuration support (all Valheim server options)
- ✅ World modifiers (presets, custom modifiers, seed)
- ✅ Data persistence
- ✅ Bilingual support (English/Chinese)

## Requirements

- Linux (tested on Ubuntu/Debian)
- Docker & Docker Compose
- 2GB+ free disk space
- Network access

## Quick Start

```bash
git clone <repository-url>
cd Valheim-Crate
cp compose.example.yml compose.yml
nano compose.yml  # Set SERVER_NAME and SERVER_PASSWORD
```

# 1. Install environment & download game
./server.sh install

# 2. Start the server
./server.sh start

## Commands

| Command | Description |
|---------|-------------|
| `install` | Build environment & download game files (**No auto-start**) |
| `update` | Safe update: Stop -> Update files -> Ready to start |
| `start` | Start server (Requires `install` first) |
| `stop` | Safely stop server (Waits for world save) |
| `restart` | Validate config -> Stop -> Start |
| `status` | Show resource usage, config, and port status |
| `remove` | Remove container/image (Data preserved) |

**Default:** `./server.sh` (Shows help menu)

## Configuration

Edit `compose.yml` (copied from `compose.example.yml`). All settings via environment variables.

**Note:** `compose.yml` is gitignored to protect your passwords.

### Required

```yaml
environment:
  SERVER_SAVE_DIR: "/valheim/saves"
  SERVER_LOGFILE: "/valheim/log.txt"
```

### Basic

```yaml
environment:
  SERVER_PORT: 2456               # Default: 2456
  SERVER_WORLD: "Dedicated"       # Default: Dedicated
  SERVER_PUBLIC: 1                # 1=public, 0=private
  SERVER_SAVE_DIR: "/valheim/saves"
  SERVER_LOGFILE: "/valheim/log.txt"
  SERVER_SEED: "your-seed"        # Optional. ⚠️ NOTE: Requires './server.sh restart' after first run to apply!
```

⚠️ About Custom Seeds: The server will generate a random world on the very first startup. If you set a SERVER_SEED, the built-in patcher will detect the mismatch. You MUST run ./server.sh restart once after the initial setup to let the patcher apply your seed and regenerate the world.

### World Modifiers

**Option 1: Preset (Recommended for beginners)**
```yaml
SERVER_PRESET: "hard"  # Normal, Casual, Easy, Hard, Hardcore, Immersive, Hammer
```
Default: Normal (if nothing set)

**Option 2: Custom Modifiers**
```yaml
SERVER_MODIFIER: "raids:none,combat:hard,resources:more"
```
| Available | Value |
|-----|------|
| combat | veryeasy, easy, hard, veryhard |
| deathpenalty | casual, veryeasy, easy, hard, hardcore |
| resources | muchless, less, more, muchmore, most |
| raids | none, muchless, less, more, muchmore |
| portals | casual, hard, veryhard |

**Option 3: Checkbox Keys**
```yaml
SERVER_SETKEY: "nomap,nobuildcost"  # nobuildcost, playerevents, passivemobs, nomap
```

**Combinations:**
- ✅ `SERVER_MODIFIER` + `SERVER_SETKEY` (recommended)
- ⚠️ `SERVER_PRESET` + `SERVER_MODIFIER` (preset overwrites modifiers)

### Advanced

```yaml
SERVER_SAVEINTERVAL: 1800    # Save interval (seconds, default: 1800)
SERVER_BACKUPS: 4            # Backup count (default: 4)
SERVER_BACKUPSHORT: 7200     # Short backup interval (default: 7200)
SERVER_BACKUPLONG: 43200     # Long backup interval (default: 43200)
SERVER_CROSSPLAY: 1          # Enable crossplay (0=Steam only, 1=Crossplay)
SERVER_INSTANCEID: "1"       # Unique ID for multiple servers
```

## Data & Ports

**Data Location:** `/opt/server/valheim` (persists after container removal)

**Port Forwarding:**
- Steam backend (default): Forward UDP 2456-2457
- Crossplay (`SERVER_CROSSPLAY: 1`): Not required

## Logs

```bash
docker compose logs -f valheim                    # Container logs
docker compose exec valheim cat /valheim/log.txt  # Server logs (if configured)
```

## Project Structure

```
📦 Valheim-Crate/
├── 🐳 Dockerfile                  # Docker image definition
├── 📝 compose.example.yml         # Example configuration (copy to compose.yml)
├── 🚫 compose.yml                 # Your local config (gitignored)
├── 🎮 server.sh                   # Main management script
├── 📚 README.md                   # English documentation
├── 📚 README.zh.md                # Chinese documentation
├── 🚫 .gitignore                  # Git ignore rules
└── 📁 scripts/
    ├── ⚙️  setup.sh               # Install/update server files
    └── 🚀 start.sh                # Start Valheim server
```

## 🗺️ Roadmap

### Phase 1: Engineering & Release 🛠️
* [ ] **CI/CD Integration**: Implement GitHub Actions for automated testing (ShellCheck, Go Test) and Docker image building.
* [ ] **Docker Registry**: Publish images to Docker Hub and GHCR (GitHub Container Registry) to support `docker pull` directly.
* [ ] **Unit Tests**: Add comprehensive Go tests for the binary patcher (`seed.go`) and BATS tests for shell scripts.

### Phase 2: Feature Enhancements ✨
* [ ] **Cloud Backup**: Add support for auto-syncing save files to cloud storage (S3, MinIO, WebDAV).
* [ ] **Webhook Notifications**: Integrate webhooks for Discord, Telegram, and DingTalk to notify server status changes (Start/Stop/IP).
* [ ] **Visual Logs**: Improve the startup log output with better visualization and progress indicators.

### Phase 3: Experimental 🧪
* [ ] **Native FWL Generator**: Research Valheim's file structure to generate `.fwl` world files directly in Go, removing the dependency on the game process for world generation (True instant setup without restart).