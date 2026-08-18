#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ulimit -n 65535 2>/dev/null || true

CLIENT_COUNT=1000
BROADCAST_COUNT=50

echo "================================================================"
echo "      CLUSTERED REALTIME WEBSOCKET BENCHMARK MATRIX            "
echo "================================================================"
echo "Specs: $(nproc) vCPUs, Linux x64"
echo "Load:  $CLIENT_COUNT concurrent WebSockets, $BROADCAST_COUNT burst broadcasts (50,000 deliveries)"
echo "================================================================"
echo ""

wait_for_server() {
  local PORT=$1
  for i in {1..30}; do
    if curl -s "http://127.0.0.1:$PORT/stats" >/dev/null 2>&1 || curl -s "http://127.0.0.1:$PORT/ws" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.5
  done
}

get_mem_mb() {
  local PID=$1
  local RSS=$(ps -o rss= -p $PID 2>/dev/null | tr -d ' ' || echo "0")
  if [ -z "$RSS" ]; then RSS="0"; fi
  awk "BEGIN {printf \"%.2f\", $RSS/1024}"
}

# 1. BLOOM REALTIME (SINGLE ISOLATE)
echo "----------------------------------------------------------------"
echo " 1. Bloom Realtime (1 Isolate / Single Core)"
echo "----------------------------------------------------------------"
(cd "$DIR/bloom_realtime" && dart run --no-enable-asserts bin/server.dart 5001) &
BLOOM_PID=$!
sleep 4
wait_for_server 5001
echo "Initial Memory: $(get_mem_mb $BLOOM_PID) MB"

/root/.bun/bin/bun "$DIR/client_bench.ts" 5001 $CLIENT_COUNT $BROADCAST_COUNT

echo "Memory with $CLIENT_COUNT Sockets: $(get_mem_mb $BLOOM_PID) MB"
kill $BLOOM_PID 2>/dev/null || true
sleep 2
echo ""

# 2. BLOOM REALTIME (8 ISOLATES CLUSTERED)
echo "----------------------------------------------------------------"
echo " 2. Bloom Realtime (8 Isolates Clustered / Multi-Core shared: true)"
echo "----------------------------------------------------------------"
(cd "$DIR/bloom_realtime" && dart run --no-enable-asserts bin/cluster_server.dart 5004) &
CLUSTER_PID=$!
sleep 5
wait_for_server 5004
echo "Initial Memory: $(get_mem_mb $CLUSTER_PID) MB"

/root/.bun/bin/bun "$DIR/client_bench.ts" 5004 $CLIENT_COUNT $BROADCAST_COUNT

echo "Memory with $CLIENT_COUNT Sockets: $(get_mem_mb $CLUSTER_PID) MB"
kill $CLUSTER_PID 2>/dev/null || true
sleep 2
echo ""

# 3. FASTIFY REALTIME
echo "----------------------------------------------------------------"
echo " 3. Fastify WebSocket (@fastify/websocket)"
echo "----------------------------------------------------------------"
node "$DIR/fastify_realtime/server.js" 5002 &
FASTIFY_PID=$!
sleep 2
wait_for_server 5002
echo "Initial Memory: $(get_mem_mb $FASTIFY_PID) MB"

/root/.bun/bin/bun "$DIR/client_bench.ts" 5002 $CLIENT_COUNT $BROADCAST_COUNT

echo "Memory with $CLIENT_COUNT Sockets: $(get_mem_mb $FASTIFY_PID) MB"
kill $FASTIFY_PID 2>/dev/null || true
sleep 2
echo ""

# 4. NESTJS REALTIME
echo "----------------------------------------------------------------"
echo " 4. NestJS WebSocket Gateway (@nestjs/platform-ws)"
echo "----------------------------------------------------------------"
node "$DIR/nestjs_realtime/dist/main.js" 5003 &
NEST_PID=$!
sleep 3
wait_for_server 5003
echo "Initial Memory: $(get_mem_mb $NEST_PID) MB"

/root/.bun/bin/bun "$DIR/client_bench.ts" 5003 $CLIENT_COUNT $BROADCAST_COUNT

echo "Memory with $CLIENT_COUNT Sockets: $(get_mem_mb $NEST_PID) MB"
kill $NEST_PID 2>/dev/null || true
sleep 1

echo "================================================================"
echo "Clustered benchmark matrix completed."
