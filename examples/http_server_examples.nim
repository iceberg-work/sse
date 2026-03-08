## HTTP Server Examples
## ====================
## 
## This file demonstrates SSE server implementation patterns.
## These examples show the protocol-level integration without framework dependencies.
## 
## Note: Uses asynchttpserver from Nim standard library for actual server code.
## 
## Run with: nim c -r examples/http_server_examples.nim

import ../src/sse
import strutils, times, json

# ============================================================
# Example 1: Minimal SSE Server
# ============================================================
echo "=== Example 1: Minimal SSE Server Pattern ==="

echo """
# Minimal SSE Server using asynchttpserver

import asynchttpserver, asyncdispatch, sse

proc sendSSEHeaders(response: var asyncdispatch.Response) =
  response.headers["Content-Type"] = "text/event-stream"
  response.headers["Cache-Control"] = "no-cache"
  response.headers["Connection"] = "keep-alive"

proc handleSSE(request: asyncdispatch.Request) {.async.} =
  var response = asyncdispatch.Response()
  sendSSEHeaders(response)
  
  # Send initial connection confirmation
  let connectEvt = initSSEvent("connected", "status", "0")
  await response.send(connectEvt.format())
  
  # Send events
  for i in 1..3:
    let evt = initSSEvent("Message " & $i, "message", $i)
    await response.send(evt.format())
    sleep(100)

var server = newAsyncHttpServer()
server.listen(Port(8080), "http://localhost:8080/events", handleSSE)
"""

echo "Required SSE headers:"
echo "  Content-Type: text/event-stream"
echo "  Cache-Control: no-cache"
echo "  Connection: keep-alive"
echo "  Access-Control-Allow-Origin: * (for browser clients)"
echo ""

# ============================================================
# Example 2: Server with Event ID Tracking
# ============================================================
echo "=== Example 2: Server with Event ID Tracking ==="

type
  EventStore = object
    events: seq[SSEvent]
    nextId: int

proc initEventStore(): EventStore =
  EventStore(events: @[], nextId: 1)

proc addEvent(store: var EventStore, data: string, eventType = "message") =
  let evt = initSSEvent(data, eventType, $store.nextId)
  store.events.add(evt)
  inc store.nextId

proc getEventsSince(store: EventStore, lastId: string): seq[SSEvent] =
  let lastIdInt = if lastId.len > 0: parseInt(lastId) else: 0
  result = @[]
  for evt in store.events:
    if evt.id.len > 0:
      let evtId = parseInt(evt.id)
      if evtId > lastIdInt:
        result.add(evt)

var store = initEventStore()
store.addEvent("First message")
store.addEvent("Second message", "update")
store.addEvent("Third message")

echo "Event store created with " & $store.events.len & " events"
echo "Events:"
for evt in store.events:
  echo "  ID: " & evt.id & ", Type: " & evt.event & ", Data: " & evt.data

# Simulate reconnection scenario
echo ""
echo "Reconnection support:"
echo "  Client sends Last-Event-ID header on reconnect"
echo "  Server uses getEventsSince() to find missed events"
echo "  Example: Client last received ID 1, server sends ID 2, 3"
echo ""

# ============================================================
# Example 4: Broadcast to Multiple Clients
# ============================================================
echo "=== Example 4: Broadcast Pattern ==="

type
  ClientConnection = ref object
    id: string
    connected: bool
  
  BroadcastHub = ref object
    clients: seq[ClientConnection]
    nextClientId: int

proc initBroadcastHub(): BroadcastHub =
  BroadcastHub(clients: @[], nextClientId: 1)

proc addClient(hub: BroadcastHub): ClientConnection =
  let conn = ClientConnection(
    id: "client_" & $hub.nextClientId,
    connected: true
  )
  hub.clients.add(conn)
  inc hub.nextClientId
  result = conn

proc removeClient(hub: BroadcastHub, conn: ClientConnection) =
  conn.connected = false
  var i = 0
  while i < hub.clients.len:
    if hub.clients[i].id == conn.id:
      hub.clients.delete(i)
    else:
      inc i

proc broadcast(hub: BroadcastHub, message: string, eventType = "message"): string =
  ## Returns formatted event for broadcasting
  let evt = initSSEvent(message, eventType)
  result = evt.format()

var hub = initBroadcastHub()
let client1 = hub.addClient()
let client2 = hub.addClient()

