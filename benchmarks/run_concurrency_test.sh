#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ulimit -n 65535 2>/dev/null || true

THREADS=4
DURATION="8s"
LEVELS=(50 100 250 500 1000)

echo "================================================================"
echo "          CONCURRENCY SCALING STRESS TEST                      "
echo "================================================================"
echo "Concurrency Matrix: ${LEVELS[*]} concurrent connections"
echo "Load Threads:       $THREADS threads"
echo "Duration per test:  $DURATION"
echo "================================================================"
echo ""

run_concurrency_suite() {
  local NAME=$1
  local PORT=$2

  echo "================================================================"
  echo " Testing Concurrency Scaling for: $NAME (Port: $PORT)"
  echo "================================================================"

  for C in "${LEVELS[@]}"; do
    echo "--------------------------------------------------------"
    echo " Concurrency: $C connections [GET /ping]"
    echo "--------------------------------------------------------"
    wrk -t$THREADS -c$C -d$DURATION --latency http://127.0.0.1:$PORT/ping
    echo ""

    echo "--------------------------------------------------------"
    echo " Concurrency: $C connections [POST /echo]"
    echo "--------------------------------------------------------"
    wrk -t$THREADS -c$C -d$DURATION --latency -s "$DIR/post_echo.lua" http://127.0.0.1:$PORT/echo
    echo ""
    sleep 1
  done
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

run_concurrency_suite "Fastify (Node.js)" 4002
run_concurrency_suite "NestJS (Node.js / Express)" 4003
run_concurrency_suite "Bloom Server (Dart)" 4001

echo "Shutting down servers..."
kill $FASTIFY_PID $NEST_PID $BLOOM_PID 2>/dev/null || true
echo "Concurrency scaling benchmark completed."
