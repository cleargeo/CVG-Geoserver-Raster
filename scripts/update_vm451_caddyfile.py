#!/usr/bin/env python3
"""
Update VM451 Caddyfile to add portal handle blocks for raster and vector GeoServer sites.
Run on VM451: python3 /tmp/update_vm451_caddyfile.py
"""
import sys
import shutil
import os
from datetime import datetime

CADDYFILE = '/opt/cvg-platform/Caddyfile'
BACKUP = f'/opt/cvg-platform/Caddyfile.bak.portal_{datetime.now().strftime("%Y%m%d_%H%M%S")}'

# Read current Caddyfile
with open(CADDYFILE, 'r') as f:
    content = f.read()

# Check if already updated
if '/srv/static/geoserver-raster' in content:
    print(f'ALREADY_UPDATED: Portal handle blocks already exist in {CADDYFILE}')
    sys.exit(0)

# Backup
shutil.copy2(CADDYFILE, BACKUP)
print(f'Backup created: {BACKUP}')

RASTER_PORTAL_BLOCK = """    # Portal — CVG Raster proprietary data access portal at root
    handle / {
        root * /srv/static/geoserver-raster
        file_server
    }
    handle /portal/* {
        uri strip_prefix /portal
        root * /srv/static/geoserver-raster
        file_server
    }

"""

VECTOR_PORTAL_BLOCK = """    # Portal — CVG Vector proprietary data access portal at root
    handle / {
        root * /srv/static/geoserver-vector
        file_server
    }
    handle /portal/* {
        uri strip_prefix /portal
        root * /srv/static/geoserver-vector
        file_server
    }

"""

# Insert for raster — before the catch-all reverse_proxy
RASTER_MARKER = '    # OWS / REST / GWC — public GIS endpoints\n    reverse_proxy cvg-geoserver-raster:8080'
if RASTER_MARKER not in content:
    print('ERROR: Raster marker not found in Caddyfile')
    sys.exit(1)
content = content.replace(RASTER_MARKER, RASTER_PORTAL_BLOCK + RASTER_MARKER)
print('Raster portal block inserted')

# Insert for vector — before the catch-all reverse_proxy
VECTOR_MARKER = '    # OWS / WFS / WMS — public GIS endpoints\n    reverse_proxy cvg-geoserver-vector:8080'
if VECTOR_MARKER not in content:
    print('ERROR: Vector marker not found in Caddyfile')
    sys.exit(1)
content = content.replace(VECTOR_MARKER, VECTOR_PORTAL_BLOCK + VECTOR_MARKER)
print('Vector portal block inserted')

# Write updated Caddyfile
with open(CADDYFILE, 'w') as f:
    f.write(content)

print(f'SUCCESS: {CADDYFILE} updated with portal handle blocks')
print('Run: docker exec cvg-caddy caddy reload --config /etc/caddy/Caddyfile')
