# SSE Library Examples

This directory contains executable examples for the SSE (Server-Sent Events) library.

## Quick Start

New to SSE? Start here:

```bash
# 5-minute quick start
nim c -r examples/quick_start.nim

# Then explore more examples
nim c -r examples/basic_usage.nim
```

All examples can be run with:

```bash
nim c -r examples/<filename>.nim
```

## Example Files

### Getting Started

| File | Description | Time | 
|------|-------------|------|
| [`quick_start.nim`](quick_start.nim) | **Start here!** 5-minute introduction | 5 min |
| [`basic_usage.nim`](basic_usage.nim) | Core API fundamentals | 10 min |

### Core Examples

| File | Description | Topics |
|------|-------------|--------|
| [`basic_usage.nim`](basic_usage.nim) | Basic library usage | Create, format, parse events |
| [`ssevent_examples.nim`](ssevent_examples.nim) | SSEvent comprehensive examples | Initialization, formatting, parsing, comparison |
| [`parser_examples.nim`](parser_examples.nim) | Streaming parser examples | Incremental parsing, buffer management, error handling |
| [`validation_examples.nim`](validation_examples.nim) | Validation functions | Syntax validation, strict validation |
| [`json_examples.nim`](json_examples.nim) | JSON serialization | toJson, fromJson, type safety |
| [`advanced_examples.nim`](advanced_examples.nim) | Advanced usage patterns | Large data, edge cases, streaming |
| [`security_examples.nim`](security_examples.nim) | Security features | DoS protection, field injection prevention, retry validation |
| [`usage_patterns.nim`](usage_patterns.nim) | Common usage patterns | Event creation, streaming, parsing, custom types |
| [`consumer_examples.nim`](consumer_examples.nim) | SSE consumer patterns | Receiving, processing, forwarding, persisting |

### HTTP Integration Examples

| File | Description | Topics |
|------|-------------|--------|
| [`http_server_examples.nim`](http_server_examples.nim) | HTTP server implementation | std/httpserver, broadcasting, reconnection |
| [`http_client_examples.nim`](http_client_examples.nim) | HTTP client consumption | Streaming, LLM APIs, reconnection, health monitoring |
| [`web_framework_integration.nim`](web_framework_integration.nim) | Protocol usage guide | Integration patterns, headers, error handling |

## Running Examples

### Run All Examples (Recommended)

The easiest way to run all examples is to use the provided script:

```bash
nim c -r examples/run_all.nim
```

This will compile and run all example files and show a summary.

### Run a Single Example

```bash
# Basic usage
nim c -r examples/basic_usage.nim

# SSEvent examples
nim c -r examples/ssevent_examples.nim

# Parser examples
nim c -r examples/parser_examples.nim

# Validation examples
nim c -r examples/validation_examples.nim

# JSON examples
nim c -r examples/json_examples.nim

# Advanced examples
nim c -r examples/advanced_examples.nim
```

## Example Categories

### 1. Basic Usage (`basic_usage.nim`)
- Creating events with `initSSEvent()`
- Formatting events with `format()`
- Parsing raw SSE data with `parse()`
- Heartbeat/comment formatting

### 2. SSEvent Operations (`ssevent_examples.nim`)
- Basic and full initialization
- Formatting with various options
- Multiline data handling
- Line ending normalization
- Parsing different SSE formats
- String representation
- Event comparison

### 3. Streaming Parser (`parser_examples.nim`)
- Parser initialization
- Custom buffer sizes
- Chunked data processing
- Event splitting across chunks
- LastEventId tracking
- Parser reset
- Buffer overflow protection
- Empty feed handling

### 4. Validation (`validation_examples.nim`)
- `validateSyntax()` - Basic syntax validation
- `validateStrict()` - Strict field validation
- `validate()` - Alias for validateSyntax
- Invalid retry value detection
- Unknown field detection
- Real-world validation scenarios

### 5. JSON Support (`json_examples.nim`)
- `toJson()` - Convert SSEvent to JSON
- `fromJson()` - Convert JSON to SSEvent
- Type safety and mismatch handling
- Missing fields handling
- Round-trip conversion
- Pretty printing

### 6. Advanced Patterns (`advanced_examples.nim`)
- Large data handling (1MB+)
- Multiline data with many lines
- Processing many small events
- Round-trip format/parse
- Streaming with large chunks
- Comment handling
- Line ending normalization
- Colon handling variations
- Empty and edge cases
- Retry value edge cases
- Buffer management
- Multiple events parsing

## Code Structure

Each example file follows this structure:

```nim
## Example File Description
## ========================
## 
## Run with: nim c -r examples/<filename>.nim

import ../src/sse

# ============================================================
# Example 1: Example Title
# ============================================================
echo "=== Example 1: Example Title ==="
# Example code here
```

## Extending Examples

To add new examples:

1. Create a new `.nim` file in the `examples/` directory
2. Follow the existing structure with clear section headers
3. Include descriptive comments
4. Add expected output in comments
5. Update this README.md with the new example

## Testing

All examples are tested to ensure they compile and run correctly. If you modify any example, please verify it still works:

```bash
nim c -r examples/<your-example>.nim
```

## See Also

- [Library Source](../src/sse.nim)
- [Unit Tests](../tests/test_sse.nim)
- [Benchmarks](../tests/benchmark.nim)
- [HTML5 SSE Specification](https://html.spec.whatwg.org/multipage/server-sent-events.html)
