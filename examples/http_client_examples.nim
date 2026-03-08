## HTTP Client Examples
## ====================
## 
## This file demonstrates how to consume SSE streams using httpclient.
## These examples show real HTTP client patterns for consuming SSE streams.
## 
## ⚠️ SECURITY WARNING:
## The examples below using response.body are for DEMONSTRATION ONLY.
## In production, ALWAYS use streaming APIs (getStream/reqStream) to avoid
## loading entire responses into memory, which can lead to DoS vulnerabilities.
## 
## Run with: nim c -r examples/http_client_examples.nim

import ../src/sse
import pure/httpclient, strutils, json, times

# ============================================================
# Example 1: Basic SSE Stream Consumption
# ============================================================
echo "=== Example 1: Basic SSE Stream Consumption ==="

echo """
# ⚠️ WARNING: This example uses response.body which loads entire response into memory.
# DO NOT use this pattern in production for large or long-running streams.
# Use the streaming pattern shown in Example 8 instead.

# Basic SSE Stream Consumption using httpclient
import httpclient, sse

proc consumeSSEStream(url: string) =
  var client = newHttpClient()
  client.headers = newHttpHeaders({
    "Accept": "text/event-stream",
    "Cache-Control": "no-cache"
  })
  
  let response = client.get(url)
  var parser = initSSEParser()
  
  # ⚠️ WARNING: response.body loads entire response into memory
  # Only safe for small, finite streams
  for line in response.body.splitLines():
    let events = parser.feed(line & "\\n")
    for evt in events:
      echo "Received: " & evt.data

consumeSSEStream("http://localhost:8080/events")
"""

echo "HTTP Client configured for SSE:"
echo "  Accept: text/event-stream"
echo "  Cache-Control: no-cache"
echo ""
echo "Pattern:"
echo "  1. Create HttpClient with SSE headers"
echo "  2. Use get() or getStream() for streaming"
echo "  3. Feed response body to SSEParser"
echo "  4. Process complete events"
echo ""
echo "⚠️ SECURITY: For production use, see Example 8 for proper streaming pattern"
echo ""

# ============================================================
# Example 2: Streaming with Callbacks
# ============================================================
echo "=== Example 2: Streaming with Callbacks ==="

type
  SSECallback = proc(event: SSEvent) {.closure, gcsafe.}
  ErrorCallback = proc(error: string) {.closure, gcsafe.}
  DoneCallback = proc() {.closure, gcsafe.}

echo """
# Callback-based SSE streaming

import httpclient, sse

type
  SSECallback = proc(event: SSEvent) {.closure, gcsafe.}
  ErrorCallback = proc(error: string) {.closure, gcsafe.}
  DoneCallback = proc() {.closure, gcsafe.}

proc streamSSE(
  url: string,
  onEvent: SSECallback,
  onError: ErrorCallback,
  onDone: DoneCallback
) =
  var client = newHttpClient()
  client.headers = newHttpHeaders({"Accept": "text/event-stream"})
  
  try:
    let response = client.get(url)
    var parser = initSSEParser()
    
    for line in response.body.splitLines():
      let events = parser.feed(line & "\\n")
      for evt in events:
        onEvent(evt)
    
    onDone()
  except:
    onError("Connection failed")

# Usage
streamSSE("http://localhost:8080/events",
  onEvent = proc(evt: SSEvent) =
    echo "Event: " & evt.event & ", Data: " & evt.data,
  onError = proc(err: string) =
    echo "Error: " & err,
  onDone = proc() =
    echo "Stream completed"
)
"""

echo "Callback-based streaming pattern:"
echo "  onEvent: Called for each complete SSE event"
echo "  onError: Called on connection/parsing error"
echo "  onDone: Called when stream ends"
echo ""

# ============================================================
# Example 3: OpenAI-Style LLM API Consumption
# ============================================================
echo "=== Example 3: OpenAI-Style LLM API ==="

type
  ChatChunk = object
    content: string
    finishReason: string
  
  LLMStreamHandler = proc(chunk: ChatChunk, done: bool) {.closure, gcsafe.}

