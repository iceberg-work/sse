## SSE Usage Patterns
## ==================
## 
## This file demonstrates common usage patterns for the SSE library.
## These patterns can be adapted to work with any web framework.
## 
## Run with: nim c -r examples/usage_patterns.nim

import ../src/sse
import std/[json, strutils]

# ============================================================
# Pattern 1: Simple Event Creation and Formatting
# ============================================================
echo "=== Pattern 1: Simple Event Creation ==="

# Basic event
let evt1 = initSSEvent("Hello, World!")
echo evt1.format()

# Event with type
let evt2 = initSSEvent("Update data", "update")
echo evt2.format()

# Event with all fields
let evt3 = initSSEvent("Message", "custom", "event-123", 5000)
echo evt3.format()

# ============================================================
# Pattern 2: Streaming Multiple Events
# ============================================================
echo "\n=== Pattern 2: Streaming Multiple Events ==="

let events = @[
  initSSEvent("First", "start"),
  initSSEvent("Second", "update"),
  initSSEvent("Third", "end")
]

for evt in events:
  echo evt.format()

# Or use the sequence formatter
echo format(events)

# ============================================================
# Pattern 3: Parsing Incoming SSE Data
# ============================================================
echo "\n=== Pattern 3: Parsing SSE Data ==="

let rawData = """
data: Hello
data: World

event: message
data: Test
id: 123

"""

let parsed = parse(rawData)
for i, evt in parsed:
  echo "Event ", i, ": data='", evt.data, "', event='", evt.event, "', id='", evt.id, "'"

# ============================================================
# Pattern 4: Streaming Parser (Chunked Data)
# ============================================================
echo "\n=== Pattern 4: Streaming Parser ==="

var parser = initSSEParser()

# Simulate receiving data in chunks
let chunks = [
  "data: Hel",
  "lo\n\n",
  "data: Wor",
  "ld\n\n"
]

for i, chunk in chunks:
  let events = parser.feed(chunk)
  echo "Chunk ", i+1, " - Events: ", events.len
  for evt in events:
    echo "  Data: ", evt.data

# ============================================================
# Pattern 5: Heartbeat/Keep-Alive
# ============================================================
echo "\n=== Pattern 5: Heartbeat ==="

# Simple heartbeat
echo formatHeartbeat()

# Heartbeat with comment
echo formatHeartbeat("ping")

# Heartbeat with special characters (automatically cleaned)
echo formatHeartbeat("ping\ninjected")

# ============================================================
# Pattern 6: Validation Before Processing
# ============================================================
echo "\n=== Pattern 6: Validation ==="

let testCases = [
  "data: valid\n\n",
  "data: test\nretry: abc\n\n",
  "data: test\nretry: -100\n\n",
  "unknown: field\n\n"
]

for i, testCase in testCases:
  let (valid, err) = validateSyntax(testCase)
  echo "Case ", i+1, ": ", if valid: "✓ Valid" else: "✗ Invalid - " & err

# ============================================================
# Pattern 7: JSON Serialization
# ============================================================
echo "\n=== Pattern 7: JSON Serialization ==="

let evt = initSSEvent("Test data", "message", "123", 5000)

# Convert to JSON
let jsonNode = evt.toJson()
echo "JSON: ", jsonNode.pretty

# Convert back from JSON
let restored = fromJson(jsonNode)
echo "Restored: data='", restored.data, "', event='", restored.event, "'"

# ============================================================
# Pattern 8: Large Data Handling
# ============================================================
echo "\n=== Pattern 8: Large Data Handling ==="

# Multiline data
let multiline = """Line 1
Line 2
Line 3"""

let evtLarge = initSSEvent(multiline)
echo "Multiline event:"
echo evtLarge.format()

# ============================================================
# Pattern 9: Event Comparison
# ============================================================
echo "\n=== Pattern 9: Event Comparison ==="

let a = initSSEvent("test", "msg", "1", 5000)
let b = initSSEvent("test", "msg", "1", 5000)
let c = initSSEvent("different", "msg", "1", 5000)

echo "a == b: ", a == b
echo "a == c: ", a == c

# ============================================================
# Pattern 10: Error Handling
# ============================================================
echo "\n=== Pattern 10: Error Handling ==="

# Parse with size limit
try:
  let largeInput = "x".repeat(15 * 1024 * 1024)  # 15 MB
  discard parse(largeInput)
except SSEError as e:
  echo "✓ Caught oversized input: ", e.msg

# Parser with buffer limit
var limitedParser = initSSEParser(maxBufferSize = 100)
try:
  discard limitedParser.feed("data: " & "x".repeat(200) & "\n\n")
except SSEError as e:
  echo "✓ Caught buffer overflow: ", e.msg

# ============================================================
# Pattern 11: Custom Event Types
# ============================================================
echo "\n=== Pattern 11: Custom Event Types ==="

# Define custom event types using SSEvent
type
  ChatMessage = object
    user: string
    content: string
    timestamp: int64

proc toSSEvent(msg: ChatMessage): SSEvent =
  let jsonNode = %*{
    "user": msg.user,
    "content": msg.content,
    "timestamp": msg.timestamp
  }
  initSSEvent($jsonNode, "chat_message")

proc fromSSEvent(evt: SSEvent): ChatMessage =
  let jsonNode = parseJson(evt.data)
  ChatMessage(
    user: jsonNode["user"].getStr(),
    content: jsonNode["content"].getStr(),
    timestamp: jsonNode["timestamp"].getInt()
  )

let msg = ChatMessage(user: "Alice", content: "Hello!", timestamp: 1234567890)
let customEvt = msg.toSSEvent()
echo "Custom event:"
echo customEvt.format()

let restoredMsg = fromSSEvent(customEvt)
echo "Restored: ", restoredMsg.user, " said: ", restoredMsg.content

# ============================================================
# Pattern 12: Batch Processing
# ============================================================
echo "\n=== Pattern 12: Batch Processing ==="

proc processBatch(dataItems: seq[string]): string =
  ## Process multiple items and return formatted SSE stream
  var events: seq[SSEvent] = @[]
  for i, item in dataItems:
    events.add(initSSEvent(item, "item", $(i+1)))
  format(events)

let items = @["Item 1", "Item 2", "Item 3", "Item 4"]
echo processBatch(items)

echo "\n=== All patterns demonstrated successfully! ==="
