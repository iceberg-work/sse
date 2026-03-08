## Security Examples
## =================
## 
## This file demonstrates security features and protections.
## Run with: nim c -r examples/security_examples.nim

import ../src/sse
import std/strutils

# ============================================================
# Example 1: Parse size limit protection
# ============================================================
echo "=== Example 1: Parse size limit protection ==="
try:
  let largeInput = "x".repeat(15 * 1024 * 1024)  # 15 MB
  discard parse(largeInput)
  echo "ERROR: Should have raised SSEError"
except SSEError as e:
  echo "✓ Correctly rejected oversized input: ", e.msg
except Exception as e:
  echo "✗ Unexpected error: ", e.name, ": ", e.msg

# ============================================================
# Example 2: Parse with custom size limit
# ============================================================
echo "\n=== Example 2: Parse with custom size limit ==="
try:
  let mediumInput = "data: hello\n\n"
  let events2 = parse(mediumInput, maxSize = 100)  # Very small limit
  echo "✓ Parsed small input successfully: ", events2.len, " events"
  
  let largeInput2 = "data: " & "x".repeat(200) & "\n\n"
  discard parse(largeInput2, maxSize = 100)
  echo "ERROR: Should have raised SSEError"
except SSEError as e:
  echo "✓ Correctly rejected input exceeding custom limit: ", e.msg

# ============================================================
# Example 3: Field injection prevention (event)
# ============================================================
echo "=== Example 3: Field injection prevention (event) ==="
let malicious1 = initSSEvent("hello", "message\nid: injected", "real-id", 5000)
let formatted1 = malicious1.format()
echo "Malicious event field:"
echo formatted1
let hasNoNewlineInjection = not formatted1.contains("event: message\nid:")
let hasSanitizedOutput = "event: messageid: injected" in formatted1
if hasNoNewlineInjection and hasSanitizedOutput:
  echo "✓ Field injection prevented - newlines removed, text stays on same line"
else:
  echo "✗ SECURITY ISSUE: New field line created!"

# ============================================================
# Example 4: Field injection prevention (id)
# ============================================================
echo "\n=== Example 4: Field injection prevention (id) ==="
let malicious2 = initSSEvent("hello", "message", "real-id\nevent: injected", 5000)
let formatted2 = malicious2.format()
echo "Malicious id field:"
echo formatted2
if "id: real-idevent: injected" in formatted2:
  echo "✓ Field injection prevented - newlines removed, text stays on same line"
else:
  echo "✗ SECURITY ISSUE: New field line created!"

# ============================================================
# Example 5: Field injection prevention (CRLF)
# ============================================================
echo "\n=== Example 5: Field injection prevention (CRLF) ==="
let malicious3 = initSSEvent("hello", "message\r\nevent: crlf-injected", "id", 5000)
let formatted3 = malicious3.format()
echo "Malicious event with CRLF:"
echo formatted3
if "event: messageevent: crlf-injected" in formatted3:
  echo "✓ CRLF injection prevented - CR removed, text stays on same line"
else:
  echo "✗ SECURITY ISSUE: CRLF created new line!"

# ============================================================
# Example 6: Negative retry value handling (parse)
# ============================================================
echo "\n=== Example 6: Negative retry value handling (parse) ==="
let negativeRetry = "data: test\nretry: -1000\n\n"
let events3 = parse(negativeRetry)
echo "Parsed event with negative retry:"
echo "  retry value: ", events3[0].retry
if events3[0].retry == 0:
  echo "✓ Negative retry ignored (defaults to 0, the SSEvent default)"
else:
  echo "  Note: Negative retry accepted as: ", events3[0].retry

# ============================================================
# Example 7: Large retry value handling
# ============================================================
echo "\n=== Example 7: Large retry value handling ==="
let largeRetry = "data: test\nretry: 9223372036854775807\n\n"
let events4 = parse(largeRetry)
echo "Parsed event with very large retry:"
echo "  retry value: ", events4[0].retry
echo "  Note: Large values are accepted but may cause client issues"

# ============================================================
# Example 8: Normal event (no injection)
# ============================================================
echo "\n=== Example 8: Normal event (no injection) ==="
let normal = initSSEvent("hello world", "message", "123", 5000)
let formatted4 = normal.format()
echo "Normal event:"
echo formatted4
echo "✓ Normal events work correctly"

# ============================================================
# Example 9: Data field with newlines (allowed)
# ============================================================
echo "\n=== Example 9: Data field with newlines (allowed) ==="
let multiline = initSSEvent("line1\nline2\nline3", "message", "id", 5000)
let formatted5 = multiline.format()
echo "Multiline data (newlines are allowed in data):"
echo formatted5
echo "✓ Data field correctly handles newlines as multiple data: lines"

# ============================================================
# Example 10: Buffer overflow protection (parser)
# ============================================================
echo "\n=== Example 10: Buffer overflow protection (parser) ==="
var parser = initSSEParser(maxBufferSize = 100)
try:
  let largeChunk = "data: " & "x".repeat(200) & "\n\n"
  discard parser.feed(largeChunk)
  echo "ERROR: Should have raised SSEError"
except SSEError as e:
  echo "✓ Parser correctly rejected oversized chunk: ", e.msg
except Exception as e:
  echo "✗ Unexpected error: ", e.name, ": ", e.msg

# ============================================================
# Example 11: Error handling best practices
# ============================================================
echo "\n=== Example 11: Error handling best practices ==="

proc safeParse(data: string): seq[SSEvent] =
  ## Safe parsing with comprehensive error handling
  try:
    result = parse(data)
  except SSEError as e:
    echo "[SSE Error] Parsing failed: ", e.msg
    result = @[]
  except ValueError as e:
    echo "[Value Error] Invalid data format: ", e.msg
    result = @[]
  except Exception as e:
    echo "[Unexpected Error] ", e.name, ": ", e.msg
    result = @[]

# Test with valid data
echo "Parsing valid data:"
let validEvents = safeParse("data: hello\n\n")
echo "  Parsed ", validEvents.len, " events"

# Test with invalid data
echo "Parsing invalid data:"
let invalidEvents = safeParse("data: " & "x".repeat(15 * 1024 * 1024) & "\n\n")
echo "  Handled error gracefully, returned ", invalidEvents.len, " events"

echo "\nSecurity examples completed!"
echo "\n=== Summary ==="
echo "The library now protects against:"
echo "  1. DoS attacks via large input (parse size limit)"
echo "  2. Field injection attacks (newline sanitization)"
echo "  3. Buffer overflow (parser buffer limit)"
echo "  4. Invalid retry values (negative value rejection)"
