# Valheim-Crate

🐳 **Valheim dedicated server in Docker** — Zero setup, runs on Linux.

[中文文档 / Chinese Documentation](README.zh.md)

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
cp docker-compose.example.yml docker-compose.yml
nano docker-compose.yml  # Set SERVER_NAME and SERVER_PASSWORD
./server.sh install
```

## Commands

| Command | Description |
|---------|-------------|
| `install` | First-time installation (build, create, install, start) |
| `update` | Update server files (no rebuild) |
| `start` | Start server (auto-install if needed) |
| `stop` | Stop server |
| `restart` | Restart server |
| `status` | Show server status |
| `remove` | Remove container/image (data preserved) |

**Default:** `./server.sh` (same as `start`)

## Configuration

Edit `docker-compose.yml` (copied from `docker-compose.example.yml`). All settings via environment variables.

**Note:** `docker-compose.yml` is gitignored to protect your passwords.

### Required

```yaml
environment:
  SERVER_NAME: "Your Server Name"
  SERVER_PASSWORD: "YourPassword"
```

### Basic

```yaml
environment:
  SERVER_PORT: 2456              # Default: 2456
  SERVER_WORLD: "Dedicated"       # Default: Dedicated
  SERVER_PUBLIC: 1                # 1=public, 0=private
  SERVER_SAVE_DIR: "/valheim/saves"
  SERVER_LOGFILE: "/valheim/log.txt"
  SERVER_SEED: "your-seed"        # Optional, random if not set
```

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
Available: `Combat`, `DeathPenalty`, `Resources`, `Raids`, `Portals`  
Values: `veryeasy`, `easy`, `hard`, `veryhard`, `casual`, `hardcore`, `muchless`, `less`, `more`, `muchmore`, `most`, `none`

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
docker-compose logs -f valheim                    # Container logs
docker-compose exec valheim cat /valheim/log.txt  # Server logs (if configured)
```

## Troubleshooting

**Server won't start:**
- Check: `./server.sh status`
- View logs: `docker-compose logs valheim`
- Verify: `SERVER_NAME` and `SERVER_PASSWORD` are set

**Server files not found:**
```bash
./server.sh install
```

**Port conflict:**
Change ports in `docker-compose.yml` and update `SERVER_PORT`.

**Update failed:**
```bash
./server.sh start && ./server.sh update
```

## FAQ

**Q: Change settings?**  
A: Edit `docker-compose.yml`, then `./server.sh restart`

**Q: World lost after remove?**  
A: No, data in `/opt/server/valheim` persists

**Q: Update server?**  
A: `./server.sh update`

**Q: Custom seed?**  
A: Set `SERVER_SEED: "your-seed"`

**Q: Enable crossplay?**  
A: Set `SERVER_CROSSPLAY: 1`

## License

This project is provided as-is for running Valheim dedicated servers.
