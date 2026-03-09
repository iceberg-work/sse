## SSE (Server-Sent Events) Library
## ================================
## 
## A framework-agnostic implementation of the HTML5 Server-Sent Events protocol.
## This library provides parsing, formatting, and streaming capabilities for SSE.
## 
## Version Compatibility
## ---------------------
## 
## - Requires Nim >= 2.0.0
## - Developed and tested with Nim 2.2.6 (Windows/Linux)
## 
## Thread Safety
## -------------
## 
## - `SSEvent` is a value type and is safe to share across threads
## - `SSEParser` is **NOT thread-safe**. Each parser instance maintains mutable
##   internal state (buffer, lastEventId). If you need to use a parser from
##   multiple threads, you must synchronize access with a lock (e.g., `Lock` from
##   `std/locks`) or use a separate parser instance per thread
## - All `parse()` and `format()` functions are pure and thread-safe
## 
## Performance Characteristics
## ---------------------------
## 
## - **Memory**: Uses a single internal buffer for streaming. Memory usage is
##   bounded by `maxBufferSize` (default: 1 MB). When exceeded, `SSEError` is
##   raised and the buffer is cleared
## - **Throughput**: Optimized for high performance. Simple events process in
##   sub-microsecond range. Run `nim c -r -d:release tests/benchmark.nim` for
##   actual measurements on your system
## - **Large Data**: Handles events up to the buffer limit efficiently.
##   For events larger than 1MB, increase `maxBufferSize` in `initSSEParser()`
## - **GC Pressure**: Minimal. Strings are reused where possible. Run `GC_fullCollect()`
##   periodically in long-running servers if memory is a concern
## 
## Example:
## ```nim
## import sse
## 
## # Create and format an event
## let evt = initSSEvent("hello world", "message", "123", 5000)
## echo evt.format()
## # Output: event: message
## #         data: hello world
## #         id: 123
## #         retry: 5000
## #         
## 
## # Parse SSE data
## let events = parse("data: hello\n\ndata: world\n\n")
## for e in events:
##   echo e.data
## ```
## 
## For more examples, see:
## * [examples/basic_usage.nim](https://github.com/iceberg-work/sse/tree/main/examples/basic_usage.nim) - Basic usage patterns
## * [examples/ssevent_examples.nim](https://github.com/iceberg-work/sse/tree/main/examples/ssevent_examples.nim) - SSEvent operations
## * [examples/parser_examples.nim](https://github.com/iceberg-work/sse/tree/main/examples/parser_examples.nim) - Streaming parser
## * [examples/validation_examples.nim](https://github.com/iceberg-work/sse/tree/main/examples/validation_examples.nim) - Validation
## * [examples/json_examples.nim](https://github.com/iceberg-work/sse/tree/main/examples/json_examples.nim) - JSON serialization
## * [examples/advanced_examples.nim](https://github.com/iceberg-work/sse/tree/main/examples/advanced_examples.nim) - Advanced patterns
## 
## See also:
## * HTML5 SSE Specification: https://html.spec.whatwg.org/multipage/server-sent-events.html

import std/[strutils, json]

const
  DefaultMaxBufferSize* = 1024 * 1024
  ## Default maximum buffer size for SSEParser (1 MB)
  
  DefaultMaxParseSize* = 10 * 1024 * 1024
  ## Default maximum input size for parse() function (10 MB)

type
  SSEvent* = object
    ## Represents a single Server-Sent Event.
    ## 
    ## Fields:
    ## * `event`: The event type (optional, defaults to "message" in browsers)
    ## * `data`: The event data (required for meaningful events)
    ## * `id`: The last event ID (used for reconnection)
    ## * `retry`: Reconnection time in milliseconds (optional)
    ##   - `-1` means not set (when created via initSSEvent)
    ##   - `0` is the default when parsed (negative values are ignored during parsing)
    event*: string
    data*: string
    id*: string
    retry*: int
  
  SSEParser* = object
    ## Streaming parser for incremental SSE data processing.
    ## 
    ## Use `feed()` to incrementally parse incoming data chunks.
    ## The parser maintains internal buffer state and tracks the last event ID.
    ## 
    ## Example:
    ## ```nim
    ## var parser = initSSEParser()
    ## let events = parser.feed("data: hello\n\n")
    ## ```
    buffer: string
    maxBufferSize: int
    lastEventId*: string
    ## The ID of the last successfully parsed event
  
  SSEError* = object of CatchableError
    ## Exception raised when SSE parsing encounters an error.
    ## Currently raised when buffer size exceeds maxBufferSize.

