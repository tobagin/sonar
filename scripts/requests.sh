#!/bin/bash

# Sonar Webhook Testing Script
# Usage: ./scripts/requests.sh <ngrok-url>
# Example: ./scripts/requests.sh https://e1eee85f39f7.ngrok-free.app

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if URL is provided
if [ $# -eq 0 ]; then
    echo -e "${RED}Error: Please provide the ngrok URL${NC}"
    echo "Usage: $0 <ngrok-url>"
    echo "Example: $0 https://e1eee85f39f7.ngrok-free.app"
    exit 1
fi

URL="$1"
# Remove trailing slash if present
URL=${URL%/}

echo -e "${BLUE}🚀 Starting webhook tests for: ${URL}${NC}"
echo

# Function to send request and show status
send_request() {
    local method="$1"
    local path="$2"
    local content_type="$3"
    local data="$4"
    local description="$5"
    
    echo -e "${YELLOW}📤 Sending ${method} ${path} - ${description}${NC}"
    
    if [ -n "$data" ]; then
        response=$(curl -s -w "HTTP %{http_code}" \
            -X "$method" \
            -H "Content-Type: $content_type" \
            -H "User-Agent: Sonar-Test-Script/1.0" \
            -H "X-Test-ID: $(date +%s)" \
            -d "$data" \
            "$URL$path" 2>/dev/null || echo "FAILED")
    else
        response=$(curl -s -w "HTTP %{http_code}" \
            -X "$method" \
            -H "User-Agent: Sonar-Test-Script/1.0" \
            -H "X-Test-ID: $(date +%s)" \
            "$URL$path" 2>/dev/null || echo "FAILED")
    fi
    
    if [[ "$response" == *"HTTP 200"* ]]; then
        echo -e "${GREEN}✅ Success: $response${NC}"
    else
        echo -e "${RED}❌ Response: $response${NC}"
    fi
    echo
    sleep 0.5  # Small delay between requests
}

# 1. Simple GET request
send_request "GET" "/webhook" "" "" "Simple GET request"

# 2. GET with query parameters
send_request "GET" "/webhook?param1=value1&param2=value2&source=test" "" "" "GET with query parameters"

# 3. POST with JSON payload
json_payload='{
    "event": "user.created",
    "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")'",
    "data": {
        "user_id": "12345",
        "username": "testuser",
        "email": "test@example.com",
        "metadata": {
            "source": "api",
            "version": "1.0"
        }
    }
}'
send_request "POST" "/webhook" "application/json" "$json_payload" "POST with JSON payload"

# 4. POST with form data
form_data="username=testuser&email=test@example.com&action=signup&timestamp=$(date +%s)"
send_request "POST" "/webhook/form" "application/x-www-form-urlencoded" "$form_data" "POST with form data"

# 5. PUT request with JSON
put_payload='{
    "id": "67890",
    "action": "update",
    "changes": {
        "status": "active",
        "last_login": "'$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")'"
    }
}'
send_request "PUT" "/api/webhook" "application/json" "$put_payload" "PUT request with JSON"

# 6. DELETE request
send_request "DELETE" "/webhook/user/12345" "" "" "DELETE request"

# 7. PATCH request
patch_payload='[
    {"op": "replace", "path": "/status", "value": "inactive"},
    {"op": "add", "path": "/notes", "value": "Account suspended"}
]'
send_request "PATCH" "/webhook" "application/json-patch+json" "$patch_payload" "PATCH request with JSON Patch"

# 8. POST with XML payload
xml_payload='<?xml version="1.0" encoding="UTF-8"?>
<notification>
    <event>payment.completed</event>
    <timestamp>'$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")'</timestamp>
    <data>
        <transaction_id>txn_123456789</transaction_id>
        <amount currency="USD">29.99</amount>
        <status>completed</status>
        <customer>
            <id>cust_456</id>
            <email>customer@example.com</email>
        </customer>
    </data>
</notification>'
send_request "POST" "/webhook/payment" "application/xml" "$xml_payload" "POST with XML payload"

# 9. POST with plain text
text_payload="This is a plain text webhook payload.
It contains multiple lines
and various characters: !@#$%^&*()
Timestamp: $(date)"
send_request "POST" "/webhook/text" "text/plain" "$text_payload" "POST with plain text"

