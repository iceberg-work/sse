# SSE - Server-Sent Events for Nim

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Nim Version](https://img.shields.io/badge/Nim-2.0.0+-blue.svg)](https://nim-lang.org)

**A dedicated, production-ready Server-Sent Events (SSE) library for Nim** - A framework-agnostic implementation of the HTML5 SSE protocol.

## 🎯 Why SSE?

Server-Sent Events are perfect for:
- 🤖 **LLM API Streaming** - OpenAI, Anthropic, and other AI APIs use SSE for token streaming
- 📊 **Real-time Updates** - Stock prices, news feeds, live scores
- 🔔 **Notifications** - Push notifications from server to browser
- 📈 **Progress Tracking** - File upload/download progress, build status
- 🎙️ **Live Comments** - Live chat, collaborative editing

## ✨ Features

- ✅ **Full SSE Specification** - Compliant with HTML5 SSE standard
- ✅ **Streaming Parser** - Process SSE data in real-time with chunked transfer
- ✅ **Reconnection Support** - Automatic Last-Event-ID tracking for resume capability
- ✅ **Security Built-in** - DoS protection, field injection prevention, buffer limits
- ✅ **Minimal Dependencies** - Pure Nim, uses only Nim standard library (no external dependencies)
- ✅ **High Performance** - Optimized for efficient event processing
- ✅ **Thread Safety Documented** - Clear thread safety documentation for all APIs
- ✅ **JSON Support** - Easy serialization/deserialization of events
- ✅ **Comprehensive Examples** - 13 example files covering all use cases

## 📦 Installation

### From Nimble (Recommended)
```bash
nimble install server-sent-events
```

### From Source
```bash
git clone https://github.com/iceberg-work/sse.git
cd sse
nimble install
```

### Add to Project
Add to your `.nimble` file:
```nim
requires "server-sent-events >= 0.1.0"
```

## 🚀 Quick Start

### 30 Seconds to First Event

```nim
import sse

# Create an event
let evt = initSSEvent("Hello, World!", "message", "1", 5000)

# Format for sending
echo evt.format()
# Output:
# event: message
# data: Hello, World!
# id: 1
# retry: 5000
# 
```

### Parse SSE Data

```nim
import sse

let events = parse("data: hello\n\ndata: world\n\n")
for evt in events:
  echo evt.data  # "hello", then "world"
```

### Streaming Parser

```nim
import sse

var parser = initSSEParser()

# Feed data in chunks
let events1 = parser.feed("data: Hel")
let events2 = parser.feed("lo\n\n")

echo events2[0].data  # "Hello"
```

## 📚 Examples

### Run All Examples
```bash
nim c -r examples/run_all.nim
```

### Key Examples

| Example | Description | Run Command |
|---------|-------------|-------------|
| **Quick Start** | 5-minute introduction | `nim c -r examples/quick_start.nim` |
| **Basic Usage** | Core API | `nim c -r examples/basic_usage.nim` |
| **HTTP Server** | SSE server with asynchttpserver | `nim c -r examples/http_server_examples.nim` |
| **HTTP Client** | Consume SSE streams | `nim c -r examples/http_client_examples.nim` |
| **LLM API** | OpenAI-style streaming | See `http_client_examples.nim` Scenario 3 |
| **Security** | DoS protection, injection prevention | `nim c -r examples/security_examples.nim` |
| **Consumer** | SSE client consumption patterns | `nim c -r examples/consumer_examples.nim` |
| **JSON** | JSON serialization/deserialization | `nim c -r examples/json_examples.nim` |
| **Parser** | Streaming parser usage | `nim c -r examples/parser_examples.nim` |
| **Web Framework** | Prologue, Jester, Karax integration | `nim c -r examples/web_framework_integration.nim` |

📖 **Full example guide**: [examples/README.md](examples/README.md)

## 📖 Documentation

### Core API

#### Event Creation
```nim
proc initSSEvent*(data: string, event = "", id = "", retry = -1): SSEvent
```

#### Formatting
```nim
proc format*(evt: SSEvent): string
proc format*(events: seq[SSEvent]): string
proc formatHeartbeat*(comment = ""): string
```

#### Parsing
```nim
proc parse*(raw: string, maxSize = DefaultMaxParseSize): seq[SSEvent]
proc feed*(parser: var SSEParser, data: string): seq[SSEvent]
```

#### Validation
```nim
proc validateSyntax*(raw: string): tuple[valid: bool, error: string]
proc validateStrict*(raw: string): tuple[valid: bool, error: string]
```

#### JSON Support
```nim
proc toJson*(evt: SSEvent): JsonNode
proc fromJson*(node: JsonNode): SSEvent
```

📖 **Full API documentation**: Generate with `nimble docs` or view [docs/sse.html](docs/sse.html)

## 🎯 Use Cases

### 1. LLM API Streaming (OpenAI-style)

```nim
import sse, httpclient, json, strutils

var client = newHttpClient()
client.headers = newHttpHeaders({
  "Authorization": "Bearer YOUR_API_KEY",
  "Accept": "text/event-stream"
})

# ⚠️ WARNING: For production, use getStream() instead of response.body
# to avoid loading entire streams into memory. See http_client_examples.nim.
let response = client.get("https://api.openai.com/v1/chat/completions?stream=true")
var parser = initSSEParser()

for line in response.body.splitLines():
  let events = parser.feed(line & "\n")
  for evt in events:
    if evt.data == "[DONE]":
      break
    let json = parseJson(evt.data)
    echo json["choices"][0]["delta"]["content"]
```

### 2. Simple SSE Server

```nim
import asynchttpserver, sse, asyncdispatch

# Note: This example shows SSE format. For true streaming, use lower-level APIs.

proc handleSSE(req: Request) {.async.} =
  try:
    # Build SSE response
    var response = ""
    
    # Add events
    for i in 1..10:
      let evt = initSSEvent("Message " & $i, "update", $i)
      response.add(evt.format())
    
    # Send response with SSE headers
    await req.respond(Http200, response, {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      "Connection": "keep-alive"
    }.newHttpHeaders)
  except:
    echo "Error handling request"

# Start server
var server = newAsyncHttpServer()
echo "SSE Server listening on http://127.0.0.1:8080"
discard serve(server, Port(8080), handleSSE, "127.0.0.1")
runForever()
```

### 3. Real-time Notifications

```nim
import sse

# Create notification event
let notification = initSSEvent(
  """{"title": "New Message", "body": "You have a new message!"}""",
  "notification",
  "msg-123"
)

# Send to client
echo notification.format()
```

## 🔒 Security

The library includes built-in protections against common attacks:

- **DoS Protection**: Default 10MB parse limit, configurable buffer sizes (default: 1MB)
- **Field Injection Prevention**: Newlines (`\r`, `\n`, `\u2028`, `\u2029`) in `event` and `id` fields are sanitized
- **Buffer Overflow**: Parser raises `SSEError` when buffer limit exceeded
- **Invalid Retry**: Negative retry values are silently ignored

### ⚠️ Security Limitations

**Important**: Understand the scope of protection:

1. **Data Field Not Sanitized**: The `data` field preserves newlines (as per SSE spec). Be cautious when embedding JSON or other structured data.

2. **JSON Serialization**: `toJson()` outputs raw values - do NOT embed resulting JSON directly in HTML/JavaScript without escaping.

3. **Streaming Memory**: When consuming streams, always use streaming APIs (`getStream()`) instead of `response.body` to avoid memory exhaustion.

See [examples/security_examples.nim](examples/security_examples.nim) for details and [SECURITY.md](SECURITY.md) for comprehensive security guide.

## 🏆 Why This Library?

### Focus on SSE

While other HTTP libraries may include basic SSE support, this library is **dedicated to SSE**:

| Feature | This SSE Library | General HTTP Libraries |
|---------|-----------------|------------------------|
| SSE Protocol Support | ✅ Full | ⚠️ Basic |
| Streaming Parser | ✅ Built-in | ❌ DIY |
| Reconnection (Last-Event-ID) | ✅ Automatic | ❌ Manual |
| Security Features | ✅ Comprehensive | ⚠️ Basic |
| Documentation | ✅ Extensive | ⚠️ Minimal |
| Examples | ✅ 13 files | ⚠️ Few |
| Dependencies | ✅ Zero | Varies |

**Complementary, not competitive**: Use this library alongside your favorite HTTP server/client for the best SSE experience.

### Design Philosophy

1. **Framework Agnostic** - Works with any HTTP library
2. **Zero Dependencies** - Pure Nim, no external requirements
3. **Security First** - Built-in protections against common attacks
4. **Performance** - Optimized for high-throughput scenarios
5. **Developer Experience** - Comprehensive docs and examples

## 🧪 Testing

```bash
# Run unit tests
nimble test

# Run all examples
nim c -r examples/run_all.nim

# Run benchmarks
nim c -r -d:release tests/benchmark.nim
```

## 📊 Performance

This library is optimized for high performance with efficient memory usage. Actual results vary by hardware and use case.

### Typical Performance Characteristics

- **Event Creation**: Very fast (typically < 100ns for simple events)
- **Formatting**: Sub-microsecond for simple events
- **Parsing**: High throughput for standard SSE data
- **Memory**: Bounded by buffer size (default: 1MB for parser, 10MB for parse())

### Run Your Own Benchmarks

**Important**: Always benchmark with your specific workload and hardware:

```bash
# Quick benchmark (release mode for accurate results)
nimble bench

# Or run directly
nim c -r -d:release tests/benchmark.nim
```

The benchmark suite tests:
- Event creation speed
- Formatting performance (simple, multiline, large data)
- Parsing throughput
- Round-trip efficiency
- Memory usage for large data (1MB+)

**Note**: Performance numbers in documentation are estimates. Actual performance depends on:
- CPU speed and architecture
- Memory bandwidth
- Nim compiler version and optimization flags
- Event size and complexity

## 🤝 Contributing

Contributions are welcome! Feel free to open issues for bugs, suggestions for improvements, or pull requests with fixes.

## 📝 License

MIT License - See [LICENSE](LICENSE) file for details.

## 🔗 Resources

- [HTML5 SSE Specification](https://html.spec.whatwg.org/multipage/server-sent-events.html)
- [MDN: Using Server-Sent Events](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events)
- [Nim Programming Language](https://nim-lang.org)

---

**Made with ❤️ for the Nim community**

*If you find this library useful, please consider giving it a star ⭐*