proc safeParseInt(s: string): tuple[ok: bool, val: int] =
  try:
    (true, parseInt(s))
  except ValueError:
    (false, 0)

proc sanitizeField(s: string): string =
  ## Removes all newline characters from a field value to prevent field injection.
  ## 
  ## Handles:
  ## - \\r\\n (CRLF)
  ## - \\r (CR)
  ## - \\n (LF)
  ## - \\u2028 (LINE SEPARATOR)
  ## - \\u2029 (PARAGRAPH SEPARATOR)
  ## - \\0 (NULL character)
  ## 
  ## This is used for event and id fields to prevent injection attacks.
  result = s.replace("\r\n", "").replace("\r", "").replace("\n", "")
  result = result.replace("\u2028", "").replace("\u2029", "")
  result = result.replace("\0", "")

proc initSSEvent*(data: string, event = "", id = "", retry = -1): SSEvent =
  ## Creates a new SSEvent with the specified fields.
  ## 
  ## Parameters:
  ## * `data`: The event data (required)
  ## * `event`: The event type (optional)
  ## * `id`: The event ID (optional) - must not contain NULL characters
  ## * `retry`: Reconnection time in milliseconds (optional, -1 = not set)
  ## 
  ## Security Note:
  ## - Event and ID fields are sanitized during initialization to prevent injection attacks
  ## - ID field must not contain NULL characters (will be removed)
  ## 
  ## Example:
  ## ```nim
  ## let evt = initSSEvent("hello", "message", "123", 5000)
  ## ```
  ## 
  ## See also:
  ## * [examples/ssevent_examples.nim](https://github.com/iceberg-work/sse/tree/main/examples/ssevent_examples.nim) - Initialization examples
  let safeId = sanitizeField(id)
  let safeEvent = sanitizeField(event)
  SSEvent(data: data, event: safeEvent, id: safeId, retry: retry)

proc initSSEParser*(maxBufferSize = DefaultMaxBufferSize): SSEParser =
  ## Creates a new SSE parser with the specified maximum buffer size.
  ## 
  ## Parameters:
  ## * `maxBufferSize`: Maximum bytes to buffer before raising SSEError
  ## 
  ## Example:
  ## ```nim
  ## var parser = initSSEParser(maxBufferSize = 2 * 1024 * 1024)  # 2 MB
  ## ```
  ## 
  ## See also:
  ## * [examples/parser_examples.nim](https://github.com/iceberg-work/sse/tree/main/examples/parser_examples.nim) - Parser initialization
  let safeMaxSize = if maxBufferSize <= 0: DefaultMaxBufferSize else: maxBufferSize
  SSEParser(buffer: "", maxBufferSize: safeMaxSize, lastEventId: "")

proc format*(evt: SSEvent): string =
  ## Formats an SSEvent as a valid SSE message string.
  ## 
  ## The output follows the SSE specification:
  ## - Multiline data is split into multiple `data:` fields
  ## - Empty fields are omitted
  ## - CRLF and CR are normalized to LF
  ## 
  ## Security Note:
  ## - Event and ID fields are already sanitized by initSSEvent()
  ## - Data fields preserve newlines (as per SSE spec) but be cautious when
  ##   embedding JSON or other structured data that may contain colon-prefixed text
  ## 
  ## Example:
  ## ```nim
  ## let evt = initSSEvent("hello\nworld", "message")
  ## echo evt.format()
  ## # Output:
  ## # event: message
  ## # data: hello
  ## # data: world
  ## # 
  ## ```
  ## 
  ## See also:
  ## * [examples/ssevent_examples.nim](https://github.com/iceberg-work/sse/tree/main/examples/ssevent_examples.nim) - Format examples
  result.setLen(0)
  
  if evt.event.len > 0:
    result.add "event: "
    result.add evt.event
    result.add "\n"
  
  if evt.data.len == 0:
    result.add "data: \n"
  else:
    var i = 0
    while i < evt.data.len:
      var lineEnd = i
      while lineEnd < evt.data.len and evt.data[lineEnd] != '\n' and evt.data[lineEnd] != '\r':
        inc lineEnd
      result.add "data: "
      result.add evt.data.substr(i, lineEnd - 1)
      result.add "\n"
      i = lineEnd
      if i < evt.data.len and evt.data[i] == '\r':
        inc i
      if i < evt.data.len and evt.data[i] == '\n':
        inc i
  
  if evt.id.len > 0:
    result.add "id: "
    result.add evt.id
    result.add "\n"
  if evt.retry >= 0:
    result.add "retry: "
    result.add $evt.retry
    result.add "\n"
  result.add "\n"

