# SSW Deployment Status — CVG Proxmox Infrastructure

> **Primary location:** `G:\07_APPLICATIONS_TOOLS\CVG_Storm Surge Wizard\SSW_DEPLOYMENT_STATUS.md`
> *(Stored here in CVG_Geoserver_Raster workspace as fallback due to SSW directory access restrictions)*

---

## Infrastructure Overview

| Component | VM | IP | Domain | Status |
|---|---|---|---|---|
| CVG Platform / TLS Terminator | VM451 | 10.10.10.200 | — | ✅ Healthy |
| GeoServer Raster | VM454 | 10.10.10.203 | raster.cleargeo.tech | ✅ Healthy |
| GeoServer Vector | VM455 | 10.10.10.204 | vector.cleargeo.tech | ✅ Healthy |

**Proxmox Host:** CVG-QUEEN-11 (10.10.10.56) — PVE 8.3.0  
**External IP:** 131.148.52.231 → FortiGate → VM451:443  
**SSH Key:** `C:\Users\AlexZelenski\.ssh\cvg_neuron_proxmox` | User: `ubuntu`

---

## Routing Architecture

```
Internet (HTTPS 443)
  → 131.148.52.231 (FortiGate NAT)
    → VM451:443 (cvg-caddy, TLS termination, Let's Encrypt)
      → HTTP → VM454:80 (caddy-gsr)  → geoserver-raster:8080  [raster.cleargeo.tech]
      → HTTP → VM455:80 (caddy-gsv)  → geoserver-vector:8080  [vector.cleargeo.tech]
```

**Docker containers per VM:**
- VM451: `cvg-caddy` (host file: `/opt/cvg-platform/Caddyfile`)
- VM454: `geoserver-raster`, `caddy-gsr`, `watchtower-gsr` (Caddyfile: `/opt/cvg/CVG_Geoserver_Raster/caddy/Caddyfile`)
- VM455: `geoserver-vector`, `caddy-gsv`, `watchtower-gsv` (Caddyfile: `/opt/cvg/CVG_Geoserver_Vector/caddy/Caddyfile`)

---

## Session History

### Session 10/11 — 2026-03-21 — HTTPS Routing Fully Operational ✅

**Goal:** Complete HTTPS routing for `raster.cleargeo.tech` and `vector.cleargeo.tech`.

**Three-layer fix applied:**

#### Fix 1 — VM454 & VM455: `handle /status` ordering bug
- **Problem:** `handle /status { respond "OK" 200 }` was placed AFTER the bare `reverse_proxy` catch-all in both HTTP and HTTPS blocks → `/status` requests fell through to GeoServer → Jetty 404
- **Fix:** Moved `handle /status` block BEFORE `reverse_proxy` catch-all in both VMs' Caddyfiles (both HTTP and HTTPS blocks)
- **Critical rule:** A bare `reverse_proxy` in Caddy is a catch-all — all `handle` blocks must precede it

#### Fix 2 — VM451: Proxy target correction
- **Problem:** VM451's `cvg-caddy` was proxying directly to `cvg-geoserver-raster:8080` (bypassing `caddy-gsr` entirely), so requests hit GeoServer's Jetty directly without the intermediate Caddy applying proper routing
- **Fix:** Changed proxy targets in VM451 Caddyfile:
  - `raster.cleargeo.tech` → `reverse_proxy http://10.10.10.203:80` (caddy-gsr)
  - `vector.cleargeo.tech` → `reverse_proxy http://10.10.10.204:80` (caddy-gsv)

#### Fix 3 — VM451: Health check removal
- **Problem:** `health_uri /status` health probes sent `Host: 10.10.10.203` (upstream IP), not `Host: raster.cleargeo.tech` → `caddy-gsr` returned 308 redirect → Caddy marked upstream unhealthy → 503 errors
- **Fix:** Removed `health_uri` from both raster and vector `reverse_proxy` blocks in VM451 Caddyfile
- **Rationale:** `caddy-gsr`/`caddy-gsv` already perform their own health checks against GeoServer; double health-checking with an incorrect Host header causes false-positive failures

**Deployment method:** SSH pull → local edit with `write_to_file` → SCP push → `sudo cp` → `caddy validate` → `docker exec caddy caddy reload`

**Verified results:**
```
curl https://raster.cleargeo.tech/status                          → "OK" HTTP:200 ✅
curl https://vector.cleargeo.tech/status                          → "OK" HTTP:200 ✅
curl "https://raster.cleargeo.tech/geoserver/ows?service=WMS&version=1.3.0&request=GetCapabilities"
                                                                  → </WMS_Capabilities> HTTP:200 ✅
curl "https://vector.cleargeo.tech/geoserver/ows?service=WFS&version=2.0.0&request=GetCapabilities"
                                                                  → Full WFS 2.0.0 XML with CVG feature types HTTP:200 ✅
```

---

## Local File Reference

| Local File | Target VM | Remote Path |
|---|---|---|
| `G:\07_APPLICATIONS_TOOLS\CVG_Geoserver_Raster\caddy\Caddyfile` | VM454 | `/opt/cvg/CVG_Geoserver_Raster/caddy/Caddyfile` |
| `G:\07_APPLICATIONS_TOOLS\CVG_Geoserver_Vector\caddy\Caddyfile` | VM455 | `/opt/cvg/CVG_Geoserver_Vector/caddy/Caddyfile` |
| `G:\07_APPLICATIONS_TOOLS\CVG_Geoserver_Raster\vm451_Caddyfile_live.txt` | VM451 | `/opt/cvg-platform/Caddyfile` |

---

## Pending / Future Work

| ID | Task | Priority |
|---|---|---|
| BF-13 | Deploy SSW_API_KEY enforcement to VM451 | High |
| OPS-01 | Add `localhost { tls internal; handle /status {...}; respond 404 }` block back to VM454/VM455 production Caddyfiles (verify if already present in container) | Low |
| OPS-02 | Re-evaluate if `health_uri` can be re-enabled on VM451 once caddy-gsr/gsv respond to IP-based Host headers | Low |
