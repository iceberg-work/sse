# Package

name          = "server_sent_events"
version       = "0.1.2"
author        = "iceberg-work"
description   = "A dedicated Server-Sent Events (SSE) library for Nim - framework agnostic, production-ready."
license       = "MIT"
srcDir        = "src"

# Dependencies

requires "nim >= 2.0.0"

# Tasks

task test, "Run tests":
  exec "nim c -r tests/test_sse.nim"

task examples, "Run all examples":
  exec "nim c -r examples/run_all.nim"

task docs, "Generate documentation":
  exec "nim doc --index:on --outdir:docs src/sse.nim"

task bench, "Run performance benchmarks":
  exec "nim c -r -d:release tests/benchmark.nim"

task all, "Run tests and benchmarks":
  exec "nim c -r tests/test_sse.nim"
  exec "nim c -r -d:release tests/benchmark.nim"
