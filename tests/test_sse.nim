discard """
  cmd:      "nim c -r --styleCheck:hint $options $file"
  matrix:   "--mm:refc; --mm:orc"
  targets:  "c"
  action:   "run"
  exitcode: 0
"""

import std/[unittest, strutils, json]
import ../src/sse

suite "SSEvent initialization":
  test "basic initialization":
    let evt = initSSEvent("hello")
    check evt.data == "hello"
    check evt.event == ""
    check evt.id == ""
    check evt.retry == -1

  test "full initialization":
    let evt = initSSEvent("data", "message", "123", 5000)
    check evt.data == "data"
    check evt.event == "message"
    check evt.id == "123"
    check evt.retry == 5000

suite "SSEvent format":
  test "simple data":
    let evt = initSSEvent("hello")
    check evt.format() == "data: hello\n\n"

  test "with event type":
    let evt = initSSEvent("hello", "message")
    check evt.format() == "event: message\ndata: hello\n\n"

  test "multiline data":
    let evt = initSSEvent("line1\nline2")
    check evt.format() == "data: line1\ndata: line2\n\n"

  test "with id":
    let evt = initSSEvent("test", "", "abc")
    check "id: abc" in evt.format()
    check "event:" notin evt.format()

  test "with retry":
    let evt = initSSEvent("test", "event", "id", 5000)
    let fmt = evt.format()
    check "event: event" in fmt
    check "data: test" in fmt
    check "id: id" in fmt
    check "retry: 5000" in fmt

  test "CRLF normalization":
    let evt = initSSEvent("line1\r\nline2")
    check '\r' notin evt.format()
    check evt.format() == "data: line1\ndata: line2\n\n"

  test "CR normalization":
    let evt = initSSEvent("line1\rline2")
    check '\r' notin evt.format()
    check evt.format() == "data: line1\ndata: line2\n\n"

  test "empty data":
    let evt = initSSEvent("")
    check evt.format() == "data: \n\n"

  test "retry = 0":
    let evt = initSSEvent("test", "", "", 0)
    check "retry: 0" in evt.format()

  test "negative retry not included":
    let evt = initSSEvent("test", "", "", -1)
    check "retry:" notin evt.format()

suite "format seq[SSEvent]":
  test "multiple events":
    let events = @[
      initSSEvent("first"),
      initSSEvent("second", "custom")
    ]
    let fmt = format(events)
    check "data: first" in fmt
    check "data: second" in fmt
    check "event: custom" in fmt

suite "formatHeartbeat":
  test "empty comment (standard)":
    let hb = formatHeartbeat()
    check hb == ":\n\n"

  test "with comment":
    let hb = formatHeartbeat("ping")
    check hb == ": ping\n\n"

  test "comment with newlines removed":
    let hb = formatHeartbeat("ping\nid: injected")
    check "ping\nid:" notin hb
    check "pingid: injected" in hb

  test "comment with CRLF removed":
    let hb = formatHeartbeat("ping\r\ninjected")
    check "ping\r\n" notin hb
    check "pinginjected" in hb

suite "SSEvent parse":
  test "simple event":
    let events = parse("data: hello\n\n")
    check events.len == 1
    check events[0].data == "hello"

  test "with event type":
    let events = parse("event: message\ndata: hello\n\n")
    check events.len == 1
    check events[0].event == "message"
    check events[0].data == "hello"

  test "multiline data":
    let events = parse("data: line1\ndata: line2\n\n")
    check events.len == 1
    check events[0].data == "line1\nline2"

  test "with id":
    let events = parse("data: test\nid: abc\n\n")
    check events.len == 1
    check events[0].id == "abc"

  test "with retry":
    let events = parse("data: test\nretry: 5000\n\n")
    check events.len == 1
    check events[0].retry == 5000

  test "comment ignored":
    let events = parse(": this is a comment\ndata: hello\n\n")
    check events.len == 1
    check events[0].data == "hello"

  test "multiple events":
    let events = parse("data: first\n\ndata: second\n\n")
    check events.len == 2
    check events[0].data == "first"
    check events[1].data == "second"

  test "full event":
    let raw = "event: custom\ndata: test data\nid: msg-001\nretry: 3000\n\n"
    let events = parse(raw)
    check events.len == 1
    check events[0].event == "custom"
    check events[0].data == "test data"
    check events[0].id == "msg-001"
    check events[0].retry == 3000

  test "Windows CRLF line endings":
    let events = parse("data: hello\r\n\r\n")
    check events.len == 1
    check events[0].data == "hello"

  test "colon without space":
    let events = parse("data:value\n\n")
    check events.len == 1
    check events[0].data == "value"

  test "colon with multiple spaces (only first removed)":
    let events = parse("data:  value\n\n")
    check events.len == 1
    check events[0].data == " value"

  test "empty input":
    let events = parse("")
    check events.len == 0

  test "pure comment stream":
    let events = parse(": comment1\n: comment2\n\n")
    check events.len == 0