proc format*(events: seq[SSEvent]): string =
  ## Formats a sequence of SSEvents as a concatenated SSE stream.
  ## 
  ## Example:
  ## ```nim
  ## let events = @[initSSEvent("first"), initSSEvent("second")]
  ## echo format(events)
  ## # Output:
  ## # data: first
  ## # 
  ## # data: second
  ## # 
  ## ```
  for evt in events:
    result.add(evt.format())

proc formatHeartbeat*(comment = ""): string =
  ## Formats an SSE heartbeat/comment line.
  ## 
  ## Heartbeats are used to keep the connection alive and are ignored by clients.
  ## 
  ## Parameters:
  ## * `comment`: Optional comment text (default: empty)
  ## 
  ## Security: Newlines in comment are removed to prevent comment line injection.
  ## Handles: \\r, \\n, \\u2028 (LINE SEPARATOR), \\u2029 (PARAGRAPH SEPARATOR)
  ## 
  ## Example:
  ## ```nim
  ## echo formatHeartbeat()        # Output: ":\n\n"
  ## echo formatHeartbeat("ping")  # Output: ": ping\n\n"
  ## ```
  result = ":"
  if comment.len > 0:
    let safeComment = sanitizeField(comment)
    result.add(" " & safeComment)
  result.add("\n\n")

proc parse*(raw: string, maxSize = DefaultMaxParseSize): seq[SSEvent] =
  ## Parses a raw SSE string into a sequence of SSEvents.
  ## 
  ## Follows the HTML5 SSE specification:
  ## - Empty lines dispatch events
  ## - Lines starting with `:` are comments (ignored)
  ## - `data:` fields are concatenated with newlines
  ## - Invalid `retry:` values are silently ignored
  ## - Unknown fields are ignored
  ## 
  ## Parameters:
  ## * `raw`: The raw SSE data to parse
  ## * `maxSize`: Maximum input size in bytes (default: 10 MB). Raises SSEError
  ##   if exceeded to prevent DoS attacks.
  ## 
  ## Raises:
  ## * `SSEError` if input size exceeds maxSize
  ## 
  ## Example:
  ## ```nim
  ## let events = parse("data: hello\n\ndata: world\n\n")
  ## echo events.len      # 2
  ## echo events[0].data  # "hello"
  ## echo events[1].data  # "world"
  ## ```
  ## 
  ## See also:
  ## * [examples/ssevent_examples.nim](https://github.com/iceberg-work/sse/tree/main/examples/ssevent_examples.nim) - Parse examples
  let safeMaxSize = if maxSize <= 0: DefaultMaxParseSize else: maxSize
  if raw.len > safeMaxSize:
    raise newException(SSEError, "Input size exceeds maximum limit")
  
  var currentEvent = SSEvent()
  var dataLines: seq[string] = @[]
  var hasContent = false
  
  for line in raw.splitLines():
    if line.len == 0:
      if hasContent:
        currentEvent.data = dataLines.join("\n")
        result.add(currentEvent)
        currentEvent = SSEvent()
        dataLines = @[]
        hasContent = false
    elif line[0] == ':':
      discard
    elif ':' in line:
      let colonPos = line.find(':')
      let field = line[0..<colonPos]
      var value = if colonPos + 1 < line.len: line[colonPos+1..^1] else: ""
      
      if value.len > 0 and value[0] == ' ':
        value = value[1..^1]
      
      case field
      of "event":
        currentEvent.event = sanitizeField(value)
        hasContent = true
      of "data":
        dataLines.add(value)
        hasContent = true
      of "id":
        currentEvent.id = sanitizeField(value)
        hasContent = true
      of "retry":
        hasContent = true
        let (ok, val) = safeParseInt(value)
        if ok and val >= 0:
          currentEvent.retry = val
      else:
        discard

  if hasContent:
    currentEvent.data = dataLines.join("\n")
    result.add(currentEvent)

proc normalizeNewlines(s: string): string =
  ## Normalizes all newline variations to \n
  result = s.replace("\r\n", "\n").replace("\r", "\n")

