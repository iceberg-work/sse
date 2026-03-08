## JSON Support Examples
## =====================
## 
## This file demonstrates SSEvent JSON serialization.
## Run with: nim c -r examples/json_examples.nim

import ../src/sse
import std/json

# ============================================================
# Example 1: Simple toJson
# ============================================================
echo "=== Example 1: Simple toJson ==="
let evt1 = initSSEvent("hello")
let j1 = evt1.toJson()
echo "JSON: ", $j1
echo "Data: ", j1["data"].getStr()

# ============================================================
# Example 2: Full toJson
# ============================================================
echo "\n=== Example 2: Full toJson ==="
let evt2 = initSSEvent("test", "message", "123", 5000)
let j2 = evt2.toJson()
echo "JSON: ", $j2
echo "Data: ", j2["data"].getStr()
echo "Event: ", j2["event"].getStr()
echo "ID: ", j2["id"].getStr()
echo "Retry: ", j2["retry"].getInt()

# ============================================================
# Example 3: fromJson with all fields
# ============================================================
echo "\n=== Example 3: fromJson with all fields ==="
let j3 = %*{"data": "test", "event": "msg", "id": "1", "retry": 3000}
let evt3 = fromJson(j3)
echo "Data: ", evt3.data
echo "Event: ", evt3.event
echo "ID: ", evt3.id
echo "Retry: ", evt3.retry

# ============================================================
# Example 4: fromJson missing fields
# ============================================================
echo "=== Example 4: fromJson missing fields ==="
let j4 = %*{"data": "test"}
let evt4 = fromJson(j4)
echo "Data: ", evt4.data
echo "Event: '", evt4.event, "'"
echo "ID: '", evt4.id, "'"
echo "Retry: ", evt4.retry

# ============================================================
# Example 5: fromJson empty object
# ============================================================
echo "=== Example 5: fromJson empty object ==="
let j5 = %*{}
let evt5 = fromJson(j5)
echo "Data: '", evt5.data, "'"
echo "Event: '", evt5.event, "'"
echo "ID: '", evt5.id, "'"
echo "Retry: ", evt5.retry

# ============================================================
# Example 6: fromJson type mismatch - retry as string
# ============================================================
echo "=== Example 6: Type mismatch - retry as string ==="
let j6 = %*{"data": "test", "retry": "5000"}
let evt6 = fromJson(j6)
echo "Data: ", evt6.data
echo "Retry (should be -1): ", evt6.retry

# ============================================================
# Example 7: fromJson type mismatch - retry as float
# ============================================================
echo "=== Example 7: Type mismatch - retry as float ==="
let j7 = %*{"data": "test", "retry": 5.5}
let evt7 = fromJson(j7)
echo "Data: ", evt7.data
echo "Retry (should be -1): ", evt7.retry

# ============================================================
# Example 8: fromJson type mismatch - data as int
# ============================================================
echo "=== Example 8: Type mismatch - data as int ==="
let j8 = %*{"data": 123, "event": "test"}
let evt8 = fromJson(j8)
echo "Data (should be empty): '", evt8.data, "'"
echo "Event: ", evt8.event

# ============================================================
# Example 9: fromJson type mismatch - data as array
# ============================================================
echo "=== Example 9: Type mismatch - data as array ==="
let j9 = %*{"data": [1, 2, 3]}
let evt9 = fromJson(j9)
echo "Data (should be empty): '", evt9.data, "'"

# ============================================================
# Example 10: Round-trip conversion
# ============================================================
echo "\n=== Example 10: Round-trip conversion ==="
let original = initSSEvent("test data", "message", "123", 5000)
let jsonNode = original.toJson()
let restored = fromJson(jsonNode)
echo "Original: ", $original
echo "Restored: ", $restored
echo "Equal: ", original == restored

# ============================================================
# Example 11: JSON with null retry
# ============================================================
echo "\n=== Example 11: JSON with null retry ==="
let j11 = %*{"data": "test", "retry": newJNull()}
let evt11 = fromJson(j11)
echo "Data: ", evt11.data
echo "Retry (should be -1): ", evt11.retry

# ============================================================
# Example 12: Pretty print JSON
# ============================================================
echo "\n=== Example 12: Pretty print JSON ==="
let evt12 = initSSEvent("hello world", "message", "123", 5000)
let j12 = evt12.toJson()
echo "Pretty JSON:"
echo pretty(j12)

echo "JSON examples completed!"