suite "SSEParser (streaming)":
  test "single event in one chunk":
    var parser = initSSEParser()
    let events = parser.feed("data: hello\n\n")
    check events.len == 1
    check events[0].data == "hello"
    check not parser.hasPending()

  test "event split across chunks":
    var parser = initSSEParser()
    var events = parser.feed("data: hel")
    check events.len == 0
    check parser.hasPending()
    
    events = parser.feed("lo\n\n")
    check events.len == 1
    check events[0].data == "hello"

  test "multiple events in chunks":
    var parser = initSSEParser()
    var events = parser.feed("data: first\n\ndata: sec")
    check events.len == 1
    check events[0].data == "first"
    
    events = parser.feed("ond\n\n")
    check events.len == 1
    check events[0].data == "second"

  test "reset parser":
    var parser = initSSEParser()
    discard parser.feed("data: partial")
    check parser.hasPending()
    parser.reset()
    check not parser.hasPending()

  test "lastEventId tracking":
    var parser = initSSEParser()
    discard parser.feed("data: test\nid: msg-123\n\n")
    check parser.lastEventId == "msg-123"
    
    discard parser.feed("data: test2\nid: msg-456\n\n")
    check parser.lastEventId == "msg-456"

  test "buffer at exact boundary":
    var parser = initSSEParser()
    let events = parser.feed("data: hello\n\n")
    check events.len == 1
    check not parser.hasPending()

  test "buffer overflow protection":
    var parser = initSSEParser(maxBufferSize = 100)
    var raised = false
    try:
      discard parser.feed("x".repeat(150))
    except SSEError:
      raised = true
    check raised
    check not parser.hasPending()

  test "empty feed":
    var parser = initSSEParser()
    let events = parser.feed("")
    check events.len == 0
    check not parser.hasPending()

suite "validateSyntax":
  test "valid event":
    let (valid, err) = validateSyntax("data: hello\n\n")
    check valid
    check err == ""

  test "valid with all fields":
    let (valid, _) = validateSyntax("event: msg\ndata: hello\nid: 1\nretry: 5000\n\n")
    check valid

  test "valid with comment":
    let (valid, _) = validateSyntax(": comment\ndata: hello\n\n")
    check valid

  test "invalid retry value":
    let (valid, err) = validateSyntax("data: test\nretry: abc\n\n")
    check not valid
    check "Invalid retry value" in err

  test "negative retry value rejected":
    let (valid, err) = validateSyntax("data: test\nretry: -1000\n\n")
    check not valid
    check "Negative retry value" in err

  test "unknown field":
    let (valid, err) = validateSyntax("unknown: value\ndata: test\n\n")
    check not valid
    check "Unknown field" in err

suite "validateStrict":
  test "valid event with data":
    let (valid, _) = validateStrict("data: hello\n\n")
    check valid

  test "event without data is valid (SSE spec allows)":
    let (valid, _) = validateStrict("event: msg\n\n")
    check valid

  test "id only event is valid":
    let (valid, _) = validateStrict("id: 123\n\n")
    check valid

  test "valid with all fields":
    let (valid, _) = validateStrict("event: msg\ndata: hello\nid: 1\nretry: 5000\n\n")
    check valid

  test "negative retry value rejected":
    let (valid, err) = validateStrict("data: test\nretry: -1000\n\n")
    check not valid
    check "Negative retry value" in err

