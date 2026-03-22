#!/usr/bin/env python3
"""
Patch VM451 /opt/cvg-platform/Caddyfile:
  - Replace raster.cleargeo.tech block: proxy to http://10.10.10.203:80 (caddy-gsr)
  - Replace vector.cleargeo.tech block: proxy to http://10.10.10.204:80 (caddy-gsv)
"""
import re, shutil, sys

CADDYFILE = '/opt/cvg-platform/Caddyfile'
shutil.copy(CADDYFILE, CADDYFILE + '.bak2')
print(f'Backed up to {CADDYFILE}.bak2')

with open(CADDYFILE, 'r') as f:
    content = f.read()

RASTER_NEW = """\
# -- GeoServer Raster (raster.cleargeo.tech) ----------------------------------
raster.cleargeo.tech {
    encode gzip zstd

    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        -Server
        -X-Powered-By
    }

    # All routing, access control, and CORS handled by caddy-gsr on VM454:80
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
        flush_interval -1
        health_uri      /status
        health_interval 30s
        health_timeout  10s
    }

    log {
        output file /data/logs/geoserver-raster.log {
            roll_size 50mb
            roll_keep 7
        }
    }
}"""

VECTOR_NEW = """\
# -- GeoServer Vector (vector.cleargeo.tech) -----------------------------------
vector.cleargeo.tech {
    encode gzip zstd

    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        -Server
        -X-Powered-By
    }

    # All routing, access control, and CORS handled by caddy-gsv on VM455:80
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
        flush_interval -1
        health_uri      /status
        health_interval 30s
        health_timeout  10s
    }

    log {
        output file /data/logs/geoserver-vector.log {
            roll_size 50mb
            roll_keep 7
        }
    }
}"""

# Match entire block: comment line + site block (from opening { to standalone })
raster_pat = re.compile(
    r'# -- GeoServer Raster \(raster\.cleargeo\.tech\).*?^raster\.cleargeo\.tech \{[^}]*(?:\{[^}]*\}[^}]*)*\}',
    re.DOTALL | re.MULTILINE
)
vector_pat = re.compile(
    r'# -- GeoServer Vector \(vector\.cleargeo\.tech\).*?^vector\.cleargeo\.tech \{[^}]*(?:\{[^}]*\}[^}]*)*\}',
    re.DOTALL | re.MULTILINE
)

m = raster_pat.search(content)
if not m:
    print('ERROR: raster block not found'); sys.exit(1)
print(f'Found raster block at chars {m.start()}–{m.end()}')

m = vector_pat.search(content)
if not m:
    print('ERROR: vector block not found'); sys.exit(1)
print(f'Found vector block at chars {m.start()}–{m.end()}')

content = raster_pat.sub(RASTER_NEW, content, count=1)
content = vector_pat.sub(VECTOR_NEW, content, count=1)

with open(CADDYFILE, 'w') as f:
    f.write(content)

print('Patch applied OK — run: docker exec cvg-caddy caddy validate --config /etc/caddy/Caddyfile')
