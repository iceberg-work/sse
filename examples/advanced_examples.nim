## Advanced Examples
## =================
## 
## This file demonstrates advanced SSE usage patterns.
## Run with: nim c -r examples/advanced_examples.nim

import ../src/sse
import std/strutils

# ============================================================
# Example 1: Large data handling
# ============================================================
echo "=== Example 1: Large data handling ==="
let largeData = "x".repeat(1024 * 1024)  # 1MB
let evt1 = initSSEvent(largeData)
let fmt = evt1.format()
echo "Formatted size: ", fmt.len, " bytes"

let parsed1 = parse(fmt)
echo "Parsed events: ", parsed1.len
echo "Data size: ", parsed1[0].data.len, " bytes"

# ============================================================
# Example 2: Large multiline data
# ============================================================
echo "\n=== Example 2: Large multiline data ==="
var lines: seq[string] = @[]
for i in 0..<1000:
  lines.add("line " & $i)
let multiData = lines.join("\n")
let evt2 = initSSEvent(multiData)
let parsed2 = parse(evt2.format())
echo "Lines: ", parsed2[0].data.split("\n").len

# ============================================================
# Example 3: Many small events
# ============================================================
echo "\n=== Example 3: Many small events ==="
var raw = ""
for i in 0..<100:
  raw.add("data: event" & $i & "\n\n")
let events3 = parse(raw)
echo "Total events: ", events3.len
echo "First event: ", events3[0].data
echo "Last event: ", events3[99].data

# ============================================================
# Example 4: Round-trip format then parse
# ============================================================
echo "\n=== Example 4: Round-trip format then parse ==="
let original = initSSEvent("test data", "message", "123", 5000)
let formatted = original.format()
echo "Formatted:"
echo formatted

let parsed3 = parse(formatted)
echo "Parsed back:"
echo "  Data: ", parsed3[0].data
echo "  Event: ", parsed3[0].event
echo "  ID: ", parsed3[0].id
echo "  Retry: ", parsed3[0].retry
echo "  Match: ", parsed3[0] == original

# ============================================================
# Example 5: Streaming parser with large chunk
# ============================================================
echo "\n=== Example 5: Streaming parser with large chunk ==="
var parser1 = initSSEParser(maxBufferSize = 2 * 1024 * 1024)
let largeData2 = "x".repeat(1024 * 1024)
let events4 = parser1.feed("data: " & largeData2 & "\n\n")
echo "Events: ", events4.len
echo "Data size: ", events4[0].data.len, " bytes"

# ============================================================
# Example 6: Comment handling
# ============================================================
echo "\n=== Example 6: Comment handling ==="
let withComments = """
: This is a comment
data: hello
: Another comment
data: world

"""
let events5 = parse(withComments)
echo "Events parsed (comments ignored): ", events5.len
echo "Data: ", events5[0].data

# ============================================================
# Example 7: Line ending normalization
# ============================================================
echo "\n=== Example 7: Line ending normalization ==="
let windowsStyle = "data: hello\r\n\r\n"
let unixStyle = "data: hello\n\n"
let oldMacStyle = "data: hello\r\r"

let e1 = parse(windowsStyle)
let e2 = parse(unixStyle)
let e3 = parse(oldMacStyle)

echo "Windows CRLF: ", e1[0].data
echo "Unix LF: ", e2[0].data
echo "Old Mac CR: ", e3[0].data
echo "All equal: ", e1[0].data == e2[0].data and e2[0].data == e3[0].data

# ============================================================
# Example 8: Colon handling variations
# ============================================================
echo "\n=== Example 8: Colon handling variations ==="
let noSpace = "data:value\n\n"
let oneSpace = "data: value\n\n"
let multiSpace = "data:  value\n\n"

let e4 = parse(noSpace)
let e5 = parse(oneSpace)
let e6 = parse(multiSpace)

echo "No space: '", e4[0].data, "'"
echo "One space: '", e5[0].data, "'"
echo "Multi space: '", e6[0].data, "'"

# ============================================================
# Example 9: Empty and edge cases
# ============================================================
echo "\n=== Example 9: Empty and edge cases ==="
let emptyEvents = parse("")
echo "Empty input events: ", emptyEvents.len

let justComments = parse(": comment1\n: comment2\n\n")
echo "Just comments events: ", justComments.len

let emptyData = initSSEvent("")
echo "Empty data format: '", emptyData.format(), "'"

# ============================================================
# Example 10: Retry value edge cases
# ============================================================
echo "\n=== Example 10: Retry value edge cases ==="
let retryZero = initSSEvent("test", "", "", 0)
echo "Retry 0 included: ", "retry: 0" in retryZero.format()

let retryNegative = initSSEvent("test", "", "", -1)
echo "Retry -1 included: ", "retry:" in retryNegative.format()

let retry5000 = initSSEvent("test", "", "", 5000)
echo "Retry 5000 included: ", "retry: 5000" in retry5000.format()

# ============================================================
# Example 11: Parser buffer management
# ============================================================
echo "\n=== Example 11: Parser buffer management ==="
var parser2 = initSSEParser()

# Feed partial data
let partial1 = parser2.feed("data: hel")
echo "After 'hel' - Events: ", partial1.len, ", Pending: ", parser2.hasPending()

# Feed more
let partial2 = parser2.feed("lo")
echo "After 'lo' - Events: ", partial2.len, ", Pending: ", parser2.hasPending()

# Complete the event
let complete = parser2.feed("\n\n")
echo "After '\\n\\n' - Events: ", complete.len, ", Data: ", complete[0].data
echo "Pending: ", parser2.hasPending()

# ============================================================
# Example 12: Multiple events in single parse
# ============================================================
echo "\n=== Example 12: Multiple events in single parse ==="
let multiEventRaw = """
data: event1

event: update
data: event2
id: 2

data: event3
id: 3
retry: 1000

"""
let events6 = parse(multiEventRaw)
echo "Total events: ", events6.len
for i, evt in events6:
  echo "  Event ", i+1, ": data='", evt.data, "', event='", evt.event, "', id='", evt.id, "', retry=", evt.retry

echo "Advanced examples completed!"