suite "JSON support":
  test "toJson simple":
    let evt = initSSEvent("hello")
    let j = evt.toJson()
    check j["data"].getStr() == "hello"
    check "event" notin j

  test "toJson full":
    let evt = initSSEvent("test", "message", "123", 5000)
    let j = evt.toJson()
    check j["data"].getStr() == "test"
    check j["event"].getStr() == "message"
    check j["id"].getStr() == "123"
    check j["retry"].getInt() == 5000

  test "fromJson with all fields":
    let j = %*{"data": "test", "event": "msg", "id": "1", "retry": 3000}
    let evt = fromJson(j)
    check evt.data == "test"
    check evt.event == "msg"
    check evt.id == "1"
    check evt.retry == 3000

  test "fromJson missing fields":
    let j = %*{"data": "test"}
    let evt = fromJson(j)
    check evt.data == "test"
    check evt.event == ""
    check evt.id == ""
    check evt.retry == -1

  test "fromJson empty object":
    let j = %*{}
    let evt = fromJson(j)
    check evt.data == ""
    check evt.event == ""
    check evt.id == ""
    check evt.retry == -1

  test "fromJson retry as string (type mismatch)":
    let j = %*{"data": "test", "retry": "5000"}
    let evt = fromJson(j)
    check evt.data == "test"
    check evt.retry == -1

  test "fromJson retry as float (type mismatch)":
    let j = %*{"data": "test", "retry": 5.5}
    let evt = fromJson(j)
    check evt.data == "test"
    check evt.retry == -1

  test "fromJson retry as null (type mismatch)":
    let j = %*{"data": "test", "retry": newJNull()}
    let evt = fromJson(j)
    check evt.data == "test"
    check evt.retry == -1

  test "fromJson retry as object (type mismatch)":
    let j = %*{"data": "test", "retry": {"value": 5000}}
    let evt = fromJson(j)
    check evt.data == "test"
    check evt.retry == -1

  test "fromJson data as int (type mismatch)":
    let j = %*{"data": 123, "event": "test"}
    let evt = fromJson(j)
    check evt.data == ""
    check evt.event == "test"

  test "fromJson data as array (type mismatch)":
    let j = %*{"data": [1, 2, 3]}
    let evt = fromJson(j)
    check evt.data == ""

  test "fromJson event as int (type mismatch)":
    let j = %*{"data": "test", "event": 123}
    let evt = fromJson(j)
    check evt.event == ""

  test "fromJson id as bool (type mismatch)":
    let j = %*{"data": "test", "id": true}
    let evt = fromJson(j)
    check evt.id == ""

  test "toJson fromJson round-trip":
    let original = initSSEvent("test data", "message", "123", 5000)
    let evt = fromJson(original.toJson())
    check evt == original

suite "equality":
  test "equal events":
    let a = initSSEvent("hello", "msg", "1", 5000)
    let b = initSSEvent("hello", "msg", "1", 5000)
    check a == b

  test "different data":
    let a = initSSEvent("hello")
    let b = initSSEvent("world")
    check a != b

  test "different event type":
    let a = initSSEvent("hello", "msg1")
    let b = initSSEvent("hello", "msg2")
    check a != b

suite "Round-trip":
  test "format then parse":
    let original = initSSEvent("test data", "message", "123", 5000)
    let parsed = parse(original.format())
    check parsed.len == 1
    check parsed[0].data == original.data
    check parsed[0].event == original.event
    check parsed[0].id == original.id
    check parsed[0].retry == original.retry

suite "Large data handling":
  test "large single line data (1MB)":
    let largeData = "x".repeat(1024 * 1024)
    let evt = initSSEvent(largeData)
    let fmt = evt.format()
    check fmt.len > 1024 * 1024
    let parsed = parse(fmt)
    check parsed.len == 1
    check parsed[0].data.len == 1024 * 1024

  test "large multiline data (1000 lines)":
    var lines: seq[string] = @[]
    for i in 0..<1000:
      lines.add("line " & $i)
    let multiData = lines.join("\n")
    let evt = initSSEvent(multiData)
    let parsed = parse(evt.format())
    check parsed.len == 1
    check parsed[0].data.split("\n").len == 1000

  test "parser handles large chunk":
    var parser = initSSEParser(maxBufferSize = 2 * 1024 * 1024)
    let largeData = "x".repeat(1024 * 1024)
    let events = parser.feed("data: " & largeData & "\n\n")
    check events.len == 1
    check events[0].data.len == 1024 * 1024

  test "parser rejects oversized chunk":
    var parser = initSSEParser(maxBufferSize = 100)
    var raised = false
    try:
      discard parser.feed("data: " & "x".repeat(200) & "\n\n")
    except SSEError:
      raised = true
    check raised

  test "many small events":
    var raw = ""
    for i in 0..<100:
      raw.add("data: event" & $i & "\n\n")
    let events = parse(raw)
    check events.len == 100
    check events[0].data == "event0"
    check events[99].data == "event99"

