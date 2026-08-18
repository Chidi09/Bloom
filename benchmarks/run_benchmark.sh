#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THREADS=4
CONNECTIONS=100
DURATION="10s"
WARMUP="3s"

echo "================================================================"
echo "          BLOOM SERVER vs FASTIFY vs NESTJS BENCHMARK          "
echo "================================================================"
echo "Specs: $(nproc) vCPUs, Linux x64"
echo "Load:  $THREADS threads, $CONNECTIONS connections, $DURATION duration per test"
echo "================================================================"
echo ""

run_test_suite() {
  local NAME=$1
  local PORT=$2
  local PID=$3

  echo "----------------------------------------------------------------"
  echo " [BENCHMARK] $NAME (Port: $PORT, PID: $PID)"
  echo "----------------------------------------------------------------"

  # Measure initial memory
  local MEM_INIT=$(ps -o rss= -p $PID | tr -d ' ')
  local MEM_INIT_MB=$(awk "BEGIN {printf \"%.2f\", $MEM_INIT/1024}")
  echo "Initial Memory (RSS): ${MEM_INIT_MB} MB"
  echo ""

  # Warmup
  echo ">> Warming up..."
  wrk -t2 -c20 -d$WARMUP http://127.0.0.1:$PORT/ping > /dev/null 2>&1
  sleep 1

  # Test 1: GET /ping (Plain JSON baseline)
  echo ">> 1. Test: GET /ping (JSON Hello World)"
  wrk -t$THREADS -c$CONNECTIONS -d$DURATION --latency http://127.0.0.1:$PORT/ping
  echo ""

  # Test 2: GET /users/42 (Parameterized Route + Serialization)
  echo ">> 2. Test: GET /users/42 (Dynamic Route & Params)"
  wrk -t$THREADS -c$CONNECTIONS -d$DURATION --latency http://127.0.0.1:$PORT/users/42
  echo ""

  # Test 3: POST /echo (JSON Body Parsing + Response)
  echo ">> 3. Test: POST /echo (JSON Payload Parsing)"
  wrk -t$THREADS -c$CONNECTIONS -d$DURATION --latency -s "$DIR/post_echo.lua" http://127.0.0.1:$PORT/echo
  echo ""

  # Measure final memory
  local MEM_FINAL=$(ps -o rss= -p $PID | tr -d ' ')
  local MEM_FINAL_MB=$(awk "BEGIN {printf \"%.2f\", $MEM_FINAL/1024}")
  echo "Final Memory (RSS): ${MEM_FINAL_MB} MB"
  echo ""
}

# 1. Start Fastify
echo "Starting Fastify server on :4002..."
node "$DIR/fastify_server/server.js" 4002 &
FASTIFY_PID=$!
sleep 2

# 2. Start NestJS
echo "Starting NestJS server on :4003..."
node "$DIR/nestjs_server/dist/main.js" 4003 &
NEST_PID=$!
sleep 3

# 3. Start Bloom Server
echo "Starting Bloom Server on :4001..."
(cd "$DIR/bloom_server" && dart run --no-enable-asserts bin/server.dart 4001) &
BLOOM_PID=$!
sleep 4

# Run benchmarks
run_test_suite "Fastify (Node.js)" 4002 $FASTIFY_PID
run_test_suite "NestJS (Node.js / Express)" 4003 $NEST_PID
run_test_suite "Bloom Server (Dart)" 4001 $BLOOM_PID

# Cleanup
echo "Shutting down servers..."
kill $FASTIFY_PID $NEST_PID $BLOOM_PID 2>/dev/null || true
echo "Benchmark completed."
