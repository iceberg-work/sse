discard """
  cmd:      "nim c -r -d:release $file"
  action:   "run"
"""

import std/[times, strformat, strutils]
import ../src/sse

proc getMemUsage(): int =
  when declared(getOccupiedMem):
    result = getOccupiedMem()
  else:
    result = 0

proc formatBytes(bytes: int): string =
  const units = ["B", "KB", "MB", "GB"]
  var size = float(bytes)
  var unitIdx = 0
  while size >= 1024 and unitIdx < units.len - 1:
    size /= 1024
    inc unitIdx
  fmt"{size:.2f} {units[unitIdx]}"

proc benchmark(name: string, iterations: int, op: proc()) =
  let start = cpuTime()
  for i in 1..iterations:
    op()
  let elapsed = cpuTime() - start
  let opsPerSec = float(iterations) / elapsed
  echo fmt"{name}: {iterations} iterations in {elapsed:.4f}s ({opsPerSec:.0f} ops/s)"

proc benchmarkWithMemory(name: string, iterations: int, op: proc()) =
  GC_fullCollect()
  let memBefore = getMemUsage()
  let start = cpuTime()
  for i in 1..iterations:
    op()
  let elapsed = cpuTime() - start
  GC_fullCollect()
  let memAfter = getMemUsage()
  let opsPerSec = float(iterations) / elapsed
  let memDelta = memAfter - memBefore
  echo fmt"{name}: {iterations} iterations in {elapsed:.4f}s ({opsPerSec:.0f} ops/s)"
  echo fmt"  Memory: before={formatBytes(memBefore)}, after={formatBytes(memAfter)}, delta={formatBytes(memDelta)}"

proc main() =
  echo repeat("=", 60)
  echo "SSE Library Performance Benchmark"
  echo repeat("=", 60)
  
  benchmark("initSSEvent", 1_000_000, proc() =
    discard initSSEvent("hello world", "message", "123", 5000)
  )
  
  let evt = initSSEvent("hello world", "message", "123", 5000)
  benchmark("format (simple)", 1_000_000, proc() =
    discard evt.format()
  )
  
  let multiLineEvt = initSSEvent("line1\nline2\nline3\nline4\nline5", "message", "id", 5000)
  benchmark("format (multiline)", 500_000, proc() =
    discard multiLineEvt.format()
  )
  
  var largeData = ""
  for i in 1..1000:
    largeData.add("x")
  let largeEvt = initSSEvent(largeData, "message", "id")
  benchmark("format (1KB data)", 100_000, proc() =
    discard largeEvt.format()
  )
  
  let simpleRaw = "data: hello\n\n"
  benchmark("parse (simple)", 1_000_000, proc() =
    discard parse(simpleRaw)
  )
  
  let multiRaw = "event: message\ndata: line1\ndata: line2\nid: 123\nretry: 5000\n\n"
  benchmark("parse (full)", 500_000, proc() =
    discard parse(multiRaw)
  )
  
  var multiEventsRaw = ""
  for i in 1..10:
    multiEventsRaw.add(fmt"data: event{i}" & "\n\n")
  benchmark("parse (10 events)", 100_000, proc() =
    discard parse(multiEventsRaw)
  )
  
  let original = initSSEvent("test data", "message", "123", 5000)
  benchmark("round-trip", 500_000, proc() =
    discard parse(original.format())
  )
  
  echo ""
  echo repeat("-", 60)
  echo "Large Data Benchmarks (with memory tracking)"
  echo repeat("-", 60)
  
  let largeData1MB = "x".repeat(1024 * 1024)
  let largeEvt1MB = initSSEvent(largeData1MB)
  benchmarkWithMemory("format (1MB data)", 100, proc() =
    discard largeEvt1MB.format()
  )
  
  let largeRaw1MB = "data: " & largeData1MB & "\n\n"
  benchmarkWithMemory("parse (1MB data)", 100, proc() =
    discard parse(largeRaw1MB)
  )
  
  benchmarkWithMemory("feed (1MB chunk)", 100, proc() =
    var p = initSSEParser(maxBufferSize = 2 * 1024 * 1024)
    discard p.feed(largeRaw1MB)
  )
  
  var multiLineDataLarge = ""
  for i in 1..1000:
    multiLineDataLarge.add("line " & $i & "\n")
  multiLineDataLarge = multiLineDataLarge[0..^2]
  let multiLineEvtLarge = initSSEvent(multiLineDataLarge)
  benchmarkWithMemory("format (1000 lines)", 1000, proc() =
    discard multiLineEvtLarge.format()
  )
  
  var manyEventsRaw = ""
  for i in 1..100:
    manyEventsRaw.add(fmt"data: event{i}" & "\n\n")
  benchmarkWithMemory("parse (100 events)", 10_000, proc() =
    discard parse(manyEventsRaw)
  )
  
  echo ""
  echo repeat("=", 60)
  echo "Benchmark complete!"

when isMainModule:
  main()
