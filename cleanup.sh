#!/bin/bash
echo "Starting cleanup of unnecessary files and logs..."

echo "Removing log files..."
rm -f *.log
rm -f .cloudflared.log

echo "Removing temporary location files..."
rm -f location_*.txt
rm -f current_location.bak

echo "Removing captured images..."
rm -f cam*.png
rm -f captures/cam*.png captures/cam*.jpg captures/cam*.webp 2>/dev/null

echo "Removing temporary HTML files..."
rm -f index.php
rm -f index2.html
rm -f index3.html

echo "Cleaning saved locations directory..."
if [ -d "location_data" ]; then
    rm -f location_data/*.ndjson
    rm -f location_data/daily/* 2>/dev/null
    rm -f location_data/sessions/* 2>/dev/null
fi

if [ -d "location_intel" ]; then
    rm -f location_intel/*.ndjson
    rm -f location_intel/daily/* 2>/dev/null
    rm -f location_intel/sessions/* 2>/dev/null
fi

echo "Removing other temporary files..."
rm -f LocationLog.log
rm -f LocationError.log
rm -f Log.log
rm -f ip.txt
rm -f visitors.log

echo "Cleanup completed successfully!"