# 10. GitHub-style webhook
github_payload='{
    "zen": "Non-blocking is better than blocking.",
    "hook_id": 12345678,
    "hook": {
        "type": "Repository",
        "id": 12345678,
        "name": "web",
        "active": true,
        "events": ["push", "pull_request"],
        "config": {
            "content_type": "json",
            "insecure_ssl": "0",
            "url": "'$URL'/webhook"
        }
    },
    "repository": {
        "id": 35129377,
        "name": "public-repo",
        "full_name": "baxterthehacker/public-repo",
        "owner": {
            "login": "baxterthehacker",
            "id": 6752317,
            "type": "User"
        }
    }
}'
send_request "POST" "/webhook/github" "application/json" "$github_payload" "GitHub-style webhook"

# 11. Slack-style webhook
slack_payload='{
    "token": "test_token_123",
    "team_id": "T1234567890",
    "api_app_id": "A1234567890",
    "event": {
        "type": "message",
        "channel": "C1234567890",
        "user": "U1234567890",
        "text": "Hello from Slack webhook test!",
        "ts": "'$(date +%s.%3N)'"
    },
    "type": "event_callback",
    "event_id": "Ev'$(date +%s)'",
    "event_time": '$(date +%s)'
}'
send_request "POST" "/webhook/slack" "application/json" "$slack_payload" "Slack-style webhook"

# 12. Discord-style webhook
discord_payload='{
    "username": "Webhook Test Bot",
    "avatar_url": "https://example.com/avatar.png",
    "content": "Hello from Discord webhook test!",
    "embeds": [
        {
            "title": "Test Notification",
            "description": "This is a test webhook from the Sonar testing script",
            "color": 3066993,
            "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")'",
            "fields": [
                {
                    "name": "Status",
                    "value": "Testing",
                    "inline": true
                },
                {
                    "name": "Environment",
                    "value": "Development",
                    "inline": true
                }
            ]
        }
    ]
}'
send_request "POST" "/webhook/discord" "application/json" "$discord_payload" "Discord-style webhook"

# 13. Stripe-style webhook
stripe_payload='{
    "id": "evt_test_webhook",
    "object": "event",
    "api_version": "2020-08-27",
    "created": '$(date +%s)',
    "data": {
        "object": {
            "id": "ch_test_charge",
            "object": "charge",
            "amount": 2000,
            "currency": "usd",
            "customer": "cus_test_customer",
            "description": "Test charge from webhook script",
            "paid": true,
            "status": "succeeded"
        }
    },
    "livemode": false,
    "pending_webhooks": 1,
    "request": {
        "id": "req_test_request",
        "idempotency_key": null
    },
    "type": "charge.succeeded"
}'
send_request "POST" "/webhook/stripe" "application/json" "$stripe_payload" "Stripe-style webhook"

# 14. Large payload test
large_payload='{'
large_payload+='"message": "This is a test of a larger payload",'
large_payload+='"data": ['
for i in {1..50}; do
    large_payload+='{
        "id": '$i',
        "name": "Item '$i'",
        "description": "This is a description for item '$i' with some additional text to make the payload larger",
        "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")'",
        "metadata": {
            "key1": "value1_'$i'",
            "key2": "value2_'$i'",
            "key3": "value3_'$i'"
        }
    }'
    if [ $i -lt 50 ]; then
        large_payload+=','
    fi
done
large_payload+=']}'
send_request "POST" "/webhook/large" "application/json" "$large_payload" "Large payload test (50 items)"

# 15. Custom headers test
custom_headers_payload='{
    "test": "custom_headers",
    "message": "Testing webhook with custom headers"
}'

echo -e "${YELLOW}📤 Sending POST /webhook/headers - Custom headers test${NC}"
response=$(curl -s -w "HTTP %{http_code}" \
    -X "POST" \
    -H "Content-Type: application/json" \
    -H "User-Agent: Sonar-Test-Script/1.0" \
    -H "X-Test-ID: $(date +%s)" \
    -H "X-Custom-Header: CustomValue123" \
    -H "X-API-Key: test-api-key-789" \
    -H "X-Webhook-Source: sonar-test-script" \
    -H "Authorization: Bearer test-token-xyz" \
    -d "$custom_headers_payload" \
    "$URL/webhook/headers" 2>/dev/null || echo "FAILED")

if [[ "$response" == *"HTTP 200"* ]]; then
    echo -e "${GREEN}✅ Success: $response${NC}"
else
    echo -e "${RED}❌ Response: $response${NC}"
fi
echo

echo -e "${BLUE}🎉 All webhook tests completed!${NC}"
echo -e "${BLUE}Check your Sonar app to see all the received requests.${NC}"