proc findDoubleNewlinePos(s: string): tuple[pos: int, len: int] =
  ## Finds the position of any double newline combination
  ## Returns (position, separator_length) or (-1, 0) if not found
  var i = 0
  while i < s.len:
    let c = s[i]
    if c == '\n' or c == '\r':
      var j = i + 1
      while j < s.len and (s[j] == '\n' or s[j] == '\r'):
        inc j
      if j - i >= 2:
        return (i, j - i)
      i = j
    else:
      inc i
  return (-1, 0)

proc feed*(parser: var SSEParser, data: string): seq[SSEvent] =
  ## Incrementally feeds data to the parser and returns completed events.
  ## 
  ## This is useful for streaming scenarios where data arrives in chunks.
  ## The parser buffers incomplete data until a complete event is received.
  ## 
  ## Raises:
  ## * `SSEError` if buffer size exceeds maxBufferSize
  ## 
  ## Example:
  ## ```nim
  ## var parser = initSSEParser()
  ## 
  ## # Data split across chunks
  ## let events1 = parser.feed("data: hel")
  ## echo events1.len  # 0 (incomplete)
  ## 
  ## let events2 = parser.feed("lo\n\n")
  ## echo events2.len  # 1 (complete)
  ## echo events2[0].data  # "hello"
  ## ```
  ## 
  ## See also:
  ## * [examples/parser_examples.nim](https://github.com/iceberg-work/sse/tree/main/examples/parser_examples.nim) - Streaming examples
  if parser.buffer.len + data.len > parser.maxBufferSize:
    parser.buffer = ""
    parser.lastEventId = ""
    raise newException(SSEError, "Buffer size exceeded maximum limit")
  
  parser.buffer.add(data)
  result = @[]
  
  while true:
    let (dblNewline, sepLen) = findDoubleNewlinePos(parser.buffer)
    if dblNewline == -1:
      break
    
    let chunk = parser.buffer[0..<dblNewline]
    let remainingStart = dblNewline + sepLen
    
    var newBuffer = ""
    if remainingStart < parser.buffer.len:
      newBuffer = parser.buffer[remainingStart..^1]
    parser.buffer = newBuffer
    
    let normalizedChunk = normalizeNewlines(chunk)
    let events = parse(normalizedChunk & "\n\n", maxSize = parser.maxBufferSize)
    
    for evt in events:
      if evt.id.len > 0:
        parser.lastEventId = evt.id
      result.add(evt)

proc hasPending*(parser: SSEParser): bool =
  ## Returns true if the parser has incomplete data in its buffer.
  ## 
  ## Example:
  ## ```nim
  ## var parser = initSSEParser()
  ## discard parser.feed("data: partial")
  ## echo parser.hasPending()  # true
  ## ```
  parser.buffer.len > 0

proc reset*(parser: var SSEParser) =
  ## Resets the parser state, clearing the buffer and lastEventId.
  ## 
  ## Example:
  ## ```nim
  ## var parser = initSSEParser()
  ## discard parser.feed("data: partial")
  ## parser.reset()
  ## echo parser.hasPending()  # false
  ## ```
  parser.buffer = ""
  parser.lastEventId = ""

proc validateSyntax*(raw: string): tuple[valid: bool, error: string] =
  ## Validates SSE syntax and returns (true, "") if valid.
  ## 
  ## Checks for:
  ## - Valid field names (event, data, id, retry)
  ## - Valid retry values (must be non-negative integer)
  ## 
  ## Example:
  ## ```nim
  ## let (valid, err) = validateSyntax("data: hello\n\n")
  ## echo valid  # true
  ## ```
  ## 
  ## See also:
  ## * [examples/validation_examples.nim](https://github.com/iceberg-work/sse/tree/main/examples/validation_examples.nim) - Validation examples
  for line in raw.splitLines():
    if line.len == 0 or line[0] == ':':
      continue
    if ':' notin line:
      return (false, "Invalid line format: " & line)
    
    let colonPos = line.find(':')
    let field = line[0..<colonPos]
    
    if field notin ["event", "data", "id", "retry"]:
      return (false, "Unknown field: " & field)
    
    if field == "retry":
      var value = if colonPos + 1 < line.len: line[colonPos+1..^1] else: ""
      if value.len > 0 and value[0] == ' ':
        value = value[1..^1]
      let (ok, val) = safeParseInt(value)
      if not ok:
        return (false, "Invalid retry value: " & value)
      if val < 0:
        return (false, "Negative retry value is not allowed: " & value)
        
  return (true, "")