proc consumeOpenAIStream(
  url: string,
  apiKey: string,
  prompt: string,
  onChunk: LLMStreamHandler
) =
  ## Consume OpenAI-style SSE stream
  ## 
  ## Parameters:
  ## * url: API endpoint (e.g., https://api.openai.com/v1/chat/completions)
  ## * apiKey: API key for authentication
  ## * prompt: User prompt to send
  ## * onChunk: Called for each content chunk
  
  var client = newHttpClient()
  client.headers = newHttpHeaders({
    "Authorization": "Bearer " & apiKey,
    "Content-Type": "application/json",
    "Accept": "text/event-stream"
  })
  
  # Request body - build JSON manually
  let requestBody = """{"model":"gpt-3.5-turbo","messages":[{"role":"user","content":"%s"}],"stream":true}""" % prompt
  
  try:
    var parser = initSSEParser()
    
    # In real usage:
    # let response = client.post(url, requestBody)
    # let stream = response.getStream()
    # 
    # var buffer = ""
    # while true:
    #   let chunk = stream.readChunk(1024)
    #   if chunk.len == 0: break
    #   buffer.add(chunk)
    #   
    #   # Process SSE events
    #   let events = parser.feed(buffer)
    #   for evt in events:
    #     if evt.data == "[DONE]":
    #       onChunk(ChatChunk(content: "", finishReason: "stop"), true)
    #     else:
    #       try:
    #         let json = parseJson(evt.data)
    #         let choices = json["choices"]
    #         if choices.len > 0:
    #           let delta = choices[0]["delta"]
    #           let content = delta.getOrDefault("content", newJString("")).getStr("")
    #           let finishReason = delta.getOrDefault("finish_reason", newJNull())
    #           let reason = if finishReason.kind == JString: finishReason.getStr("") else: ""
    #           if content.len > 0:
    #             onChunk(ChatChunk(content: content, finishReason: reason), false)
    #       except:
    #         discard
    #   buffer = ""
    
    echo "OpenAI stream consumption pattern:"
    echo "  1. Set Authorization: Bearer <key>"
    echo "  2. Set Content-Type: application/json"
    echo "  3. Send JSON body with stream: true"
    echo "  4. Parse SSE events with JSON data"
    echo "  5. Handle [DONE] sentinel"
    echo "  6. Extract content from choices[0].delta.content"
  
  except:
    onChunk(ChatChunk(content: "[Error: Connection failed]", finishReason: "error"), true)

# Example usage (not executed without valid API)
echo "OpenAI-style consumption pattern demonstrated"
echo "Expected SSE format:"
echo "  data: {\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}"
echo "  data: {\"choices\":[{\"delta\":{\"content\":\" World\"}}]}"
echo "  data: [DONE]"
echo ""

# ============================================================
# Example 4: Reconnection with Last-Event-ID
# ============================================================
echo "=== Example 4: Reconnection with Last-Event-ID ==="

proc connectWithReconnect(url: string, lastEventId: string) =
  ## Connect to SSE stream with reconnection support
  ## 
  ## Parameters:
  ## * url: SSE endpoint URL
  ## * lastEventId: Last received event ID (empty for first connection)
  
  var client = newHttpClient()
  client.headers = newHttpHeaders({
    "Accept": "text/event-stream"
  })
  
  if lastEventId.len > 0:
    client.headers.add("Last-Event-ID", lastEventId)
    echo "Reconnecting with Last-Event-ID: " & lastEventId
  else:
    echo "Initial connection"
  
  try:
    var parser = initSSEParser()
    
    # In real usage:
    # let stream = client.getStream(url)
    # while true:
    #   let chunk = stream.readChunk(1024)
    #   if chunk.len == 0: break
    #   let events = parser.feed(chunk)
    #   for evt in events:
    #     if evt.id.len > 0:
    #       lastEventId = evt.id  # Save for reconnection
    #     processEvent(evt)
    
    echo "Reconnection pattern:"
    echo "  1. Save last event ID on each event"
    echo "  2. On disconnect, reconnect with Last-Event-ID header"
    echo "  3. Server sends missed events"
    echo "  4. Continue from where left off"
  
  except:
    echo "Connection failed - would retry after delay"

# Simulate reconnection
connectWithReconnect("http://localhost:8080/events", "")
connectWithReconnect("http://localhost:8080/events", "event-5")
echo ""

