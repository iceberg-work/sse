## Web Framework Integration Guide
## ================================
## 
## Framework-agnostic SSE integration patterns.
## The concepts here apply to ANY web framework.
## 
## Run with: nim c -r examples/web_framework_integration.nim

import ../src/sse
import std/[json, strutils]

# ============================================================
# Section 1: Required HTTP Response Headers
# ============================================================
# 
# SSE requires these headers (framework-agnostic):
# 
#   Content-Type: text/event-stream    # Required
#   Cache-Control: no-cache            # Required
#   Connection: keep-alive             # Recommended
# 
# Optional but useful:
#   X-Accel-Buffering: no              # Disable nginx buffering
#   Access-Control-Allow-Origin: *     # CORS for browser clients

echo "=== Section 1: Required HTTP Headers ==="
echo "Content-Type: text/event-stream"
echo "Cache-Control: no-cache"
echo "Connection: keep-alive"
echo ""

# ============================================================
# Section 2: Core Integration Pattern
# ============================================================
# 
# The integration is always the same 3 steps:
# 
#   1. Set headers (see Section 1)
#   2. Create event: initSSEvent(data, event, id, retry)
#   3. Send: your_framework_send(evt.format())

echo "=== Section 2: Core Integration Pattern ==="

# Basic event
let evt1 = initSSEvent("Hello World")
echo "Basic event:"
echo evt1.format()

# Event with type
let evt2 = initSSEvent("Hello World", "message")
echo "Event with type:"
echo evt2.format()

# Full event
let evt3 = initSSEvent("Hello World", "message", "123", 5000)
echo "Full event:"
echo evt3.format()

# ============================================================
# Section 3: Streaming Parser (Client-side)
# ============================================================
# 
# For consuming SSE streams (e.g., LLM APIs):
# 
#   var parser = initSSEParser()
#   for chunk in received_data:
#     let events = parser.feed(chunk)
#     for evt in events:
#       handle_event(evt)
# 
# The parser handles:
#   - Chunked data (events split across chunks)
#   - Last-Event-ID tracking (for reconnection)
#   - Buffer overflow protection

echo "=== Section 3: Streaming Parser ==="

var parser = initSSEParser()

# Simulate chunked data
discard parser.feed("data: Hel")
echo "After chunk 1: ", parser.hasPending(), " pending"

let chunk2 = parser.feed("lo\n\n")
echo "After chunk 2: ", chunk2.len, " event(s)"
echo "Data: ", chunk2[0].data
echo "LastEventId: ", parser.lastEventId

# Parser with ID tracking
var parserWithId = initSSEParser()
discard parserWithId.feed("data: test\nid: msg-456\n\n")
echo "Tracked LastEventId: ", parserWithId.lastEventId

# ============================================================
# Section 4: Reconnection with Last-Event-ID
# ============================================================
# 
# Client sends: Last-Event-ID: <id>
# Server should resume from that event.
# 
# Pseudocode (framework-specific):
#   let lastId = get_header("Last-Event-ID")
#   let startFrom = if lastId.len > 0: parseInt(lastId) + 1 else: 0

echo "=== Section 4: Reconnection (Last-Event-ID) ==="

# Simulate server handling Last-Event-ID
let lastId = "msg-005"
let startFrom = if lastId.len > 0: 6 else: 0
echo "Client sent Last-Event-ID: ", lastId
echo "Server resumes from: ", startFrom

# Send events with ID for reconnection support
for i in startFrom..startFrom+2:
  let idStr = "msg-" & align($i, 3, '0')
  let evt = initSSEvent("Message " & $i, "update", idStr)
  echo evt.format()

# ============================================================
# Section 5: Heartbeat/Keep-Alive
# ============================================================
# 
# Send periodic heartbeats to detect disconnections:
# 
#   # Every N seconds:
#   send_to_client(formatHeartbeat("ping"))
# 
# Clients ignore comment lines, but connection stays alive.

echo "=== Section 5: Heartbeat/Keep-Alive ==="

echo "Simple heartbeat:"
echo formatHeartbeat()

echo "Heartbeat with comment:"
echo formatHeartbeat("ping")

echo "Heartbeat (newline sanitized):"
echo formatHeartbeat("ping\ninjected")

# ============================================================
# Section 6: Error Handling
# ============================================================
# 
# Common errors to handle:
# 
#   try:
#     send_to_client(evt.format())
#   except IOError, OSError:
#     # Client disconnected
#     cleanup()
# 
#   try:
#     let events = parser.feed(large_chunk)
#   except SSEError:
#     # Buffer overflow - malicious or misconfigured client
#     disconnect()

echo "=== Section 6: Error Handling ==="

# Buffer overflow protection
var limitedParser = initSSEParser(maxBufferSize = 100)
try:
  discard limitedParser.feed("x".repeat(150))
  echo "ERROR: Should have raised SSEError"
except SSEError as e:
  echo "Caught buffer overflow: ", e.msg

# Parse size limit
try:
  discard parse("x".repeat(15 * 1024 * 1024))
  echo "ERROR: Should have raised SSEError"
except SSEError as e:
  echo "Caught parse size limit: ", e.msg

# ============================================================
# Section 7: Security Checklist
# ============================================================
# 
# ✓ Set maxBufferSize to prevent memory exhaustion
# ✓ Set maxSize in parse() to limit input size
# ✓ The library sanitizes newlines in event/id fields (injection safe)
# ✓ Validate retry values (negative values are ignored)

echo "=== Section 7: Security Checklist ==="

# Field injection prevention
let malicious = initSSEvent("hello", "message\nevent: injected", "real-id")
let safe = malicious.format()
if "event: message\nevent:" in safe:
  echo "SECURITY ISSUE: Field injection possible!"
else:
  echo "OK: Newlines sanitized in event field"

# Validation
let (valid, err) = validateSyntax("data: test\nretry: abc\n\n")
if not valid:
  echo "Validation caught: ", err

# ============================================================
# Section 8: Common Patterns
# ============================================================

echo "=== Section 8: Common Patterns ==="

# Pattern: Multiline data
echo "--- Multiline data ---"
let multiline = initSSEvent("line1\nline2\nline3")
echo multiline.format()

# Pattern: JSON payload
echo "--- JSON payload ---"
let payload = %*{"user": "alice", "msg": "hello"}
let jsonEvt = initSSEvent($payload, "chat")
echo jsonEvt.format()

# Pattern: Multiple events
echo "--- Multiple events ---"
let events = @[
  initSSEvent("First", "start"),
  initSSEvent("Second", "update"),
  initSSEvent("Third", "end")
]
echo format(events)

# Pattern: Parse and process
echo "--- Parse and process ---"
let rawData = "data: hello\n\ndata: world\n\n"
let parsed = parse(rawData)
echo "Parsed ", parsed.len, " events"
for i, evt in parsed:
  echo "  Event ", i, ": ", evt.data

echo ""
echo "=========================================="
echo "Web Framework Integration Guide completed"
echo "=========================================="
