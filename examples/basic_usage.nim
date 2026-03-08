## Basic Usage Examples
## ====================
## 
## This file demonstrates basic SSE library usage.
## Run with: nim c -r examples/basic_usage.nim

import ../src/sse

# ============================================================
# Example 1: Create and format an event
# ============================================================
echo "=== Example 1: Create and format an event ==="
let evt = initSSEvent("hello world", "message", "123", 5000)
echo evt.format()
# Output:
# event: message
# data: hello world
# id: 123
# retry: 5000
# 

# ============================================================
# Example 2: Parse SSE data
# ============================================================
echo "=== Example 2: Parse SSE data ==="
let events = parse("data: hello\n\ndata: world\n\n")
echo "Number of events: ", events.len
for e in events:
  echo "Event data: ", e.data

# ============================================================
# Example 3: Format heartbeat/comment
# ============================================================
echo "=== Example 3: Format heartbeat ==="
echo formatHeartbeat()
echo formatHeartbeat("ping")

echo "Basic usage examples completed!"