# ============================================================
# Example 5: Event Filtering and Transformation
# ============================================================
echo "=== Example 5: Event Filtering and Transformation ==="

type
  EventFilter = proc(evt: SSEvent): bool {.closure, gcsafe.}
  EventTransformer = proc(evt: SSEvent): SSEvent {.closure, gcsafe.}

proc createFilteredConsumer(
  filter: EventFilter,
  transformer: EventTransformer
): SSECallback =
  ## Create event consumer with filtering and transformation
  result = proc(evt: SSEvent) =
    if filter(evt):
      let transformed = transformer(evt)
      echo "  Processed: " & transformed.data

# Example: Only process events with specific type
let filter = proc(evt: SSEvent): bool =
  evt.event == "update" or evt.event == ""

let transformer = proc(evt: SSEvent): SSEvent =
  # Add timestamp to data
  initSSEvent("[" & $getTime().toUnix() & "] " & evt.data, evt.event, evt.id)

let consumer = createFilteredConsumer(filter, transformer)

# Simulate events
let testEvents = @[
  initSSEvent("First", "status"),
  initSSEvent("Second", "update"),
  initSSEvent("Third", "update")
]

echo "Filtering and transformation:"
for evt in testEvents:
  consumer(evt)
echo ""

# ============================================================
# Example 6: Connection Health Monitoring
# ============================================================
echo "=== Example 6: Connection Health Monitoring ==="

type
  ConnectionHealth = object
    lastHeartbeatTime: Time
    maxHeartbeatInterval: Duration
    reconnectCount: int
    maxReconnects: int

proc initHealth(maxReconnects = 3): ConnectionHealth =
  ConnectionHealth(
    lastHeartbeatTime: getTime(),
    maxHeartbeatInterval: initDuration(seconds = 30),
    reconnectCount: 0,
    maxReconnects: maxReconnects
  )

proc checkHealth(health: var ConnectionHealth): bool =
  ## Check if connection is healthy
  let now = getTime()
  let sinceLastHeartbeat = now - health.lastHeartbeatTime
  
  if sinceLastHeartbeat > health.maxHeartbeatInterval:
    echo "  ⚠ No heartbeat for " & $sinceLastHeartbeat.inSeconds & "s"
    if health.reconnectCount < health.maxReconnects:
      inc health.reconnectCount
      echo "  Attempting reconnect (" & $health.reconnectCount & "/" & $health.maxReconnects & ")"
      result = false
    else:
      echo "  ✗ Max reconnects exceeded"
      result = false
  else:
    result = true

proc recordHeartbeat(health: var ConnectionHealth) =
  health.lastHeartbeatTime = getTime()
  health.reconnectCount = 0

var health = initHealth()
echo "Health monitor initialized"
echo "Max heartbeat interval: 30s"
echo "Max reconnects: 3"

# Simulate heartbeat
recordHeartbeat(health)
echo "Heartbeat recorded"

# Check health
if checkHealth(health):
  echo "Connection healthy ✓"
else:
  echo "Connection unhealthy ✗"
echo ""

# ============================================================
# Example 7: Buffering and Batching
# ============================================================
echo "=== Example 7: Buffering and Batching ==="

type
  BatchConsumer = object
    buffer: seq[SSEvent]
    batchSize: int
    flushCallback: proc(batch: seq[SSEvent]) {.closure, gcsafe.}

proc initBatchConsumer(
  size: int,
  onFlush: proc(batch: seq[SSEvent]) {.closure, gcsafe.}
): BatchConsumer =
  BatchConsumer(buffer: @[], batchSize: size, flushCallback: onFlush)

proc add(bc: var BatchConsumer, evt: SSEvent) =
  bc.buffer.add(evt)
  if bc.buffer.len >= bc.batchSize:
    bc.flushCallback(bc.buffer)
    bc.buffer = @[]

proc flush(bc: var BatchConsumer) =
  if bc.buffer.len > 0:
    bc.flushCallback(bc.buffer)
    bc.buffer = @[]

var batchConsumer = initBatchConsumer(3, proc(batch: seq[SSEvent]) =
  echo "  Flushed batch of " & $batch.len & " events:"
  for evt in batch:
    echo "    - " & evt.data
)