suite "LLM API Streaming (Use Case)":
  test "OpenAI-style single-line JSON":
    # OpenAI SSE responses are single-line JSON
    let raw = "data: {\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}\n\n"
    let events = parse(raw)
    check events.len == 1
    check events[0].data == "{\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}"
  
  test "JSON with special characters (colons, quotes)":
    let jsonStr = """{"message": "Value: with colon and \"quotes\""}"""
    let evt = initSSEvent(jsonStr, "message")
    let parsed = parse(evt.format())
    check parsed.len == 1
    check parsed[0].data == jsonStr
  
  test "Unicode in JSON content":
    let jsonStr = """{"content": "Hello 你好 🌍 مرحبا"}"""
    let evt = initSSEvent(jsonStr, "message")
    let parsed = parse(evt.format())
    check parsed.len == 1
    check parsed[0].data == jsonStr
  
  test "Multiline JSON (pretty-printed)":
    let multiJson = "{\n  \"key\": \"value\"\n}"
    let evt = initSSEvent(multiJson, "message")
    let parsed = parse(evt.format())
    check parsed.len == 1
    # Data field preserves newlines
    check parsed[0].data == multiJson
  
  test "Rapid sequential JSON events":
    var parser = initSSEParser()
    var eventCount = 0
    for i in 0..<100:
      let chunk = "data: {\"index\":" & $i & "}\n\n"
      let events = parser.feed(chunk)
      eventCount += events.len
    check eventCount == 100
  
  test "Large JSON content":
    var largeContent = ""
    for i in 0..<1000:
      largeContent.add("w" & $i & " ")
    let jsonStr = "{\"content\": \"" & largeContent & "\"}"
    let evt = initSSEvent(jsonStr, "message")
    let parsed = parse(evt.format())
    check parsed.len == 1
    check parsed[0].data.len > 4000  # Verify large content preserved

suite "Security - Parse size limits":
  test "parse rejects oversized input":
    var raised = false
    try:
      let largeInput = "x".repeat(15 * 1024 * 1024)  # 15 MB
      discard parse(largeInput)
    except SSEError:
      raised = true
    check raised

  test "parse accepts input under limit":
    let smallInput = "data: hello\n\n"
    let events = parse(smallInput, maxSize = 100)
    check events.len == 1

  test "parse rejects input over custom limit":
    var raised = false
    try:
      let input = "data: " & "x".repeat(200) & "\n\n"
      discard parse(input, maxSize = 100)
    except SSEError:
      raised = true
    check raised

suite "Security - Field injection prevention":
  test "format removes newlines from event field (prevents new field creation)":
    let malicious = initSSEvent("hello", "message\nid: injected", "real-id")
    let formatted = malicious.format()
    # Newlines are removed, so "id: injected" becomes part of the event line, not a new field
    check "event: messageid: injected" in formatted  # Text remains but on same line
    check formatted.find("event: message\nid: injected") == -1  # No new line created

  test "format removes CRLF from event field":
    let malicious = initSSEvent("hello", "message\r\nevent: injected", "id")
    let formatted = malicious.format()
    check "event: messageevent: injected" in formatted  # Text remains but on same line
    check formatted.find("event: message\r\nevent: injected") == -1  # No CRLF

  test "format removes newlines from id field":
    let malicious = initSSEvent("hello", "message", "id\nevent: injected")
    let formatted = malicious.format()
    check "id: idevent: injected" in formatted  # Text remains but on same line
    check formatted.find("id: id\nevent: injected") == -1  # No new line

  test "format removes CRLF from id field":
    let malicious = initSSEvent("hello", "message", "id\r\nevent: injected")
    let formatted = malicious.format()
    check "id: idevent: injected" in formatted  # Text remains but on same line
    check formatted.find("id: id\r\nevent: injected") == -1  # No CRLF

  test "format removes Unicode LINE SEPARATOR from event field":
    let malicious = initSSEvent("hello", "message\u2028event: injected", "id")
    let formatted = malicious.format()
    check "\u2028" notin formatted
    check "event: messageevent: injected" in formatted

  test "format removes Unicode PARAGRAPH SEPARATOR from event field":
    let malicious = initSSEvent("hello", "message\u2029event: injected", "id")
    let formatted = malicious.format()
    check "\u2029" notin formatted
    check "event: messageevent: injected" in formatted

  test "format removes Unicode LINE SEPARATOR from id field":
    let malicious = initSSEvent("hello", "message", "id\u2028event: injected")
    let formatted = malicious.format()
    check "\u2028" notin formatted
    check "id: idevent: injected" in formatted

  test "format removes Unicode PARAGRAPH SEPARATOR from id field":
    let malicious = initSSEvent("hello", "message", "id\u2029event: injected")
    let formatted = malicious.format()
    check "\u2029" notin formatted
    check "id: idevent: injected" in formatted

  test "format removes Unicode separators from heartbeat comment":
    let hb1 = formatHeartbeat("ping\u2028injected")
    let hb2 = formatHeartbeat("ping\u2029injected")
    check "\u2028" notin hb1
    check "\u2029" notin hb2
    check "pinginjected" in hb1
    check "pinginjected" in hb2

  test "data field still allows newlines":
    let multiline = initSSEvent("line1\nline2", "message")
    let formatted = multiline.format()
    check "data: line1" in formatted
    check "data: line2" in formatted

