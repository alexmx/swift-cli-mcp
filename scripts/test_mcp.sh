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

    # 5. List resource templates
    send_request '{"jsonrpc":"2.0","id":4,"method":"resources/templates/list","params":{}}' "List Resource Templates"

    # 6. List prompts
    send_request '{"jsonrpc":"2.0","id":5,"method":"prompts/list","params":{}}' "List Prompts"

    # 7. Call echo tool
    send_request '{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"echo","arguments":{"message":"Hello, MCP!"}}}' "Echo Tool"

    # 8. Call generate_report tool
    send_request '{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"generate_report","arguments":{"title":"Test Report"}}}' "Generate Report Tool"

    # 9. Call divide tool (success)
    send_request '{"jsonrpc":"2.0","id":8,"method":"tools/call","params":{"name":"divide","arguments":{"a":10,"b":2}}}' "Divide Tool (10 / 2)"

    # 10. Call divide tool (error - division by zero)
    send_request '{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"divide","arguments":{"a":10,"b":0}}}' "Divide Tool (division by zero)"

    # 11. Read README resource
    send_request '{"jsonrpc":"2.0","id":10,"method":"resources/read","params":{"uri":"test://readme"}}' "Read README Resource"

    # 12. Read system info resource
    send_request '{"jsonrpc":"2.0","id":11,"method":"resources/read","params":{"uri":"test://sysinfo"}}' "Read System Info Resource"

    # 13. Get code_review prompt
    send_request '{"jsonrpc":"2.0","id":12,"method":"prompts/get","params":{"name":"code_review","arguments":{"code":"func add(a: Int, b: Int) -> Int { return a + b }","language":"swift"}}}' "Get Prompt (code_review)"

    # 14. Get summarize prompt
    send_request '{"jsonrpc":"2.0","id":13,"method":"prompts/get","params":{"name":"summarize","arguments":{"content":"MCP is a protocol for LLM tool use.","focus":"technical details"}}}' "Get Prompt (summarize)"

    # 15. Set log level
    send_request '{"jsonrpc":"2.0","id":14,"method":"logging/setLevel","params":{"level":"warning"}}' "Set Log Level (warning)"

    # 16. Ping
    send_request '{"jsonrpc":"2.0","id":15,"method":"ping","params":{}}' "Ping"

    # --- Error cases ---

    # 17. Unknown method
    send_request '{"jsonrpc":"2.0","id":16,"method":"unknown/method","params":{}}' "Unknown Method (should error)"

    # 18. Unknown tool
    send_request '{"jsonrpc":"2.0","id":17,"method":"tools/call","params":{"name":"nonexistent","arguments":{}}}' "Unknown Tool (should error)"

    # 19. Unknown resource
    send_request '{"jsonrpc":"2.0","id":18,"method":"resources/read","params":{"uri":"bad://uri"}}' "Unknown Resource (should error)"

    # 20. Unknown prompt
    send_request '{"jsonrpc":"2.0","id":19,"method":"prompts/get","params":{"name":"nonexistent"}}' "Unknown Prompt (should error)"

    # 21. Missing tool name
    send_request '{"jsonrpc":"2.0","id":20,"method":"tools/call","params":{}}' "Missing Tool Name (should error)"

    # 22. Missing resource URI
    send_request '{"jsonrpc":"2.0","id":21,"method":"resources/read","params":{}}' "Missing Resource URI (should error)"

    # 23. Missing prompt name
    send_request '{"jsonrpc":"2.0","id":22,"method":"prompts/get","params":{}}' "Missing Prompt Name (should error)"

    # 24. Invalid log level
    send_request '{"jsonrpc":"2.0","id":23,"method":"logging/setLevel","params":{"level":"verbose"}}' "Invalid Log Level (should error)"

    # 25. Invalid JSON-RPC version
    send_request '{"jsonrpc":"1.0","id":24,"method":"ping","params":{}}' "Invalid JSON-RPC Version (should error)"

    # 26. Cancellation notification
    send_request '{"jsonrpc":"2.0","method":"notifications/cancelled","params":{"requestId":999,"reason":"test cancellation"}}' "Cancel Request (notification)"

} | while IFS= read -r line; do
    echo "$line"
done

echo "============================"
echo "Tests Complete!"
