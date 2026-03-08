## Run All Examples
## =================
## 
## This script compiles and runs all example files.
## Run with: nim c -r examples/run_all.nim

import std/[os, osproc]

let exampleDir = getCurrentDir() / "examples"
let examples = [
  "quick_start.nim",
  "basic_usage.nim",
  "ssevent_examples.nim",
  "parser_examples.nim",
  "validation_examples.nim",
  "json_examples.nim",
  "advanced_examples.nim",
  "security_examples.nim",
  "usage_patterns.nim",
  "consumer_examples.nim",
  "http_server_examples.nim",
  "http_client_examples.nim",
  "web_framework_integration.nim"
]

echo "========================================"
echo "Running all SSE examples"
echo "========================================"
echo ""

var successCount = 0
var failCount = 0

for example in examples:
  let examplePath = exampleDir / example
  echo "----------------------------------------"
  echo "Running: ", example
  echo "----------------------------------------"
  
  let result = execCmdEx("nim c -r --hints:off " & examplePath.quoteShell)
  if result.exitCode == 0:
    echo "✓ ", example, " - PASSED"
    inc successCount
  else:
    echo "✗ ", example, " - FAILED"
    echo result.output
    inc failCount
  
  echo ""

echo "========================================"
echo "Summary: ", successCount, " passed, ", failCount, " failed"
echo "========================================"

if failCount > 0:
  quit(1)
