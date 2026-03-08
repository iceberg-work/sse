# Security Guide for SSE Library

This document provides comprehensive security information for using the SSE (Server-Sent Events) library safely in production environments.

## Table of Contents

- [Security Features](#security-features)
- [Security Limitations](#security-limitations)
- [Best Practices](#best-practices)
- [Known Threats](#known-threats)
- [Error Handling](#error-handling) 
- [Production Checklist](#production-checklist)

---

## Security Features

### 1. DoS (Denial of Service) Protection

The library includes multiple layers of DoS protection:

```nim
# Default limits
DefaultMaxParseSize = 10 MB    # Maximum input size for parse()
DefaultMaxBufferSize = 1 MB    # Maximum buffer size for SSEParser
```

**Protection mechanism:**
- `parse()` rejects input larger than `maxSize` (default: 10MB)
- `SSEParser.feed()` rejects chunks that exceed `maxBufferSize` (default: 1MB)
- Both raise `SSEError` when limits are exceeded

**Customization:**
```nim
# Custom parse limit
let events = parse(largeData, maxSize = 50 * 1024 * 1024)  # 50 MB

# Custom buffer size
var parser = initSSEParser(maxBufferSize = 5 * 1024 * 1024)  # 5 MB
```

### 2. Field Injection Prevention

The library sanitizes newlines in `event` and `id` fields to prevent field injection attacks:

**Handled characters:**
- `\r` (Carriage Return)
- `\n` (Line Feed)
- `\u2028` (LINE SEPARATOR)
- `\u2029` (PARAGRAPH SEPARATOR)

**Example:**
```nim
let malicious = initSSEvent("hello", "message\nid: injected", "real-id")
echo malicious.format()
# Output: event: messageid: injected
#         data: hello
#         id: real-id
# 
# Note: "id: injected" is NOT a new field - it's concatenated on the same line
```

### 3. Invalid Retry Value Handling

Negative `retry` values are silently ignored during parsing:

```nim
let events = parse("data: test\nretry: -1000\n\n")
echo events[0].retry  # 0 (default, negative value ignored)
```

### 4. Buffer Overflow Protection

The streaming parser maintains strict buffer limits:

```nim
var parser = initSSEParser(maxBufferSize = 100)
try:
  discard parser.feed("x".repeat(150))
except SSEError as e:
  echo "Buffer overflow prevented: ", e.msg
```

---

## Security Limitations

### ⚠️ 1. Data Field Not Sanitized

**The `data` field preserves all characters including newlines.** This is by design to comply with the SSE specification, but requires caution:

```nim
# This is valid SSE - data can contain newlines
let evt = initSSEvent("line1\nline2", "message")
echo evt.format()
# Output:
# event: message
# data: line1
# data: line2
# 

# ⚠️ But be careful with JSON in data fields
let jsonEvt = initSSEvent("""{"key": "value: with colon"}""", "message")
echo jsonEvt.format()
# Output:
# event: message
# data: {"key": "value: with colon"}
# 
```

**Risk**: If you're embedding JSON or other structured data, ensure proper escaping when consuming on the client side.

### ⚠️ 2. JSON Serialization Outputs Raw Values

The `toJson()` function does NOT sanitize field values:

```nim
let evt = initSSEvent("hello\nworld", "message\ninjected")
let json = evt.toJson()
echo json  # {"data": "hello\nworld", "event": "message\ninjected"}
```

**⚠️ DANGER**: Do NOT embed this JSON directly in HTML or JavaScript:

```nim
# ❌ UNSAFE - XSS vulnerability!
let malicious = initSSEvent("<script>alert('XSS')</script>", "message")
let json = malicious.toJson()
echo "<div>" & $json & "</div>"  # XSS attack succeeds!
```

**Safe usage:**
```nim
# ✅ Use proper HTML escaping
import htmlgen
let safe = escapeHtml($json)
```

### ⚠️ 3. Memory Exhaustion in Client Code

Using `response.body` loads the entire response into memory:

```nim
# ❌ UNSAFE for production
var client = newHttpClient()
let response = client.get(url)
for line in response.body.splitLines():  # Loads ALL data into memory!
  # ...

# ✅ SAFE - use streaming
var client = newHttpClient()
let stream = client.getStream(url)
var buffer = ""
while true:
  let chunk = stream.readChunk(1024)
  if chunk.len == 0: break
  buffer.add(chunk)
  let events = parser.feed(buffer)
  # ...
  buffer = ""
```

### ⚠️ 4. Data Field Can Contain Colons

The SSE specification allows colons in data fields:

```nim
let evt = initSSEvent("key: value", "message")
echo evt.format()
# Output:
# event: message
# data: key: value
# 
```

This is valid SSE, but parsers that split on `:` without proper handling may misinterpret the data.

---

## Best Practices

### 1. Input Validation

Always validate input before creating events:

```nim
proc createSafeEvent(data: string, eventType = ""): SSEvent =
  # Validate data size
  if data.len > 1024 * 1024:  # 1 MB limit
    raise newException(ValueError, "Data too large")
  
  # Additional validation as needed
  if data.contains("\u0000"):  # Null bytes
    raise newException(ValueError, "Invalid character")
  
  result = initSSEvent(data, eventType)
```

### 2. Output Encoding

When embedding SSE data in other contexts:

```nim
# For HTML embedding
import htmlgen
let safeHtml = escapeHtml($evt.toJson())

# For JavaScript embedding
import json
let safeJs = escapeJs($evt.data)
```

### 3. Stream Consumption

Always use streaming for production SSE clients:

```nim
proc consumeSSE(url: string) =
  var client = newHttpClient()
  var parser = initSSEParser()
  
  try:
    let stream = client.getStream(url)
    var buffer = ""
    
    while true:
      let chunk = stream.readChunk(4096)  # 4KB chunks
      if chunk.len == 0: break
      
      buffer.add(chunk)
      let events = parser.feed(buffer)
      
      for evt in events:
        processEvent(evt)
      
      buffer = ""  # Clear processed data
  
  except IOError, OSError as e:
    echo "Connection error: ", e.msg
  except SSEError as e:
    echo "Parse error: ", e.msg
  finally:
    client.close()
```

### 4. Error Handling

Use comprehensive error handling:

```nim
proc safeParse(data: string): seq[SSEvent] =
  try:
    result = parse(data)
  except SSEError as e:
    echo "[SSE Error] ", e.msg
    result = @[]
  except ValueError as e:
    echo "[Value Error] ", e.msg
    result = @[]
  except Exception as e:
    echo "[Unexpected Error] ", e.name, ": ", e.msg
    result = @[]
```

### 5. Resource Cleanup

Always clean up resources:

```nim
var parser = initSSEParser()
try:
  # Use parser
  discard parser.feed(data)
finally:
  parser.reset()  # Clear buffer
```

---

## Known Threats

### 1. Field Injection Attack

**Threat**: Attacker tries to inject new SSE fields through event/id values.

**Example:**
```nim
let malicious = initSSEvent("hello", "message\nevent: injected\ndata: hacked")
```

**Mitigation**: ✅ Library sanitizes newlines in event/id fields.

### 2. DoS via Large Input

**Threat**: Attacker sends extremely large SSE data.

**Example:**
```nim
let attack = "data: " & "x".repeat(100 * 1024 * 1024) & "\n\n"
```

**Mitigation**: ✅ Library rejects input > 10MB by default.

### 3. Memory Exhaustion

**Threat**: Client loads entire stream into memory.

**Example:**
```nim
let response = client.get(url)  # Loads ALL data
```

**Mitigation**: ⚠️ Developer must use streaming APIs.

### 4. XSS via JSON

**Threat**: Embedding unsanitized JSON in HTML.

**Example:**
```nim
let malicious = initSSEvent("<script>alert('XSS')</script>")
let json = malicious.toJson()
echo "<div>" & $json & "</div>"  # XSS!
```

**Mitigation**: ⚠️ Developer must escape output.

### 5. Unicode Newline Injection

**Threat**: Using Unicode newline characters to bypass sanitization.

**Example:**
```nim
let malicious = initSSEvent("hello", "message\u2028event: injected")
```

**Mitigation**: ✅ Library handles \u2028 and \u2029.

---

## Error Handling

### SSEError

Raised for SSE-specific errors:

```nim
try:
  discard parse(largeData)
except SSEError as e:
  echo "SSE error: ", e.msg
  # Handle: input too large, buffer overflow, etc.
```

### Common Errors

| Error | Cause | Mitigation |
|-------|-------|------------|
| `SSEError: Input size exceeds maximum` | Input > maxSize | Increase maxSize or reject input |
| `SSEError: Buffer size exceeded` | Chunk > maxBufferSize | Increase buffer or split chunks |
| `ValueError: Invalid integer` | Malformed retry value | Validate input before parsing |

---

## Production Checklist

Before deploying to production, verify:

### Server-Side

- [ ] Set appropriate `maxSize` for `parse()` based on expected event sizes
- [ ] Set appropriate `maxBufferSize` for `SSEParser`
- [ ] Implement rate limiting to prevent abuse
- [ ] Use HTTPS for encrypted transmission
- [ ] Set proper CORS headers if needed
- [ ] Implement authentication/authorization
- [ ] Log SSE errors for monitoring
- [ ] Test with malformed input

### Client-Side

- [ ] Use streaming APIs (`getStream()`) instead of `response.body`
- [ ] Handle `SSEError`, `IOError`, and `OSError`
- [ ] Implement reconnection with Last-Event-ID
- [ ] Set timeout for connection
- [ ] Validate received data before processing
- [ ] Escape data before embedding in HTML/JavaScript
- [ ] Implement heartbeat monitoring
- [ ] Test with large streams

### General

- [ ] Review [examples/security_examples.nim](examples/security_examples.nim)
- [ ] Understand [Security Limitations](#security-limitations)
- [ ] Implement input validation for your use case
- [ ] Set up monitoring for SSE errors
- [ ] Document security assumptions for your team

---

## Reporting Security Issues

If you discover a security vulnerability, please report it responsibly:

1. **Do NOT** create a public GitHub issue
2. Email the maintainer with details
3. Allow reasonable time for a fix before public disclosure

---

## Additional Resources

- [HTML5 SSE Specification](https://html.spec.whatwg.org/multipage/server-sent-events.html)
- [OWASP XSS Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html)
- [examples/security_examples.nim](examples/security_examples.nim) - Code examples
- [README.md](README.md) - General documentation

---

**Last Updated**: 2026-03-08  
**Version**: 0.1.0
