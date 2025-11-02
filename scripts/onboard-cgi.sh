#!/bin/sh
#
# CGI Script for Onboarding Form Handler
# Purpose: Process credentials and trigger WAN activation
# Place in /www/cgi-bin/onboard.sh
#

echo "Content-Type: application/json"
echo "Access-Control-Allow-Origin: *"
echo ""

# Parse POST data
if [ "$REQUEST_METHOD" = "POST" ]; then
    # Read POST data
    read POST_DATA
    
    # Parse form fields (simple parsing for demonstration)
    DEVICE_ID=$(echo "$POST_DATA" | sed -n 's/.*device_id=\([^&]*\).*/\1/p' | sed 's/%20/ /g' | sed 's/%40/@/g')
    API_KEY=$(echo "$POST_DATA" | sed -n 's/.*api_key=\([^&]*\).*/\1/p' | sed 's/%20/ /g')
    OWNER_EMAIL=$(echo "$POST_DATA" | sed -n 's/.*owner_email=\([^&]*\).*/\1/p' | sed 's/%20/ /g' | sed 's/%40/@/g')
    
    # URL decode (basic)
    DEVICE_ID=$(echo "$DEVICE_ID" | sed 's/+/ /g')
    API_KEY=$(echo "$API_KEY" | sed 's/+/ /g')
    OWNER_EMAIL=$(echo "$OWNER_EMAIL" | sed 's/+/ /g')
    
    # Log the attempt
    logger -t onboarding "Onboarding attempt for device: $DEVICE_ID, email: $OWNER_EMAIL"
    
    # Call WAN activation script
    if [ -x /home/runner/work/zero-trust-router-onboarding/zero-trust-router-onboarding/scripts/wan-activation.sh ]; then
        /home/runner/work/zero-trust-router-onboarding/zero-trust-router-onboarding/scripts/wan-activation.sh "$DEVICE_ID" "$API_KEY" "$OWNER_EMAIL"
    elif [ -x /opt/zero-trust/scripts/wan-activation.sh ]; then
        /opt/zero-trust/scripts/wan-activation.sh "$DEVICE_ID" "$API_KEY" "$OWNER_EMAIL"
    else
        echo '{"success": false, "error": "WAN activation script not found"}'
        exit 1
    fi
else
    echo '{"success": false, "error": "Invalid request method"}'
    exit 1
fi
