#!/usr/bin/env bash
# Debug why Vector charset isn't being set
SSH_KEY="${HOME}/.ssh/cvg_neuron_proxmox"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o LogLevel=ERROR)

ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" ubuntu@10.10.10.204 bash << 'REMOTE'
set -x  # trace every command

echo "=== Step 1: GET settings.json (stream to stdout) ==="
docker exec geoserver-vector curl -sS -u admin:geoserver --max-time 15 \
  "http://localhost:8080/geoserver/rest/settings.json" > /tmp/debug_gs_vec.json
echo "Exit: $?"
echo "Size: $(wc -c < /tmp/debug_gs_vec.json) bytes"
head -c 200 /tmp/debug_gs_vec.json

echo ""
echo "=== Step 2: Show current charset value ==="
python3 -c "
import json
with open('/tmp/debug_gs_vec.json') as f: d=json.load(f)
print('Keys in global:', list(d.get('global',{}).keys()))
s = d.get('global',{}).get('settings',{})
print('Keys in settings:', list(s.keys()))
print('charset:', s.get('charset','NOT FOUND'))
print('numDecimals:', s.get('numDecimals','NOT FOUND'))
"

echo ""
echo "=== Step 3: Patch and write fixed JSON ==="
python3 -c "
import json
with open('/tmp/debug_gs_vec.json') as f: d=json.load(f)
d['global']['settings']['charset'] = 'UTF-8'
if d['global']['settings'].get('contact') is None:
    d['global']['settings']['contact'] = {}
with open('/tmp/debug_gs_fixed.json','w') as f: json.dump(d,f)
print('Patched OK')
import os; print('Fixed file size:', os.path.getsize('/tmp/debug_gs_fixed.json'))
"

echo ""
echo "=== Step 4: Verify fixed JSON has charset ==="
python3 -c "
import json
with open('/tmp/debug_gs_fixed.json') as f: d=json.load(f)
print('charset in fixed:', d['global']['settings'].get('charset','NOT FOUND'))
"

echo ""
echo "=== Step 5: docker cp fixed JSON into container ==="
docker cp /tmp/debug_gs_fixed.json geoserver-vector:/tmp/debug_gs_fixed.json
echo "cp exit: $?"

echo ""
echo "=== Step 6: PUT settings via REST (verbose) ==="
docker exec geoserver-vector curl -v -u admin:geoserver --max-time 15 \
  -X PUT -H "Content-Type: application/json" \
  -d @/tmp/debug_gs_fixed.json \
  "http://localhost:8080/geoserver/rest/settings" 2>&1

echo ""
echo "=== Step 7: GET settings again after PUT ==="
sleep 3
docker exec geoserver-vector curl -sS -u admin:geoserver --max-time 10 \
  "http://localhost:8080/geoserver/rest/settings.json" \
  | python3 -c "
import json,sys
d=json.load(sys.stdin)
print('charset after PUT:', d['global']['settings'].get('charset','NOT FOUND'))
"
REMOTE
