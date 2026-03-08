## Quick Start Guide
## =================
## 
## Get started with SSE in Nim in under 5 minutes.
## 
## Run with: nim c -r examples/quick_start.nim

import ../src/sse

echo "=========================================="
echo "SSE Quick Start Guide"
echo "=========================================="
echo ""

# ============================================================
# Step 1: Create Your First Event (30 seconds)
# ============================================================
echo "Step 1: Create Your First Event"
echo "--------------------------------"

let evt1 = initSSEvent("Hello, SSE!")
echo "Simple event:"
echo evt1.format()

# ============================================================
# Step 2: Add Event Metadata (1 minute)
# ============================================================
echo "\nStep 2: Add Event Metadata"
echo "---------------------------"

let evt2 = initSSEvent("Important update", "notification", "msg-001", 5000)
echo "Full event:"
echo evt2.format()

# ============================================================
# Step 3: Parse Incoming SSE Data (2 minutes)
# ============================================================
echo "\nStep 3: Parse Incoming SSE Data"
echo "---------------------------------"

let rawData = """
data: First message

event: update
data: Second message
id: 2

"""

let events = parse(rawData)
echo "Parsed ", events.len, " events:"
for i, evt in events:
  echo "  Event ", i + 1, ": ", evt.data

# ============================================================
# Step 4: Stream Processing (3 minutes)
# ============================================================
echo "\nStep 4: Stream Processing"
echo "-------------------------"

var parser = initSSEParser()

# Simulate receiving data in chunks
discard parser.feed("data: Hel")
let chunk2 = parser.feed("lo\n\n")

echo "Streamed event: ", chunk2[0].data

# ============================================================
# Step 5: Heartbeat/Keep-Alive (4 minutes)
# ============================================================
echo "\nStep 5: Heartbeat/Keep-Alive"
echo "------------------------------"

echo "Simple heartbeat: ", formatHeartbeat()
echo "Heartbeat with comment: ", formatHeartbeat("ping")

# ============================================================
# Step 6: JSON Integration (5 minutes)
# ============================================================
echo "\nStep 6: JSON Integration"
echo "------------------------"

import std/json

let chatMsg = %*{
  "user": "Alice",
  "message": "Hello from JSON!"
}

let evt3 = initSSEvent($chatMsg, "chat")
echo "Event with JSON data:"
echo evt3.format()

# Parse back
let parsed = parse(evt3.format())
let jsonBack = parseJson(parsed[0].data)
echo "Parsed back:"
echo "  User: ", jsonBack["user"].getStr()
echo "  Message: ", jsonBack["message"].getStr()

# ============================================================
# Next Steps
# ============================================================
echo ""
echo "=========================================="
echo "Congratulations! You've learned the basics."
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Run: nim c -r examples/basic_usage.nim"
echo "  2. Run: nim c -r examples/http_server_examples.nim"
echo "  3. Run: nim c -r examples/http_client_examples.nim"
echo "  4. Run: nim c -r examples/run_all.nim (all examples)"
echo ""
echo "Documentation:"
echo "  - examples/README.md - Full example guide"
echo "  - README.md - Library documentation"
echo "  - docs/sse.html - API reference"
echo ""
