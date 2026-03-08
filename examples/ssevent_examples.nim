## SSEvent Examples
## ================
## 
## This file demonstrates SSEvent creation, formatting, and parsing.
## Run with: nim c -r examples/ssevent_examples.nim

import ../src/sse

# ============================================================
# Example 1: Basic initialization
# ============================================================
echo "=== Example 1: Basic initialization ==="
let evt1 = initSSEvent("hello")
echo "Data: ", evt1.data
echo "Event: ", evt1.event
echo "ID: ", evt1.id
echo "Retry: ", evt1.retry

# ============================================================
# Example 2: Full initialization
# ============================================================
echo "\n=== Example 2: Full initialization ==="
let evt2 = initSSEvent("data", "message", "123", 5000)
echo "Data: ", evt2.data
echo "Event: ", evt2.event
echo "ID: ", evt2.id
echo "Retry: ", evt2.retry

# ============================================================
# Example 3: Format simple data
# ============================================================
echo "\n=== Example 3: Format simple data ==="
let evt3 = initSSEvent("hello")
echo evt3.format()

# ============================================================
# Example 4: Format with event type
# ============================================================
echo "=== Example 4: Format with event type ==="
let evt4 = initSSEvent("hello", "message")
echo evt4.format()

# ============================================================
# Example 5: Format multiline data
# ============================================================
echo "=== Example 5: Format multiline data ==="
let evt5 = initSSEvent("line1\nline2")
echo evt5.format()

# ============================================================
# Example 6: Format with ID
# ============================================================
echo "=== Example 6: Format with ID ==="
let evt6 = initSSEvent("test", "", "abc")
echo evt6.format()

# ============================================================
# Example 7: Format with retry
# ============================================================
echo "=== Example 7: Format with retry ==="
let evt7 = initSSEvent("test", "event", "id", 5000)
echo evt7.format()

# ============================================================
# Example 8: CRLF normalization
# ============================================================
echo "=== Example 8: CRLF normalization ==="
let evt8 = initSSEvent("line1\r\nline2")
echo evt8.format()

# ============================================================
# Example 9: Parse simple event
# ============================================================
echo "=== Example 9: Parse simple event ==="
let events1 = parse("data: hello\n\n")
echo "Events: ", events1.len
echo "Data: ", events1[0].data

# ============================================================
# Example 10: Parse with event type
# ============================================================
echo "=== Example 10: Parse with event type ==="
let events2 = parse("event: message\ndata: hello\n\n")
echo "Event: ", events2[0].event
echo "Data: ", events2[0].data

# ============================================================
# Example 11: Parse multiline data
# ============================================================
echo "=== Example 11: Parse multiline data ==="
let events3 = parse("data: line1\ndata: line2\n\n")
echo "Data: ", events3[0].data

# ============================================================
# Example 12: Parse full event
# ============================================================
echo "=== Example 12: Parse full event ==="
let raw = "event: custom\ndata: test data\nid: msg-001\nretry: 3000\n\n"
let events4 = parse(raw)
echo "Event: ", events4[0].event
echo "Data: ", events4[0].data
echo "ID: ", events4[0].id
echo "Retry: ", events4[0].retry

# ============================================================
# Example 13: Format multiple events
# ============================================================
echo "=== Example 13: Format multiple events ==="
let events5 = @[
  initSSEvent("first"),
  initSSEvent("second", "custom")
]
echo format(events5)

# ============================================================
# Example 14: String representation
# ============================================================
echo "=== Example 14: String representation ==="
let evt9 = initSSEvent("hello", "message", "123", 5000)
echo $evt9

# ============================================================
# Example 15: Compare events
# ============================================================
echo "=== Example 15: Compare events ==="
let a = initSSEvent("hello", "msg", "1", 5000)
let b = initSSEvent("hello", "msg", "1", 5000)
let c = initSSEvent("world", "msg", "1", 5000)
echo "a == b: ", a == b
echo "a == c: ", a == c

echo "SSEvent examples completed!"