echo "Broadcast hub created with 2 clients"
echo "Pattern:"
echo "  1. Maintain list of connected clients"
echo "  2. On message, format event once"
echo "  3. Send to all connected clients"
echo "  4. Remove disconnected clients"
echo ""
echo "Broadcast message:"
echo broadcast(hub, "Hello all!", "broadcast")

# ============================================================
# Example 5: Structured Data (JSON in SSE)
# ============================================================
echo "=== Example 5: JSON Payload in SSE ==="

type
  ChatMessage = object
    user: string
    content: string
    timestamp: int64

proc toSSEvent(msg: ChatMessage): SSEvent =
  let jsonNode = %*{
    "user": msg.user,
    "content": msg.content,
    "timestamp": msg.timestamp
  }
  initSSEvent($jsonNode, "chat_message")

let chatMsg = ChatMessage(
  user: "Alice",
  content: "Hello, World!",
  timestamp: getTime().toUnix()
)

let sseEvt = chatMsg.toSSEvent()
echo "Chat message converted to SSE:"
echo sseEvt.format()

# Parse back
let parsedJson = parseJson(sseEvt.data)
echo "Parsed back:"
echo "  User: " & parsedJson["user"].getStr()
echo "  Content: " & parsedJson["content"].getStr()
echo ""

# ============================================================
# Example 6: Rate Limiting and Throttling
# ============================================================
echo "=== Example 6: Rate Limiting Pattern ==="

type
  RateLimiter = object
    maxEventsPerSecond: int
    eventCount: int
    lastResetTime: Time

proc initRateLimiter(maxPerSec = 10): RateLimiter =
  RateLimiter(
    maxEventsPerSecond: maxPerSec,
    eventCount: 0,
    lastResetTime: getTime()
  )

proc canSend(limiter: var RateLimiter): bool =
  let now = getTime()
  if (now - limiter.lastResetTime).inSeconds >= 1:
    limiter.eventCount = 0
    limiter.lastResetTime = now
  
  if limiter.eventCount < limiter.maxEventsPerSecond:
    inc limiter.eventCount
    result = true
  else:
    result = false

var limiter = initRateLimiter(5)
echo "Rate limiter: 5 events/second"
for i in 1..7:
  if limiter.canSend():
    echo "  Event " & $i & ": ✓ Sent"
  else:
    echo "  Event " & $i & ": ✗ Rate limited"
echo ""

# ============================================================
# Example 7: Error Handling and Client Disconnect
# ============================================================
echo "=== Example 7: Error Handling ==="

echo """
# Error handling pattern for asynchttpserver

proc safeSendSSE(response: var Response, event: SSEvent): bool =
  ## Safely send SSE event, handling client disconnect
  try:
    await response.send(event.format())
    result = true
  except IOError, OSError:
    echo "Client disconnected"
    result = false
  except:
    echo "Unknown error sending SSE"
    result = false
"""

echo "Error handling pattern:"
echo "  Wrap response.send() in try-except"
echo "  Catch IOError/OSError for disconnects"
echo "  Clean up disconnected clients"
echo ""

# ============================================================
# Example 8: Complete Server Example
# ============================================================
echo "=== Example 8: Complete Server Pattern ==="

echo """
# Complete SSE Server Example using asynchttpserver

import asynchttpserver, asyncdispatch, sse, times

proc sendSSEHeaders(response: var Response) =
  response.headers["Content-Type"] = "text/event-stream"
  response.headers["Cache-Control"] = "no-cache"
  response.headers["Connection"] = "keep-alive"
  response.headers["Access-Control-Allow-Origin"] = "*"

proc handleEvents(request: Request) {.async.} =
  var response = Response()
  sendSSEHeaders(response)
  
  # Send connection confirmation
  let connectEvt = initSSEvent("connected", "status", "0")
  await response.send(connectEvt.format())
  
  # Send events
  for i in 1..10:
    let evt = initSSEvent("Message " & $i, "update", $i)
    if not await safeSendSSE(response, evt):
      break  # Client disconnected
    sleep(1000)

proc safeSendSSE(response: var Response, event: SSEvent): Future[bool] {.async.} =
  try:
    await response.send(event.format())
    result = true
  except IOError, OSError:
    result = false

var server = newAsyncHttpServer()
server.listen(Port(8080), handleEvents)
runForever()
"""

echo "See http_client_examples.nim for client-side consumption"
echo ""
echo "=== HTTP Server examples completed! ==="
echo ""
echo "Note: These examples demonstrate patterns."
echo "To create a working server, adapt these patterns"
echo "using asynchttpserver from Nim standard library."
