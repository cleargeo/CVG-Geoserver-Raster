# patch_portal.ps1 - Enhance both portals with basemap switcher, opacity, GetMap URL bar, GetFeatureInfo

Set-StrictMode -Off
$ErrorActionPreference = 'Stop'

# ── RASTER PORTAL ─────────────────────────────────────────────────────────────
$rFile = 'G:\07_APPLICATIONS_TOOLS\CVG_Geoserver_Raster\caddy\portal\index.html'
$rc = [System.IO.File]::ReadAllText($rFile, [System.Text.Encoding]::UTF8)

# HTML: replace mact+mapp block
$rOldHtml = '<div class="mact"><select class="msel" id="msel"><option value="">&#8212; Select a layer &#8212;</option></select><button class="mbtn" onclick="ldMap()">Load Layer &#9658;</button></div><div id="mapp"></div>'
$rNewHtml = '<div class="mact"><select class="msel" id="msel"><option value="">&#8212; Select a layer &#8212;</option></select><button class="mbtn" onclick="ldMap()">Load Layer &#9658;</button><select class="msel" id="bmap-sel" onchange="swBmap(this.value)" style="flex:0 0 auto;min-width:130px"><option value="dark">CartoDB Dark</option><option value="osm">OpenStreetMap</option><option value="sat">ESRI Satellite</option><option value="topo">OpenTopoMap</option></select><label style="font-size:.75rem;color:var(--tm);display:flex;align-items:center;gap:6px;white-space:nowrap">Opacity <input type="range" id="osl" min="0" max="1" step="0.05" value="0.8" oninput="setOp(this.value)" style="width:70px;accent-color:var(--acc);cursor:pointer"></label></div><div id="mapp"></div><div id="gmap-bar" style="background:var(--bg-in);border:1px solid var(--bdr);border-radius:var(--rs);padding:8px 12px;margin-top:8px;display:none;gap:8px;align-items:center;flex-wrap:wrap"><span style="color:var(--tm);flex-shrink:0;font-size:.68rem;font-weight:700">GetMap URL:</span><span id="gmap-url" style="font-family:Consolas,monospace;color:var(--tel);flex:1;overflow-x:auto;white-space:nowrap;font-size:.72rem"></span><button class="cbtn" onclick="navigator.clipboard.writeText(document.getElementById(''gmap-url'').textContent)">Copy</button></div>'

if ($rc.Contains($rOldHtml)) {
    $rc = $rc.Replace($rOldHtml, $rNewHtml)
    Write-Host "Raster: HTML block replaced OK"
} else {
    Write-Warning "Raster: HTML block NOT FOUND"
}

# JS: replace map functions
$rOldJs = 'var mapObj=null,wmsRef=null;function initMap(){if(mapObj)return;mapObj=L.map("mapp").setView([30,-90],5);L.tileLayer("https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png",{attribution:"&copy; CARTO",maxZoom:19}).addTo(mapObj);}function ldMap(){var l=document.getElementById("msel").value;if(!l){alert("Select a layer first.");return;}initMap();if(wmsRef)mapObj.removeLayer(wmsRef);wmsRef=L.tileLayer.wms("https://raster.cleargeo.tech/geoserver/wms",{layers:l,format:"image/png",transparent:true,version:"1.3.0"}).addTo(mapObj);}function prvL(n){document.getElementById("msel").value=n;document.getElementById("prv").scrollIntoView({behavior:"smooth"});ldMap();}'