suite "Security - Retry value validation":
  test "parse ignores negative retry values":
    let raw = "data: test\nretry: -1000\n\n"
    let events = parse(raw)
    check events.len == 1
    # Negative retry values are ignored, retry stays at default (0 in SSEvent())
    check events[0].retry == 0

  test "parse accepts zero retry":
    let raw = "data: test\nretry: 0\n\n"
    let events = parse(raw)
    check events.len == 1
    check events[0].retry == 0

  test "parse accepts positive retry":
    let raw = "data: test\nretry: 5000\n\n"
    let events = parse(raw)
    check events.len == 1
    check events[0].retry == 5000

  test "format includes retry 0":
    let evt = initSSEvent("test", "", "", 0)
    let formatted = evt.format()
    check "retry: 0" in formatted

suite "Security - Edge Case Validation":
  test "initSSEParser handles negative maxBufferSize":
    var parser = initSSEParser(maxBufferSize = -100)
    check not parser.hasPending()
    let events = parser.feed("data: test\n\n")
    check events.len == 1
    check events[0].data == "test"
  
  test "initSSEParser handles zero maxBufferSize":
    var parser = initSSEParser(maxBufferSize = 0)
    check not parser.hasPending()
    let events = parser.feed("data: test\n\n")
    check events.len == 1
    check events[0].data == "test"
  
  test "parse handles negative maxSize":
    let events = parse("data: test\n\n", maxSize = -100)
    check events.len == 1
    check events[0].data == "test"
  
  test "parse handles zero maxSize":
    let events = parse("data: test\n\n", maxSize = 0)
    check events.len == 1
    check events[0].data == "test"
  
  test "buffer overflow resets lastEventId":
    var parser = initSSEParser(maxBufferSize = 50)
    discard parser.feed("data: first\nid: test-id\n\n")
    check parser.lastEventId == "test-id"
    
    var raised = false
    try:
      discard parser.feed("x".repeat(100))
    except SSEError:
      raised = true
    check raised
    check parser.lastEventId == ""
    check not parser.hasPending()

suite "Security - Newline Handling (Regression Tests)":
  test "feed handles CRLF separators":
    var parser = initSSEParser()
    let crlfData = "data: test1\r\n\r\ndata: test2\r\n\r\n"
    let events = parser.feed(crlfData)
    check events.len == 2
    check events[0].data == "test1"
    check events[1].data == "test2"
  
  test "feed handles CR-only separators":
    var parser = initSSEParser()
    let crData = "data: test1\r\rdata: test2\r\r"
    let events = parser.feed(crData)
    check events.len == 2
    check events[0].data == "test1"
    check events[1].data == "test2"
  
  test "feed handles mixed newline separators":
    var parser = initSSEParser()
    let mixedData = "data: a\n\ndata: b\r\n\r\ndata: c\r\r"
    let events = parser.feed(mixedData)
    check events.len == 3
    check events[0].data == "a"
    check events[1].data == "b"
    check events[2].data == "c"
  
  test "feed handles CRLF with CRCRLF pattern":
    var parser = initSSEParser()
    let data = "data: test\r\n\r\n\r\ndata: next\r\n\r\n"
    let events = parser.feed(data)
    check events.len == 2
    check events[0].data == "test"
    check events[1].data == "next"
  
  test "feed handles LFCRLF pattern":
    var parser = initSSEParser()
    let data = "data: test\n\r\n\r\ndata: next\n\r\n"
    let events = parser.feed(data)
    check events.len >= 1
    check events[0].data == "test"

echo "All SSE tests passed!"
