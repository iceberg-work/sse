## SSE Consumer Examples
## =====================
## 
## This file demonstrates how to consume and process incoming SSE streams
## in various scenarios.
## 
## Run with: nim c -r examples/consumer_examples.nim

import ../src/sse
import json, times, tables

# ============================================================
# Scenario 1: Consuming LLM API SSE Stream (OpenAI-style)
# ============================================================
echo "=== Scenario 1: LLM API SSE Stream ==="

# Note: Complete LLM API consumption example moved to http_client_examples.nim
# This section shows the conceptual pattern only

# Example: Conceptual usage pattern
echo "LLM API Stream Consumer Pattern:"
echo "  1. Create HttpClient with SSE headers"
echo "  2. Use getStream() for true streaming"
echo "  3. Feed chunks to SSEParser"
echo "  4. Parse JSON from data field"
echo "  5. Handle [DONE] sentinel"
echo ""

# Example callback handler
echo "Example callback pattern:"
echo "  # Pseudocode:"
echo "  var client = newHttpClient()"
echo "  client.headers = newHttpHeaders({"
echo "    \"Authorization\": \"Bearer YOUR_API_KEY\","
echo "    \"Accept\": \"text/event-stream\""
echo "  })"
echo "  # ⚠️ WARNING: For production, use getStream() instead of response.body"
echo "  let response = client.get(url)"
echo "  var parser = initSSEParser()"
echo "  for line in response.body.splitLines():"
echo "    let events = parser.feed(line & \"\\n\")"
echo "    for evt in events:"
echo "      if evt.data == \"[DONE]\": handleDone()"
echo "      else: processContent(parseJson(evt.data))"
echo ""
echo "See http_client_examples.nim for working HTTP client demo"

# ============================================================
# Scenario 2: Processing SSE Events (Callback-based)
# ============================================================
echo "\n=== Scenario 2: Callback-based Processing ==="

type
  SSEHandler = proc(event: SSEvent) {.closure, gcsafe.}

proc processSSEStream(rawData: string, handler: SSEHandler) =
  ## Process SSE stream with custom handler for each event
  var parser = initSSEParser()
  let events = parser.feed(rawData)
  
  for evt in events:
    handler(evt)

# Example usage
let sampleData = """
data: Hello
event: greeting

data: World
event: greeting

data: Status update
event: status
id: 123
"""

echo "Processing events with callback:"
processSSEStream(sampleData, proc(evt: SSEvent) =
  echo "  Event type: ", evt.event
  echo "  Data: ", evt.data
  if evt.id.len > 0:
    echo "  ID: ", evt.id
  echo "  ---"
)

# ============================================================
# Scenario 3: Filtering and Transforming Events
# ============================================================
echo "\n=== Scenario 3: Filtering and Transforming ==="

type
  EventFilter = proc(evt: SSEvent): bool {.closure, gcsafe.}
  EventTransformer = proc(evt: SSEvent): SSEvent {.closure, gcsafe.}

proc filterAndTransform(rawData: string, 
                        filter: EventFilter,
                        transformer: EventTransformer): string =
  ## Filter and transform SSE events
  result = ""
  var parser = initSSEParser()
  let events = parser.feed(rawData)
  
  for evt in events:
    if filter(evt):
      let transformed = transformer(evt)
      result.add(transformed.format())

# Example: Only process "status" events
let filtered = filterAndTransform(sampleData,
  filter = proc(evt: SSEvent): bool =
    evt.event == "status",
  transformer = proc(evt: SSEvent): SSEvent =
    # Add timestamp to data
    let newData = "[" & $getTime() & "] " & evt.data
    initSSEvent(newData, evt.event, evt.id)
)

echo "Filtered and transformed events:"
echo filtered

# ============================================================
# Scenario 4: Forwarding SSE to Multiple Destinations
# ============================================================
echo "\n=== Scenario 4: Forwarding to Multiple Destinations ==="

type
  SSEForwarder = object
    destinations: seq[SSEHandler]

proc initForwarder(): SSEForwarder =
  SSEForwarder(destinations: @[])

proc addDestination(fwd: var SSEForwarder, handler: SSEHandler) =
  fwd.destinations.add(handler)

proc forward(fwd: SSEForwarder, evt: SSEvent) =
  for dest in fwd.destinations:
    dest(evt)

# Example: Forward to multiple handlers
var forwarder = initForwarder()

# Destination 1: Log to console
forwarder.addDestination(proc(evt: SSEvent) =
  echo "[LOG] ", evt.event, ": ", evt.data
)

# Destination 2: Count events
var eventCount = 0
forwarder.addDestination(proc(evt: SSEvent) =
  inc eventCount
)

# Destination 3: Validate before storing
forwarder.addDestination(proc(evt: SSEvent) =
  if evt.data.len > 0:
    echo "[VALID] Event has valid data"
  else:
    echo "[INVALID] Event has no data"
)

# Process and forward
var parser = initSSEParser()
for evt in parser.feed(sampleData):
  forwarder.forward(evt)

echo "Counted ", eventCount, " events"

# ============================================================
# Scenario 5: Persisting SSE Events to File
# ============================================================
echo "\n=== Scenario 5: Persisting to File ==="

