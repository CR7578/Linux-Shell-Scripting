#!/bin/bash


##############################
# Author : CHETHAN N
# Date : 11/11/2025
#
# This Script outputs the Node/Server/Instance health
#
# Version : v1
##############################

#set -x # Debug mode - Shows the commands in output.
set -e # Error mode - Exits the running script when error occurs.
set -o pipefail 


# --- Configuration Section ---
REPORT_FILE="/tmp/Node_health_report_$(date +%Y%m%d).txt"
LOAD_THRESHOLD=2.0                     # Threshold for 1-minute Load Average
DISK_THRESHOLD=90                      # Threshold for Disk Usage percentage
DATE_TIME=$(date +"%Y-%m-%d %H:%M:%S")


# Function to check the Node/Server Health - ( CPU , Memory , Disk )
function check_node_health(){
	echo "---- System Health Check started : $(date) ----" >> "$REPORT_FILE"
	echo "" >> "$REPORT_FILE"
	# Check CPU load 
	current_load=$(uptime | awk -F"load average: " '{print $2}' | cut -d, -f1 );
	echo "Current CPU average ( 1 min): $current_load" >> "$REPORT_FILE";
	if ($(echo "$current_load" > "$LOAD_THRESHOLD" | bc -l)); then
	       echo "Warning: High CPU load average detected !" >> "$REPORT_FILE"
	fi

	# Check disk space
	disk_usage=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//g')
	echo "Root disk space : $disk_usage%" >> "$REPORT_FILE";
	if [ $disk_usage -gt $DISK_THRESHOLD ]; then
		echo "Warning: Disk space is above $DISK_THRESHOLD%" >> "$REPORT_FILE"
		df -h / && echo "" >> "$REPORT_FILE"
	fi

	echo "" >> "$REPORT_FILE"
	echo "---- System Health Check Ended : $(date) ----" >> "$REPORT_FILE"
	
}


# Clear / Init Fresh Report file
echo "----- Generating Server Health Report -----";echo "" > "$REPORT_FILE"


# Main execution section
# Calling the function
check_node_health


# Generating Report end
echo "---------- Report Generated ---------------"; >> "$REPORT_FILE"

echo "";
echo "Content of $REPORT_FILE"
echo ""

cat $REPORT_FILE;
