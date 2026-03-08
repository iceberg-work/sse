## Validation Examples
## ===================
## 
## This file demonstrates SSE validation functions.
## Run with: nim c -r examples/validation_examples.nim

import ../src/sse

# ============================================================
# Example 1: Validate valid syntax
# ============================================================
echo "=== Example 1: Validate valid syntax ==="
let (valid1, err1) = validateSyntax("data: hello\n\n")
echo "Valid: ", valid1, ", Error: '", err1, "'"

# ============================================================
# Example 2: Validate with all fields
# ============================================================
echo "\n=== Example 2: Validate with all fields ==="
let (valid2, err2) = validateSyntax("event: msg\ndata: hello\nid: 1\nretry: 5000\n\n")
echo "Valid: ", valid2, ", Error: '", err2, "'"

# ============================================================
# Example 3: Validate with comment
# ============================================================
echo "=== Example 3: Validate with comment ==="
let (valid3, err3) = validateSyntax(": comment\ndata: hello\n\n")
echo "Valid: ", valid3, ", Error: '", err3, "'"

# ============================================================
# Example 4: Validate invalid retry value
# ============================================================
echo "=== Example 4: Validate invalid retry value ==="
let (valid4, err4) = validateSyntax("data: test\nretry: abc\n\n")
echo "Valid: ", valid4, ", Error: '", err4, "'"

# ============================================================
# Example 5: Validate unknown field
# ============================================================
echo "=== Example 5: Validate unknown field ==="
let (valid5, err5) = validateSyntax("unknown: value\ndata: test\n\n")
echo "Valid: ", valid5, ", Error: '", err5, "'"

# ============================================================
# Example 6: ValidateStrict with valid event
# ============================================================
echo "\n=== Example 6: ValidateStrict with valid event ==="
let (valid6, err6) = validateStrict("data: hello\n\n")
echo "Valid: ", valid6, ", Error: '", err6, "'"

# ============================================================
# Example 7: ValidateStrict with invalid retry
# ============================================================
echo "=== Example 7: ValidateStrict with invalid retry ==="
let (valid7, err7) = validateStrict("data: hello\nretry: abc\n\n")
echo "Valid: ", valid7, ", Error: '", err7, "'"

# ============================================================
# Example 8: ValidateStrict with all fields
# ============================================================
echo "=== Example 8: ValidateStrict with all fields ==="
let (valid8, err8) = validateStrict("event: msg\ndata: hello\nid: 1\nretry: 5000\n\n")
echo "Valid: ", valid8, ", Error: '", err8, "'"

# ============================================================
# Example 9: Validate alias
# ============================================================
echo "\n=== Example 9: Validate alias ==="
let (valid9, err9) = validate("data: test\n\n")
echo "Valid: ", valid9, ", Error: '", err9, "'"
echo "validate is alias for validateSyntax: ", validate("data: test\n\n") == validateSyntax("data: test\n\n")

# ============================================================
# Example 10: Real-world validation scenario
# ============================================================
echo "\n=== Example 10: Real-world validation scenario ==="
let sseMessages = [
  "data: hello\n\n",                          # Valid
  "event: update\ndata: test\n\n",           # Valid
  "data: test\nretry: invalid\n\n",          # Invalid retry
  "custom: field\ndata: test\n\n",           # Unknown field
  ": comment only\n\n",                       # Valid (comment)
]

for i, msg in sseMessages:
  let (valid, err) = validateSyntax(msg)
  echo "Message ", i+1, ": ", if valid: "✓ Valid" else: "✗ Invalid - " & err

echo "Validation examples completed!"
