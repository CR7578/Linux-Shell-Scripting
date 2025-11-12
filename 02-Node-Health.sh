#!/bin/bash

##############################
# Author : CHETHAN N
# Date : 11/12/2025
#
# This Script outputs a comprehensive, color-coded report 
# on the Node/Server/Instance health, including CPU, Memory, 
# Disk, and Process metrics.
#
# Version : v2.3 - Advanced Industry Report (Root Disk Only)
##############################

# --- Execution Settings ---
# Exit immediately if a command exits with a non-zero status.
set -e
# Exit immediately if any command in a pipeline fails.
set -o pipefail
# set -x # Uncomment for debug mode

# --- Color Definitions ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color (Reset)

# --- Configuration Section ---
REPORT_FILE="/tmp/Node_health_report_$(date +%Y%m%d_%H%M%S).txt"
CPU_LOAD_1M_THRESHOLD=2.0      # Threshold for 1-minute Load Average
CPU_LOAD_5M_THRESHOLD=1.5      # Threshold for 5-minute Load Average
MEM_THRESHOLD=90               # Threshold for Memory Usage percentage
DISK_THRESHOLD=90              # Threshold for Disk Usage percentage
PROC_THRESHOLD=500             # Threshold for total running processes
DATE_TIME=$(date +"%Y-%m-%d %H:%M:%S")

# Global function to print to console AND tee to report file
log() {
    echo -e "$1" | tee -a "$REPORT_FILE"
}

# --- Reporting Functions ---

function print_header() {
    log "=========================================================="
    log "|          SERVER HEALTH REPORT - $(hostname)           |"
    log "=========================================================="
    log "Report Time: ${DATE_TIME}"
    log "----------------------------------------------------------"
}

function check_system_info() {
    log "\n### 1. SYSTEM METADATA ###"
    log "$(lsb_release -ds 2>/dev/null || cat /etc/*release 2>/dev/null | head -n1)"
    log "Kernel: $(uname -r)"
    log "Architecture: $(uname -m)"
    log "Uptime: $(uptime -p)"
    log "----------------------------------------------------------"
}

function check_cpu_load() {
    log "\n### 2. CPU LOAD & USAGE ###"
    
    # Get all three load averages
    LOAD_AVG=$(uptime | awk -F"load average: " '{print $2}' | sed 's/,//g')
    LOAD_1M=$(echo "$LOAD_AVG" | awk '{print $1}')
    LOAD_5M=$(echo "$LOAD_AVG" | awk '{print $2}')
    LOAD_15M=$(echo "$LOAD_AVG" | awk '{print $3}')

    log "Current Load Average (1m, 5m, 15m): ${LOAD_AVG}"
    
    # Check 1-minute load. Use `if (( ... ))` for proper floating-point comparison using bc.
    if (( $(echo "$LOAD_1M > $CPU_LOAD_1M_THRESHOLD" | bc -l) )); then
        log "${RED}CRITICAL: 1-min Load ($LOAD_1M) is above threshold ($CPU_LOAD_1M_THRESHOLD).${NC}"
    elif (( $(echo "$LOAD_5M > $CPU_LOAD_5M_THRESHOLD" | bc -l) )); then
        log "${YELLOW}WARNING: 5-min Load ($LOAD_5M) is elevated above threshold ($CPU_LOAD_5M_THRESHOLD).${NC}"
    else
        log "${GREEN}STATUS: CPU Load is within acceptable limits.${NC}"
    fi

    log "----------------------------------------------------------"
}

