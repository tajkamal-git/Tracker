<?php
/**
 * IP capture endpoint - serves as 1x1 tracking pixel
 */
$ip   = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
$ua   = $_SERVER['HTTP_USER_AGENT'] ?? 'unknown';
$time = date('Y-m-d H:i:s');

// Save IP
$entry = "$ip | $time | $ua\n";
file_put_contents(__DIR__ . '/ip.txt', $entry, FILE_APPEND | LOCK_EX);

// Also save for tracker.sh
file_put_contents(__DIR__ . '/ip.txt', "IP: $ip\n", LOCK_EX);

// Serve a 1x1 transparent GIF
header('Content-Type: image/gif');
header('Cache-Control: no-store, no-cache, must-revalidate');
echo base64_decode('R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7');
