#!/usr/bin/env python3
"""Patch /opt/cvg-platform/Caddyfile: add acme_ca directive after email line."""
import sys

CF = "/opt/cvg-platform/Caddyfile"
NEEDLE = "acme_ca https://acme-v02.api.letsencrypt.org/directory"

with open(CF) as f:
    txt = f.read()

if NEEDLE in txt:
    print("  [skip] acme_ca already present")
    sys.exit(0)

if "email organization-support@cleargeo.tech" not in txt:
    print("  [ERROR] email directive not found — check Caddyfile manually")
    sys.exit(1)

txt = txt.replace(
    "email organization-support@cleargeo.tech",
    "email organization-support@cleargeo.tech\n    # Use Let's Encrypt only — disables ZeroSSL fallback\n    acme_ca https://acme-v02.api.letsencrypt.org/directory",
    1
)

with open(CF, "w") as f:
    f.write(txt)

# Verify
with open(CF) as f:
    v = f.read()

if NEEDLE in v:
    print("  [OK] acme_ca patched successfully")
else:
    print("  [ERROR] acme_ca not found after write!")
    sys.exit(1)
