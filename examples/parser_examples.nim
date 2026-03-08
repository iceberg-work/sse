## SSEParser Examples
## ==================
## 
## This file demonstrates streaming parser usage.
## Run with: nim c -r examples/parser_examples.nim

import ../src/sse
import std/strutils

# ============================================================
# Example 1: Basic parser initialization
# ============================================================
echo "=== Example 1: Basic parser initialization ==="
var parser1 = initSSEParser()
let events1 = parser1.feed("data: hello\n\n")
echo "Events: ", events1.len
echo "Data: ", events1[0].data

# ============================================================
# Example 2: Parser with custom buffer size
# ============================================================
echo "\n=== Example 2: Parser with custom buffer size ==="
var parser2 = initSSEParser(maxBufferSize = 2 * 1024 * 1024)  # 2 MB
echo "Parser initialized with 2MB buffer"

# ============================================================
# Example 3: Event split across chunks
# ============================================================
echo "=== Example 3: Event split across chunks ==="
var parser3 = initSSEParser()
var events2 = parser3.feed("data: hel")
echo "After first chunk - Events: ", events2.len, ", Has pending: ", parser3.hasPending()

events2 = parser3.feed("lo\n\n")
echo "After second chunk - Events: ", events2.len, ", Data: ", events2[0].data

# ============================================================
# Example 4: Multiple events in chunks
# ============================================================
echo "=== Example 4: Multiple events in chunks ==="
var parser4 = initSSEParser()
var events3 = parser4.feed("data: first\n\ndata: sec")
echo "First chunk - Events: ", events3.len
echo "Event 1: ", events3[0].data

events3 = parser4.feed("ond\n\n")
echo "Second chunk - Events: ", events3.len
echo "Event 2: ", events3[0].data

# ============================================================
# Example 5: Parser lastEventId tracking
# ============================================================
echo "=== Example 5: Parser lastEventId tracking ==="
var parser5 = initSSEParser()
discard parser5.feed("data: test\nid: msg-123\n\n")
echo "Last event ID: ", parser5.lastEventId

discard parser5.feed("data: test2\nid: msg-456\n\n")
echo "Updated last event ID: ", parser5.lastEventId

# ============================================================
# Example 6: Reset parser
# ============================================================
echo "=== Example 6: Reset parser ==="
var parser6 = initSSEParser()
discard parser6.feed("data: partial")
echo "Has pending: ", parser6.hasPending()
parser6.reset()
echo "After reset - Has pending: ", parser6.hasPending()

# ============================================================
# Example 7: Buffer overflow protection
# ============================================================
echo "=== Example 7: Buffer overflow protection ==="
var parser7 = initSSEParser(maxBufferSize = 100)
try:
  discard parser7.feed("x".repeat(150))
  echo "ERROR: Should have raised SSEError"
except SSEError as e:
  echo "Correctly raised error: ", e.msg
  echo "After error - Has pending: ", parser7.hasPending()

# ============================================================
# Example 8: Empty feed
# ============================================================
echo "=== Example 8: Empty feed ==="
var parser8 = initSSEParser()
let events4 = parser8.feed("")
echo "Events from empty feed: ", events4.len
echo "Has pending: ", parser8.hasPending()

# ============================================================
# Example 9: Streaming simulation
# ============================================================
echo "=== Example 9: Streaming simulation ==="
var parser9 = initSSEParser()
let chunks = [
  "data: chunk1\n\n",
  "data: chunk2\n\n",
  "data: chunk3\n\n"
]

for i, chunk in chunks:
  let events5 = parser9.feed(chunk)
  echo "Chunk ", i+1, " - Events: ", events5.len, ", Data: ", events5[0].data

echo "Parser examples completed!"
