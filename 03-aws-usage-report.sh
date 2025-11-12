#!/bin/bash

#############################################
# Author: CHETHAN N
# Date: 12/11/2025
#
# Version: v2.2 - Added detailed IDs/Dates
#
# This script generates a detailed, human-readable
# report of key AWS resource usage.
#
# Dependencies: aws cli, jq
#############################################

# --- Configuration ---
# Set the desired AWS region for reporting
AWS_REGION="us-east-1"
# Set AWS profile if needed (e.g., if you use multiple accounts)
# AWS_PROFILE="my-dev-profile"
# export AWS_PROFILE

# Enable strict error checking and trace (optional, but good practice)
set -euo pipefail

# Function to run aws command with error check
aws_cmd() {
    # If AWS_PROFILE is set, prepend it to the command
    if [ -n "${AWS_PROFILE:-}" ]; then
        aws --profile "${AWS_PROFILE}" "$@" --region "${AWS_REGION}"
    else
        aws "$@" --region "${AWS_REGION}"
    fi
}

# --- PRE-EXECUTION CHECKS ---

# Check for 'aws cli' dependency
if ! command -v aws &> /dev/null
then
    echo "ERROR: 'aws cli' could not be found."
    echo "Please install the AWS CLI and ensure it's in your PATH."
    exit 1
fi

# Check for 'jq' dependency
if ! command -v jq &> /dev/null
then
    echo "ERROR: 'jq' could not be found."
    echo "Please install 'jq' (JSON processor) to run this script."
    exit 1
fi

# Check AWS Configuration/Authentication
echo "Verifying AWS Configuration..."
if ! aws_cmd sts get-caller-identity > /dev/null 2>&1; then
    echo "ERROR: AWS Authentication failed."
    echo "Please ensure your credentials are set correctly for region ${AWS_REGION}."
    if [ -n "${AWS_PROFILE:-}" ]; then
        echo "Profile used: ${AWS_PROFILE}"
    fi
    exit 1
fi
echo "Configuration verified successfully."
echo ""

# --- REPORT GENERATION START ---

echo "=========================================================="
echo "      AWS RESOURCE USAGE REPORT - Region: ${AWS_REGION}     "
echo "=========================================================="
echo "Report Generated: $(date)"
echo ""

# --- 1. S3 BUCKET REPORT ---
echo "--- S3 BUCKET REPORT ---"
# Retrieving Name (the ID) and CreationDate for S3 buckets
S3_BUCKETS_JSON=$(aws_cmd s3api list-buckets \
    --query "Buckets[].{Name:Name, CreationDate:CreationDate}" \
    --output json || echo "[]")
S3_COUNT=$(echo "${S3_BUCKETS_JSON}" | jq '. | length')

if [ "${S3_COUNT}" -gt 0 ]; then
    echo "Total S3 Buckets Found: ${S3_COUNT}"
    echo ""
    echo "Detailed Bucket List (Name | Creation Date):"
    # Format output for better readability using column -t
    echo "${S3_BUCKETS_JSON}" | jq -r '.[] | "\(.Name) | \(.CreationDate)"' | column -t -s '|'
else
    echo "No S3 Buckets found in any region."
fi
echo ""

# --- 2. EC2 INSTANCE REPORT ---
echo "--- EC2 INSTANCE REPORT (Region: ${AWS_REGION}) ---"
# Already displaying ID and Name (from tags)
EC2_INSTANCES=$(aws_cmd ec2 describe-instances \
    --query 'Reservations[*].Instances[*].{ID:InstanceId, Type:InstanceType, State:State.Name, Name:Tags[?Key==`Name`]|[0].Value}' \
    --output json || echo "[]")

TOTAL_EC2_COUNT=$(echo "${EC2_INSTANCES}" | jq '. | length')

if [ "${TOTAL_EC2_COUNT}" -gt 0 ]; then
    RUNNING_COUNT=$(echo "${EC2_INSTANCES}" | jq '.[] | select(.State=="running")' | jq -s 'length')
    STOPPED_COUNT=$(echo "${EC2_INSTANCES}" | jq '.[] | select(.State=="stopped")' | jq -s 'length')

    echo "Total EC2 Instances Found: ${TOTAL_EC2_COUNT}"
    echo "  - Running: ${RUNNING_COUNT}"
    echo "  - Stopped: ${STOPPED_COUNT}"

    echo ""
    echo "Detailed Instance List (ID | State | Type | Name):"
    echo "${EC2_INSTANCES}" | jq -r '.[] | "\(.ID) | \(.State) | \(.Type) | \(.Name // "N/A")"' | column -t -s '|'
else
    echo "No EC2 Instances found in region ${AWS_REGION}."
fi
echo ""

# --- 3. LAMBDA FUNCTION REPORT ---
echo "--- LAMBDA FUNCTION REPORT (Region: ${AWS_REGION}) ---"
# Already displaying FunctionName (the Name) and other details
LAMBDA_FUNCTIONS=$(aws_cmd lambda list-functions \
    --query 'Functions[*].{Name:FunctionName, Runtime:Runtime, LastModified:LastModified}' \
    --output json || echo "[]")

LAMBDA_COUNT=$(echo "${LAMBDA_FUNCTIONS}" | jq '. | length')

if [ "${LAMBDA_COUNT}" -gt 0 ]; then
    echo "Total Lambda Functions Found: ${LAMBDA_COUNT}"

    echo ""
    echo "Detailed Function List (Name | Runtime | Last Modified):"
    # Format output for better readability using column -t
    echo "${LAMBDA_FUNCTIONS}" | jq -r '.[] | "\(.Name) | \(.Runtime) | \(.LastModified)"' | column -t -s '|'
else
    echo "No Lambda Functions found in region ${AWS_REGION}."
fi
echo ""

# --- 4. IAM USER REPORT ---
echo "--- IAM USER REPORT ---"
# Retrieving UserName and UserId
IAM_USERS_JSON=$(aws_cmd iam list-users \
    --query "Users[].{Name:UserName, ID:UserId}" \
    --output json || echo "[]")
IAM_COUNT=$(echo "${IAM_USERS_JSON}" | jq '. | length')

if [ "${IAM_COUNT}" -gt 0 ]; then
    echo "Total IAM Users Found: ${IAM_COUNT}"
    echo ""
    echo "Detailed IAM User List (Name | ID):"
    # Format output for better readability using column -t
    echo "${IAM_USERS_JSON}" | jq -r '.[] | "\(.Name) | \(.ID)"' | column -t -s '|'
else
    echo "No IAM Users found."
fi
echo ""

echo "=========================================================="
echo "          REPORT COMPLETE. Review findings above.         "
echo "=========================================================="