proc validateStrict*(raw: string): tuple[valid: bool, error: string] =
  ## Validates SSE syntax with stricter checks.
  ## 
  ## Validates:
  ## - Valid field names (event, data, id, retry)
  ## - Valid retry values (must be non-negative integer)
  ## - Rejects lines without colons (except empty lines and comments)
  ## 
  ## Note: This is the same as validateSyntax(), kept for backward compatibility.
  ## 
  ## Example:
  ## ```nim
  ## let (valid, err) = validateStrict("data: hello\nretry: abc\n\n")
  ## echo valid  # false (invalid retry value)
  ## ```
  ## 
  ## See also:
  ## * [examples/validation_examples.nim](https://github.com/iceberg-work/sse/tree/main/examples/validation_examples.nim) - Strict validation examples
  validateSyntax(raw)

proc validate*(raw: string): tuple[valid: bool, error: string] =
  ## Alias for validateSyntax.
  ## 
  ## Validates SSE syntax and returns (true, "") if valid.
  validateSyntax(raw)

proc toJson*(evt: SSEvent): JsonNode =
  ## Converts an SSEvent to a JsonNode.
  ## 
  ## Only non-empty fields are included in the output.
  ## 
  ## Security Warning:
  ## This function outputs raw field values without sanitization.
  ## Newlines in event/id fields are preserved in JSON (unlike format() which removes them).
  ## 
  ## **DO NOT** embed the resulting JSON directly in HTML or JavaScript without proper escaping.
  ## If you need SSE-compliant output, use format() instead.
  ## 
  ## Example:
  ## ```nim
  ## let evt = initSSEvent("hello", "message", "123", 5000)
  ## let j = evt.toJson()
  ## echo j["data"].getStr()  # "hello"
  ## ```
  ## 
  ## See also:
  ## * [examples/json_examples.nim](https://github.com/iceberg-work/sse/tree/main/examples/json_examples.nim) - JSON serialization examples
  result = %*{
    "data": evt.data
  }
  if evt.event.len > 0:
    result["event"] = %evt.event
  if evt.id.len > 0:
    result["id"] = %evt.id
  if evt.retry >= 0:
    result["retry"] = %evt.retry

proc fromJson*(node: JsonNode): SSEvent =
  ## Converts a JsonNode to an SSEvent.
  ## 
  ## Type-safe: mismatched types are silently ignored with default values.
  ## 
  ## Example:
  ## ```nim
  ## let j = %*{"data": "hello", "event": "message"}
  ## let evt = fromJson(j)
  ## echo evt.data  # "hello"
  ## ```
  ## 
  ## See also:
  ## * [examples/json_examples.nim](https://github.com/iceberg-work/sse/tree/main/examples/json_examples.nim) - JSON deserialization examples
  result.data = if node.hasKey("data") and node["data"].kind == JString: node["data"].getStr("") else: ""
  result.event = if node.hasKey("event") and node["event"].kind == JString: node["event"].getStr("") else: ""
  result.id = if node.hasKey("id") and node["id"].kind == JString: node["id"].getStr("") else: ""
  
  if node.hasKey("retry"):
    if node["retry"].kind == JInt:
      result.retry = node["retry"].getInt()
    else:
      result.retry = -1
  else:
    result.retry = -1

proc `$`*(evt: SSEvent): string =
  ## Returns a string representation of an SSEvent.
  ## 
  ## Data is truncated to 50 characters for readability.
  ## 
  ## Example:
  ## ```nim
  ## let evt = initSSEvent("hello", "message", "123", 5000)
  ## echo $evt  # SSEvent(event: message, data: hello, id: 123, retry: 5000)
  ## ```
  let dataPreview = if evt.data.len > 50: evt.data[0..<50] & "..." else: evt.data
  result = "SSEvent(event: " & evt.event
  result &= ", data: " & dataPreview
  result &= ", id: " & evt.id
  result &= ", retry: " & $evt.retry & ")"

proc `==`*(a, b: SSEvent): bool =
  ## Compares two SSEvents for equality.
  ## 
  ## All fields must match for events to be considered equal.
  a.event == b.event and a.data == b.data and a.id == b.id and a.retry == b.retry
