#!/usr/bin/env python3
"""
Patch VM451 Caddyfile — insert raster.cleargeo.tech + vector.cleargeo.tech
reverse-proxy blocks (pointing to VM454:80 and VM455:80) before the catch-all.

Run on VM451:  python3 /tmp/caddy_vm451_patch.py
"""
import shutil, sys

fpath = '/opt/cvg-platform/caddy/Caddyfile'

# ── Back up original ────────────────────────────────────────────────────────
shutil.copy(fpath, fpath + '.bak')
print(f'[+] Backed up to {fpath}.bak')

with open(fpath, 'r') as f:
    content = f.read()

# ── Guard against double-patching ───────────────────────────────────────────
if 'raster.cleargeo.tech' in content:
    print('[!] raster.cleargeo.tech already present in Caddyfile — skipping patch.')
    sys.exit(0)

# ── Update header comment ────────────────────────────────────────────────────
old_comment = '#   admin.cleargeo.tech        -- redirect -> portainer.cleargeo.tech'
new_comment  = (
    '#   admin.cleargeo.tech        -- redirect -> portainer.cleargeo.tech\n'
    '#   raster.cleargeo.tech       -- GeoServer Raster proxy → VM 454 (10.10.10.203)\n'
    '#   vector.cleargeo.tech       -- GeoServer Vector proxy → VM 455 (10.10.10.204)'
)
content = content.replace(old_comment, new_comment, 1)

# ── New site blocks ──────────────────────────────────────────────────────────
new_blocks = r"""
# -- GeoServer Raster (VM 454: 10.10.10.203) ----------------------------------
# VM451 Caddy terminates TLS for raster.cleargeo.tech then proxies plain HTTP
# to VM454's Caddy (caddy-gsr) on port 80. VM454's Caddyfile has an explicit
# http://raster.cleargeo.tech block to prevent Caddy's auto HTTP->HTTPS redirect.
raster.cleargeo.tech {
    encode gzip zstd

    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options    "nosniff"
        X-Frame-Options           "SAMEORIGIN"
        Referrer-Policy           "strict-origin-when-cross-origin"
        -Server
    }

    reverse_proxy http://10.10.10.203:80 {
        header_up Host              {host}
        header_up X-Forwarded-For   {remote_host}
        header_up X-Real-IP         {remote_host}
        header_up X-Forwarded-Proto {scheme}
        transport http {
            dial_timeout            30s
            response_header_timeout 120s
            read_timeout            300s
            write_timeout           300s
        }
        health_uri      /status
        health_interval 30s
        health_timeout  10s
    }

    log {
        output file /data/logs/raster.log {
            roll_size 20mb
            roll_keep 5
        }
    }
}

# -- GeoServer Vector (VM 455: 10.10.10.204) ----------------------------------
# VM451 Caddy terminates TLS for vector.cleargeo.tech then proxies plain HTTP
# to VM455's Caddy (caddy-gsv) on port 80. VM455's Caddyfile has an explicit
# http://vector.cleargeo.tech block to prevent Caddy's auto HTTP->HTTPS redirect.
vector.cleargeo.tech {
    encode gzip zstd

    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options    "nosniff"
        X-Frame-Options           "SAMEORIGIN"
        Referrer-Policy           "strict-origin-when-cross-origin"
        -Server
    }

    reverse_proxy http://10.10.10.204:80 {
        header_up Host              {host}
        header_up X-Forwarded-For   {remote_host}
        header_up X-Real-IP         {remote_host}
        header_up X-Forwarded-Proto {scheme}
        transport http {
            dial_timeout            30s
            response_header_timeout 60s
            read_timeout            300s
            write_timeout           300s
        }
        health_uri      /status
        health_interval 30s
        health_timeout  10s
    }

    log {
        output file /data/logs/vector.log {
            roll_size 20mb
            roll_keep 5
        }
    }
}

"""

# ── Splice before catch-all ──────────────────────────────────────────────────
CATCHALL = '# -- Catch-all (block unknown hosts)'
if CATCHALL not in content:
    print(f'[ERROR] Could not find insertion point "{CATCHALL}" in Caddyfile!')
    sys.exit(1)

content = content.replace(CATCHALL, new_blocks + CATCHALL, 1)

with open(fpath, 'w') as f:
    f.write(content)

print(f'[+] Caddyfile patched successfully: raster + vector blocks inserted.')
print(f'[+] Run:  docker exec cvg-caddy caddy reload --config /etc/caddy/Caddyfile')