proc persistToFile(rawData: string, filename: string) =
  ## Save SSE events to file for later processing
  var parser = initSSEParser()
  let events = parser.feed(rawData)
  
  var file = open(filename, fmWrite)
  defer: file.close()
  
  for evt in events:
    # Save in JSON Lines format for easy parsing
    let jsonNode = %*{
      "event": evt.event,
      "data": evt.data,
      "id": evt.id,
      "retry": evt.retry,
      "timestamp": $getTime()
    }
    file.writeLine($jsonNode)
  
  echo "Saved ", events.len, " events to ", filename

# Example: Demonstrate persistence without creating actual file
echo "Demonstrating persistence (dry run):"
persistToFile(sampleData, "demo_output.jsonl")

# Clean up the demo file
import std/os
if fileExists("demo_output.jsonl"):
  removeFile("demo_output.jsonl")
  echo "Demo file created and cleaned up successfully"

# ============================================================
# Scenario 6: Batch Processing and Aggregation
# ============================================================
echo "\n=== Scenario 6: Batch Processing ==="

type
  BatchProcessor = object
    batchSize: int
    buffer: seq[SSEvent]
    onBatchReady: proc(batch: seq[SSEvent]) {.closure, gcsafe.}

proc initBatchProcessor(size: int, callback: proc(batch: seq[SSEvent]) {.closure, gcsafe.}): BatchProcessor =
  BatchProcessor(batchSize: size, buffer: @[], onBatchReady: callback)

proc addEvent(bp: var BatchProcessor, evt: SSEvent) =
  bp.buffer.add(evt)
  
  if bp.buffer.len >= bp.batchSize:
    bp.onBatchReady(bp.buffer)
    bp.buffer = @[]

proc flush(bp: var BatchProcessor) =
  if bp.buffer.len > 0:
    bp.onBatchReady(bp.buffer)
    bp.buffer = @[]

# Example: Process in batches of 2
var batchCount = 0
var processor = initBatchProcessor(2, proc(batch: seq[SSEvent]) =
  inc batchCount
  echo "Batch ", batchCount, " (", batch.len, " events):"
  for evt in batch:
    echo "  - ", evt.data
)

var parser2 = initSSEParser()
for evt in parser2.feed(sampleData):
  processor.addEvent(evt)

processor.flush()
echo "Total batches: ", batchCount

# ============================================================
# Scenario 7: Event Deduplication
# ============================================================
echo "\n=== Scenario 7: Deduplication ==="

type
  Deduplicator = object
    seenIds: seq[string]
    maxSize: int

proc initDeduplicator(maxSize = 1000): Deduplicator =
  Deduplicator(seenIds: @[], maxSize: maxSize)

proc isDuplicate(dedup: var Deduplicator, evt: SSEvent): bool =
  if evt.id.len == 0:
    return false  # Can't deduplicate events without ID
  
  if evt.id in dedup.seenIds:
    return true
  
  dedup.seenIds.add(evt.id)
  
  # Trim if too large
  if dedup.seenIds.len > dedup.maxSize:
    dedup.seenIds = dedup.seenIds[dedup.seenIds.len - dedup.maxSize..^1]
  
  return false

# Example
var dedup = initDeduplicator()
let eventsWithDupes = """
data: First
id: 1

data: Second
id: 2

data: Duplicate of First
id: 1

data: Third
id: 3
"""

echo "Processing events with deduplication:"
var parser3 = initSSEParser()
for evt in parser3.feed(eventsWithDupes):
  if dedup.isDuplicate(evt):
    echo "  ✗ Duplicate: ", evt.id
  else:
    echo "  ✓ Unique: ", evt.id, " - ", evt.data

# ============================================================
# Scenario 8: Statistics and Monitoring
# ============================================================
echo "\n=== Scenario 8: Statistics ==="

type
  SSEStats = object
    totalEvents: int
    eventsByType: Table[string, int]
    totalDataSize: int
    startTime: Time

proc initStats(): SSEStats =
  SSEStats(
    totalEvents: 0,
    eventsByType: initTable[string, int](),
    totalDataSize: 0,
    startTime: getTime()
  )

proc recordEvent(stats: var SSEStats, evt: SSEvent) =
  inc stats.totalEvents
  stats.totalDataSize += evt.data.len
  
  let eventType = if evt.event.len > 0: evt.event else: "message"
  stats.eventsByType[eventType] = stats.eventsByType.getOrDefault(eventType, 0) + 1

proc printStats(stats: SSEStats) =
  echo "Statistics:"
  echo "  Total events: ", stats.totalEvents
  echo "  Total data size: ", stats.totalDataSize, " bytes"
  echo "  Events by type:"
  for key, count in stats.eventsByType.pairs:
    echo "    ", key, ": ", count
  echo "  Duration: ", getTime() - stats.startTime

# Example
var stats = initStats()
var parser4 = initSSEParser()
for evt in parser4.feed(sampleData):
  stats.recordEvent(evt)

printStats(stats)

echo "\n=== All consumer scenarios demonstrated! ==="
echo "\nNote: These are conceptual examples. Actual implementation"
echo "may require adjustments based on your specific use case."