$rNewJs = @'
var mapObj=null,wmsRef=null,curBm='dark';var BML={dark:L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',{attribution:'&copy; CARTO',maxZoom:19}),osm:L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',{attribution:'&copy; OpenStreetMap contributors',maxZoom:19}),sat:L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',{attribution:'&copy; Esri',maxZoom:18}),topo:L.tileLayer('https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',{attribution:'&copy; OpenTopoMap contributors',maxZoom:17})};function initMap(){if(mapObj)return;mapObj=L.map('mapp').setView([30,-90],5);BML.dark.addTo(mapObj);L.control.scale({imperial:true,metric:true}).addTo(mapObj);mapObj.on('moveend zoomend',updGMapUrl);}function swBmap(key){if(!mapObj)return;mapObj.removeLayer(BML[curBm]);curBm=key;BML[key].addTo(mapObj);if(wmsRef)wmsRef.bringToFront();}function setOp(v){if(wmsRef)wmsRef.setOpacity(parseFloat(v));}function updGMapUrl(){var l=(document.getElementById('msel')||{}).value;if(!mapObj||!l)return;var b=mapObj.getBounds(),sz=mapObj.getSize();var el=document.getElementById('gmap-url');if(el)el.textContent='https://raster.cleargeo.tech/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&LAYERS='+encodeURIComponent(l)+'&FORMAT=image%2Fpng&TRANSPARENT=true&CRS=EPSG%3A4326&WIDTH='+sz.x+'&HEIGHT='+sz.y+'&BBOX='+b.getSouth()+','+b.getWest()+','+b.getNorth()+','+b.getEast()+'&STYLES=';}function ldMap(){var l=document.getElementById('msel').value;if(!l){alert('Select a layer first.');return;}initMap();if(wmsRef)mapObj.removeLayer(wmsRef);var op=parseFloat((document.getElementById('osl')||{value:'0.8'}).value);wmsRef=L.tileLayer.wms('https://raster.cleargeo.tech/geoserver/wms',{layers:l,format:'image/png',transparent:true,version:'1.3.0',opacity:op}).addTo(mapObj);var gb=document.getElementById('gmap-bar');if(gb)gb.style.display='flex';updGMapUrl();mapObj.off('click');mapObj.on('click',function(e){var b=mapObj.getBounds(),sz=mapObj.getSize(),pt=mapObj.latLngToContainerPoint(e.latlng);fetch('https://raster.cleargeo.tech/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetFeatureInfo&LAYERS='+encodeURIComponent(l)+'&QUERY_LAYERS='+encodeURIComponent(l)+'&INFO_FORMAT=text%2Fplain&FEATURE_COUNT=1&WIDTH='+sz.x+'&HEIGHT='+sz.y+'&I='+Math.round(pt.x)+'&J='+Math.round(pt.y)+'&CRS=EPSG%3A4326&BBOX='+b.getSouth()+','+b.getWest()+','+b.getNorth()+','+b.getEast()).then(function(r){return r.text();}).then(function(txt){if(txt&&txt.trim()&&txt.indexOf('no results')<0)L.popup().setLatLng(e.latlng).setContent('<div style="font-family:Consolas,monospace;max-width:260px;white-space:pre-wrap;font-size:11px;color:#a5b4fc;padding:2px">'+txt.replace(/</g,'&lt;')+'</div>').openOn(mapObj);}).catch(function(){});});}function prvL(n){document.getElementById('msel').value=n;document.getElementById('prv').scrollIntoView({behavior:'smooth'});ldMap();}
'@
$rNewJs = $rNewJs.TrimEnd("`r","`n")

if ($rc.Contains($rOldJs)) {
    $rc = $rc.Replace($rOldJs, $rNewJs)
    Write-Host "Raster: JS block replaced OK"
} else {
    Write-Warning "Raster: JS block NOT FOUND"
}

# Fix the clipboard onclick - we used '' for single quotes in the HTML string above, restore them
$rc = $rc.Replace("document.getElementById(''gmap-url'').textContent", "document.getElementById('gmap-url').textContent")

[System.IO.File]::WriteAllText($rFile, $rc, [System.Text.Encoding]::UTF8)
Write-Host "Raster portal written: $((Get-Item $rFile).Length) bytes"

# ── VECTOR PORTAL ─────────────────────────────────────────────────────────────
$vFile = 'G:\07_APPLICATIONS_TOOLS\CVG_Geoserver_Vector\caddy\portal\index.html'
$vc = [System.IO.File]::ReadAllText($vFile, [System.Text.Encoding]::UTF8)

# HTML block is identical for both portals
$vOldHtml = $rOldHtml
$vNewHtml = $rNewHtml  # same HTML (no domain-specific content in the controls)
# But fix clipboard onclick for vector (same fix needed)

if ($vc.Contains($vOldHtml)) {
    $vc = $vc.Replace($vOldHtml, $vNewHtml)
    Write-Host "Vector: HTML block replaced OK"
} else {
    Write-Warning "Vector: HTML block NOT FOUND"
}

# JS: vector has same structure but different domain + window.addEventListener at end
$vOldJs = 'var mapObj=null,wmsRef=null;function initMap(){if(mapObj)return;mapObj=L.map("mapp").setView([30,-90],5);L.tileLayer("https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png",{attribution:"&copy; CARTO",maxZoom:19}).addTo(mapObj);}function ldMap(){var l=document.getElementById("msel").value;if(!l){alert("Select a layer first.");return;}initMap();if(wmsRef)mapObj.removeLayer(wmsRef);wmsRef=L.tileLayer.wms("https://vector.cleargeo.tech/geoserver/wms",{layers:l,format:"image/png",transparent:true,version:"1.3.0"}).addTo(mapObj);}function prvL(n){document.getElementById("msel").value=n;document.getElementById("prv").scrollIntoView({behavior:"smooth"});ldMap();}'