function check_memory_usage() {
    log "\n### 3. MEMORY USAGE ###"
    
    # Calculate RAM usage percentage
    MEM_FREE=$(free | grep Mem | awk '{print $4+$6}') # Free + Cached/Buffers
    MEM_TOTAL=$(free | grep Mem | awk '{print $2}')
    MEM_USED_PERCENT=$(echo "scale=2; 100 * ($MEM_TOTAL - $MEM_FREE) / $MEM_TOTAL" | bc -l)
    
    # Get Swap usage
    SWAP_USED=$(free | grep Swap | awk '{print $3}')
    SWAP_TOTAL=$(free | grep Swap | awk '{print $2}')
    
    # Added scale=2 for cleaner GB output
    log "Total RAM: $(echo "scale=2; $MEM_TOTAL / 1024 / 1024" | bc -l) GB"
    log "Used RAM: $(echo "scale=2; $MEM_USED_PERCENT / 1" | bc)%" # Format percentage
    
    # Check Memory usage.
    if (( $(echo "$MEM_USED_PERCENT > $MEM_THRESHOLD" | bc -l) )); then
        log "${RED}CRITICAL: RAM utilization ($(echo "scale=2; $MEM_USED_PERCENT / 1" | bc)%) is above threshold ($MEM_THRESHOLD%).${NC}"
        # Provide detailed output for diagnosis
        free -h
    else
        log "${GREEN}STATUS: RAM utilization is healthy.${NC}"
    fi
    
    # Check Swap
    if [ "$SWAP_TOTAL" -gt 0 ] && [ "$SWAP_USED" -gt 0 ]; then
        log "SWAP Used: $(echo "scale=2; 100 * $SWAP_USED / $SWAP_TOTAL" | bc -l)%"
        log "${YELLOW}WARNING: SWAP is being used. This may indicate memory pressure.${NC}"
    elif [ "$SWAP_TOTAL" -eq 0 ]; then
        log "STATUS: No SWAP configured."
    else
        log "STATUS: SWAP is unused."
    fi

    log "----------------------------------------------------------"
}

function check_disk_usage() {
    log "\n### 4. DISK UTILIZATION (Root Partition Only) ###"

    # Get the line for the root filesystem ('/') and extract usage percentage and partition name
    ROOT_LINE=$(df -h / | tail -1)
    USAGE=$(echo "$ROOT_LINE" | awk '{print $5}' | sed 's/%//g')
    PARTITION=$(echo "$ROOT_LINE" | awk '{print $1}')
    MOUNT_POINT=$(echo "$ROOT_LINE" | awk '{print $6}')

    # Log the current usage
    log "Partition: ${PARTITION} mounted on ${MOUNT_POINT}"
    log "Usage: ${USAGE}%"

    if [ "$USAGE" -gt "$DISK_THRESHOLD" ]; then
        log "${RED}CRITICAL: Root disk usage (${USAGE}%) is above threshold (${DISK_THRESHOLD}%).${NC}"
        # Show details for the critical partition
        df -h / | log
    elif [ "$USAGE" -gt 80 ]; then
        log "${YELLOW}WARNING: Root disk usage (${USAGE}%) is elevated (>80%).${NC}"
    else
        log "${GREEN}STATUS: Root disk usage is healthy.${NC}"
    fi
    
    log "----------------------------------------------------------"
}

function check_process_count() {
    log "\n### 5. PROCESS AND USER COUNT ###"
    
    PROCESS_COUNT=$(ps -e | wc -l)
    USER_COUNT=$(who | awk '{print $1}' | sort -u | wc -l)
    
    log "Total Running Processes: $PROCESS_COUNT"
    log "Total Logged-in Users: $USER_COUNT"
    
    if [ "$PROCESS_COUNT" -gt "$PROC_THRESHOLD" ]; then
        log "${YELLOW}WARNING: Total processes ($PROCESS_COUNT) is high (>${PROC_THRESHOLD}).${NC}"
        # Log top 5 processes using the most memory/CPU for quick diagnosis
        log "Top 5 Processes (CPU/MEM):"
        ps aux --sort=-%cpu | head -n 6 | tail -n 5 | log
    else
        log "${GREEN}STATUS: Process count is normal.${NC}"
    fi
    
    log "----------------------------------------------------------"
}


# --- Main Execution ---

# Clear / Init Fresh Report file
echo "----- New Server Health Report START -----" > "$REPORT_FILE"
echo ""

# The main execution flow now prints results to console and file simultaneously
print_header
check_system_info
check_cpu_load
check_memory_usage
check_disk_usage
check_process_count

# Final Message
log "\n=========================================================="
log "| REPORT COMPLETE. Detailed findings saved to:             |"
log "| ${REPORT_FILE}                                  |"
log "=========================================================="