echo "Batching events (batch size: 3):"
for i in 1..7:
  batchConsumer.add(initSSEvent("Event " & $i))

batchConsumer.flush()
echo ""

# ============================================================
# Example 8: Production-Ready Streaming Pattern
# ============================================================
echo "=== Example 8: Production-Ready Streaming ==="

echo """
# ✅ RECOMMENDED: Proper streaming pattern for production use
# This pattern uses getStream() to process data in chunks without
# loading the entire response into memory.

import httpclient, sse, times

proc streamSSE(url: string, maxEvents = 10) =
  var client = newHttpClient()
  client.headers = newHttpHeaders({
    "Accept": "text/event-stream",
    "Cache-Control": "no-cache"
  })
  
  try:
    # Use getStream for memory-efficient streaming
    let stream = client.getStream(url)
    var parser = initSSEParser()
    var buffer = ""
    var eventCount = 0
    
    # Read in chunks
    while true:
      let chunk = stream.readChunk(1024)
      if chunk.len == 0:
        break
      
      buffer.add(chunk)
      
      # Process complete events
      let events = parser.feed(buffer)
      for evt in events:
        echo "Event ", eventCount, ": ", evt.data
        inc eventCount
        
        if eventCount >= maxEvents:
          return
      
      # Clear processed data
      buffer = ""
  
  except IOError, OSError as e:
    echo "Connection error: ", e.msg
  except SSEError as e:
    echo "SSE parsing error: ", e.msg
  finally:
    client.close()

# Usage:
# streamSSE("http://localhost:8080/events")
"""

echo "✅ Production streaming pattern:"
echo "  1. Use getStream() instead of get()"
echo "  2. Read data in chunks (e.g., 1024 bytes)"
echo "  3. Feed chunks to parser incrementally"
echo "  4. Clear buffer after processing"
echo "  5. Handle IOError/OSError for connection issues"
echo "  6. Handle SSEError for parsing errors"
echo "  7. Always close client in finally block"
echo ""

# ============================================================
# Example 9: Complete Client Example (Conceptual)
# ============================================================
echo "=== Example 9: Complete Client Pattern ==="

echo """
# Complete SSE Client Example (Pseudocode)

import httpclient, sse, times

type
  SSEClient = object
    url: string
    client: HttpClient
    parser: SSEParser
    lastEventId: string
    reconnectDelay: int
    maxReconnects: int
    reconnectCount: int
  
  SSEHandler = proc(event: SSEvent) {.closure, gcsafe.}

proc initSSEClient(url: string): SSEClient =
  SSEClient(
    url: url,
    client: newHttpClient(),
    parser: initSSEParser(),
    reconnectDelay: 1000,
    maxReconnects: 5,
    reconnectCount: 0
  )

proc connect(client: var SSEClient, handler: SSEHandler) =
  client.client.headers = newHttpHeaders({"Accept": "text/event-stream"})
  if client.lastEventId.len > 0:
    client.client.headers.add("Last-Event-ID", client.lastEventId)
  
  try:
    let stream = client.client.getStream(client.url)
    while true:
      let chunk = stream.readChunk(1024)
      if chunk.len == 0: break
      
      let events = client.parser.feed(chunk)
      for evt in events:
        if evt.id.len > 0:
          client.lastEventId = evt.id
        handler(evt)
  
  except:
    if client.reconnectCount < client.maxReconnects:
      sleep(client.reconnectDelay)
      inc client.reconnectCount
      client.connect(handler)

# Usage
var client = initSSEClient("http://localhost:8080/events")
client.connect(proc(evt: SSEvent) =
  echo "Received: " & evt.data
)
"""

echo ""
echo "=== HTTP Client examples completed! ==="
echo ""
echo "⚠️ IMPORTANT:"
echo "  - Examples 1-7: Use response.body for DEMONSTRATION ONLY"
echo "  - Example 8: Use getStream() for PRODUCTION (recommended)"
echo "  - Example 9: Complete client pattern with reconnection"
echo ""
echo "Note: These examples demonstrate patterns. To test with"
echo "a real server, uncomment the actual HTTP calls and point"
echo "to a running SSE endpoint."
