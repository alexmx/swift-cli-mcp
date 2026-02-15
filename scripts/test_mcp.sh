#!/bin/bash

# Test script for MCP server
# Sends JSON-RPC requests and displays responses

SERVER="./.build/debug/test-server"

echo "Starting MCP Server Tests..."
echo "============================"
echo ""

# Helper function to send request and display response
send_request() {
    local request=$1
    local description=$2
    echo "Test: $description"
    echo "Request: $request"
    echo -n "Response: "
    echo "$request" | $SERVER | head -1
    echo ""
}

# Start tests
{
    # 1. Initialize
    send_request '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' "Initialize"

    # 2. Send initialized notification
    send_request '{"jsonrpc":"2.0","method":"notifications/initialized"}' "Client Initialized (notification)"

    # 3. List tools
    send_request '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' "List Tools"

    # 4. List resources
    send_request '{"jsonrpc":"2.0","id":3,"method":"resources/list","params":{}}' "List Resources"

    # 5. Call echo tool
    send_request '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"echo","arguments":{"message":"Hello, MCP!"}}}' "Echo Tool"

    # 6. Call generate_report tool
    send_request '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"generate_report","arguments":{"title":"Test Report"}}}' "Generate Report Tool"

    # 7. Call divide tool (success)
    send_request '{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"divide","arguments":{"a":10,"b":2}}}' "Divide Tool (10 / 2)"

    # 8. Call divide tool (error - division by zero)
    send_request '{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"divide","arguments":{"a":10,"b":0}}}' "Divide Tool (division by zero)"

    # 9. Read README resource
    send_request '{"jsonrpc":"2.0","id":8,"method":"resources/read","params":{"uri":"test://readme"}}' "Read README Resource"

    # 10. Read system info resource
    send_request '{"jsonrpc":"2.0","id":9,"method":"resources/read","params":{"uri":"test://sysinfo"}}' "Read System Info Resource"

    # 11. Ping
    send_request '{"jsonrpc":"2.0","id":10,"method":"ping","params":{}}' "Ping"

    # 12. Unknown method (should error)
    send_request '{"jsonrpc":"2.0","id":11,"method":"unknown/method","params":{}}' "Unknown Method (should error)"

    # 13. Invalid JSON-RPC version (should fail parsing)
    send_request '{"jsonrpc":"1.0","id":12,"method":"ping","params":{}}' "Invalid JSON-RPC Version"

} | while IFS= read -r line; do
    echo "$line"
done

echo "============================"
echo "Tests Complete!"