$vNewJs = @'
var mapObj=null,wmsRef=null,curBm='dark';var BML={dark:L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',{attribution:'&copy; CARTO',maxZoom:19}),osm:L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',{attribution:'&copy; OpenStreetMap contributors',maxZoom:19}),sat:L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',{attribution:'&copy; Esri',maxZoom:18}),topo:L.tileLayer('https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',{attribution:'&copy; OpenTopoMap contributors',maxZoom:17})};function initMap(){if(mapObj)return;mapObj=L.map('mapp').setView([30,-90],5);BML.dark.addTo(mapObj);L.control.scale({imperial:true,metric:true}).addTo(mapObj);mapObj.on('moveend zoomend',updGMapUrl);}function swBmap(key){if(!mapObj)return;mapObj.removeLayer(BML[curBm]);curBm=key;BML[key].addTo(mapObj);if(wmsRef)wmsRef.bringToFront();}function setOp(v){if(wmsRef)wmsRef.setOpacity(parseFloat(v));}function updGMapUrl(){var l=(document.getElementById('msel')||{}).value;if(!mapObj||!l)return;var b=mapObj.getBounds(),sz=mapObj.getSize();var el=document.getElementById('gmap-url');if(el)el.textContent='https://vector.cleargeo.tech/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&LAYERS='+encodeURIComponent(l)+'&FORMAT=image%2Fpng&TRANSPARENT=true&CRS=EPSG%3A4326&WIDTH='+sz.x+'&HEIGHT='+sz.y+'&BBOX='+b.getSouth()+','+b.getWest()+','+b.getNorth()+','+b.getEast()+'&STYLES=';}function ldMap(){var l=document.getElementById('msel').value;if(!l){alert('Select a layer first.');return;}initMap();if(wmsRef)mapObj.removeLayer(wmsRef);var op=parseFloat((document.getElementById('osl')||{value:'0.8'}).value);wmsRef=L.tileLayer.wms('https://vector.cleargeo.tech/geoserver/wms',{layers:l,format:'image/png',transparent:true,version:'1.3.0',opacity:op}).addTo(mapObj);var gb=document.getElementById('gmap-bar');if(gb)gb.style.display='flex';updGMapUrl();mapObj.off('click');mapObj.on('click',function(e){var b=mapObj.getBounds(),sz=mapObj.getSize(),pt=mapObj.latLngToContainerPoint(e.latlng);fetch('https://vector.cleargeo.tech/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetFeatureInfo&LAYERS='+encodeURIComponent(l)+'&QUERY_LAYERS='+encodeURIComponent(l)+'&INFO_FORMAT=application%2Fjson&FEATURE_COUNT=3&WIDTH='+sz.x+'&HEIGHT='+sz.y+'&I='+Math.round(pt.x)+'&J='+Math.round(pt.y)+'&CRS=EPSG%3A4326&BBOX='+b.getSouth()+','+b.getWest()+','+b.getNorth()+','+b.getEast()).then(function(r){return r.json();}).then(function(j){if(j.features&&j.features.length>0){var p=j.features[0].properties||{},ks=Object.keys(p);if(ks.length>0)L.popup().setLatLng(e.latlng).setContent('<div style="font-family:Consolas,monospace;max-width:280px;font-size:11px;color:#a5b4fc">'+ks.slice(0,8).map(function(k){return'<div><span style="color:#94a3b8">'+k+':</span> '+String(p[k]).slice(0,50)+'</div>';}).join('')+'</div>').openOn(mapObj);}}).catch(function(){});});}function prvL(n){document.getElementById('msel').value=n;document.getElementById('prv').scrollIntoView({behavior:'smooth'});ldMap();}
'@
$vNewJs = $vNewJs.TrimEnd("`r","`n")

if ($vc.Contains($vOldJs)) {
    $vc = $vc.Replace($vOldJs, $vNewJs)
    Write-Host "Vector: JS block replaced OK"
} else {
    Write-Warning "Vector: JS block NOT FOUND"
}

# Fix clipboard onclick
$vc = $vc.Replace("document.getElementById(''gmap-url'').textContent", "document.getElementById('gmap-url').textContent")

[System.IO.File]::WriteAllText($vFile, $vc, [System.Text.Encoding]::UTF8)
Write-Host "Vector portal written: $((Get-Item $vFile).Length) bytes"

Write-Host ""
Write-Host "=== Done. Review warnings above. ==="
