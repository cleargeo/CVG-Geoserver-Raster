# Remote Repository Reconciliation Report — CVG Projects
**Date:** 2026-03-21 22:30 ET  
**Sources checked:** git.cleargeo.tech (Gitea v1.25.5) · github.com/cleargeo · Local workspace

---

## Remote Sources

### Gitea — git.cleargeo.tech
- **Org:** `clearview-geographic`
- **Token:** `GITEA_TOKEN` in `G:\07_APPLICATIONS_TOOLS\CVG\CVG_VersionTracking_GitEngine\.env`
- **SSH port:** 222
- **HTTP internal:** `http://10.10.10.200:3000` (cvgadmin)

### GitHub — github.com/cleargeo
- **Status:** Token expired — re-auth required (`gh auth login -h github.com`)
- **Public repos only visible:** `cleargeo/cleargeo` (profile README), `cleargeo/cvg-neuron-public`

---

## Complete Repo Inventory

### Gitea — clearview-geographic org (7 repos)

| ID | Repo | Size | Root Contents | Notes |
|----|------|------|---------------|-------|
| 1 | `cvg-platform` | 48 MB | CVG_PLATFORM/, 05_ChangeLogs/, docs, AI scripts, network docs | Platform stack (Caddy/Gitea/Prometheus/Grafana/Portainer on VM451) |
| 2 | `cvg-hive` | 23 KB | README.md only | **Stub** — placeholder repo |
| 3 | `cvg-bind-dns` | 23 KB | README.md only | **Stub** — DNS service not yet developed |
| 4 | `cvg-storm-surge-wizard` | **10.3 GB** | **main:** README.md + SSW_PROJECT_REFERENCE.md<br>**master:** Full Python pkg + portal + ADCIRC/SLOSH models | `master` branch = active dev; `main` = docs/reference |
| 5 | `cvg-infrastructure` | 31 KB | DNS_REFERENCE.md, NETWORK_MAP.md, docs/ | Infrastructure reference docs only |
| 6 | `cvg-monitoring` | 23 KB | README.md only | **Stub** — placeholder repo |
| 8 | `cvg-nexus.com` | 49 MB | Full website/portal code | CVG Nexus web platform |

### GitHub — cleargeo (public repos only)

| Repo | Size | Notes |
|------|------|-------|
| `cleargeo/cleargeo` | Small | Profile README only |
| `cleargeo/cvg-neuron-public` | Unknown | Public Neuron reference |

---

## Local ↔ Remote Reconciliation

### ✅ Projects with Remote Backup (Gitea)

| Local Directory | Remote Repo | Branch | Status |
|---|---|---|---|
| `CVG_Storm Surge Wizard` (root) | `cvg-storm-surge-wizard` | **master** (active) | ✅ Remote has full 10.3GB project; local root copy has docs/ops/tests/tools — **large model data may only be in Gitea** |

### ⚠️ Projects with NO Remote Backup (Local Only)

| Local Directory | Location | File Count | Risk |
|---|---|---|---|
| `CVG_Rainfall Wizard` | `CVG\CVG_Rainfall Wizard\` | ~125 files | 🔴 **No Gitea repo — local only** |
| `CVG_SLR Wizard` | `CVG\CVG_SLR Wizard\` | ~125 files | 🔴 **No Gitea repo — local only** |
| `CVG_VersionTracking_GitEngine` | `CVG\CVG_VersionTracking_GitEngine\` | ~45 files | 🔴 **No Gitea repo — local only** |
| `CVG_GeoServ_Processor` | `CVG\CVG_GeoServ_Processor\` | 103 files | 🔴 **No Gitea repo — local only** |
| `CVG_Geoserver_Raster` | Root (live service) | Full | 🔴 **No Gitea repo — local only** |
| `CVG_Geoserver_Vector` | Root (live service) | Full | 🔴 **No Gitea repo — local only** |
| `CVG_Containerization_SupportEngine` | Root (live service) | Full | ⚠️ Root is current; CVG\ has older snapshot; no Gitea remote set |

### 🔵 Gitea Repos with No Local Workspace Match

| Gitea Repo | Size | Local Match? | Notes |
|---|---|---|---|
| `cvg-platform` | 48 MB | Possibly `CVG_Containerization_SupportEngine` or somewhere in `CVG_Projects` | Platform stack docs/configs |
| `cvg-nexus.com` | 49 MB | Not found in workspace | Web portal — may be deployed, not kept locally |
| `cvg-infrastructure` | 31 KB | `_configs/` or `CVG_DNS_SupportEngine` | Reference docs only |

### 🟡 Both Local and Remote are Sparse/Stub

| Project | Local State | Remote State | Conclusion |
|---|---|---|---|
| `CVG_DNS_SupportEngine` | Only `app\` (empty) | `cvg-bind-dns` = README.md only | Project in early planning stage — no actual code yet |
| `CVG_Neuron` | Empty in all locations | `cvg-neuron-public` on GitHub (public stub) | Planned project — not yet developed locally |
| `CVG_Audit_VM` | Empty `app\` scaffold | No Gitea repo | Scaffold only |

---

## ⚠️ ACTION ITEMS — Highest Priority

### 1. `cvg-storm-surge-wizard` — Verify Large Model Data (10.3 GB)
The Gitea `master` branch (10.3GB) likely contains ADCIRC/SLOSH NetCDF model files not present in the local workspace. **Clone or pull `master` to verify local has all model data:**
```bash
git clone --branch master ssh://git@git.cleargeo.tech:222/clearview-geographic/cvg-storm-surge-wizard.git
```

### 2. CVG_Rainfall Wizard, CVG_SLR Wizard — Create Gitea Repos (No Backup)
These fully-developed Python packages (~125 files each) are **local only** with zero remote backup:
```bash
# Create repos via Gitea API then push
curl -X POST -H "Authorization: token 7ffbb3fc2ea62e6c556b4c10e699d769f0d41e7a" \
  "https://git.cleargeo.tech/api/v1/orgs/clearview-geographic/repos" \
  -H "Content-Type: application/json" \
  -d '{"name":"cvg-rainfall-wizard","private":true,"auto_init":false}'
```

### 3. CVG_Geoserver_Raster + CVG_Geoserver_Vector — Initialize Gitea Repos
Fully-developed deployment configurations (Dockerfile, docker-compose, Caddyfile, scripts) with **zero remote backup**.

### 4. CVG_VersionTracking_GitEngine — Initialize Gitea Repo
Ironic: the tool that tracks git repos is not itself in a git repo.

### 5. Re-authenticate GitHub
```
gh auth login -h github.com
```
Then check private repos for `azelenski_cvg` and `cleargeo` accounts — may have private copies of Rainfall/SLR/GeoServer repos.

---

## GeoServer Directory Contents (Confirmed Populated)

### CVG_Geoserver_Raster (root)
`.dockerignore`, `.env.example`, `.gitignore`, `CHANGELOG.md`, `deploy_production.sh`, `docker-compose.prod.yml`, `docker-compose.yml`, `Dockerfile`, `Makefile`, `README.md`, `ROADMAP.md`, `_check_status.bat`, `_check_status.sh`, `_run_deploy.bat`, `caddy/Caddyfile`, `scripts/`, `05_ChangeLogs/`, `vm451_Caddyfile_live.txt`

### CVG_Geoserver_Vector (root)
`Dockerfile`, `deploy_production.sh`, `docker-compose.yml`, `docker-compose.prod.yml`, `_run_deploy.bat`, `.dockerignore`, `.env.example`, `caddy/Caddyfile`, `scripts/controlflow.properties`, `scripts/geoserver-init.sh`
