#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ulimit -n 65535 2>/dev/null || true

CLIENT_COUNT=1000
BROADCAST_COUNT=50

echo "================================================================"
echo "          REALTIME WEBSOCKET & PUB/SUB BENCHMARK               "
echo "================================================================"
echo "Specs: $(nproc) vCPUs, Linux x64"
echo "Load:  $CLIENT_COUNT concurrent WebSockets, $BROADCAST_COUNT burst broadcasts (50,000 deliveries)"
echo "================================================================"
echo ""

wait_for_server() {
  local PORT=$1
  for i in {1..30}; do
    if curl -s "http://127.0.0.1:$PORT/stats" >/dev/null 2>&1 || curl -s "http://127.0.0.1:$PORT/ws" >/dev/null 2>&1 || curl -s "http://127.0.0.1:$PORT" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.5
  done
}

# 1. BLOOM REALTIME
echo "----------------------------------------------------------------"
echo " [REALTIME] Bloom Realtime Server (Dart)"
echo "----------------------------------------------------------------"
(cd "$DIR/bloom_realtime" && dart run --no-enable-asserts bin/server.dart 5001) &
BLOOM_PID=$!
sleep 4
wait_for_server 5001
MEM_INIT=$(ps -o rss= -p $BLOOM_PID | tr -d ' ')
echo "Initial Memory: $(awk "BEGIN {printf \"%.2f\", $MEM_INIT/1024}") MB"

/root/.bun/bin/bun "$DIR/client_bench.ts" 5001 $CLIENT_COUNT $BROADCAST_COUNT

MEM_FINAL=$(ps -o rss= -p $BLOOM_PID | tr -d ' ')
echo "Memory with $CLIENT_COUNT Live WebSockets: $(awk "BEGIN {printf \"%.2f\", $MEM_FINAL/1024}") MB"
kill $BLOOM_PID 2>/dev/null || true
sleep 2
echo ""

# 2. FASTIFY REALTIME
echo "----------------------------------------------------------------"
echo " [REALTIME] Fastify WebSocket (@fastify/websocket)"
echo "----------------------------------------------------------------"
node "$DIR/fastify_realtime/server.js" 5002 &
FASTIFY_PID=$!
sleep 2
wait_for_server 5002
MEM_INIT=$(ps -o rss= -p $FASTIFY_PID | tr -d ' ')
echo "Initial Memory: $(awk "BEGIN {printf \"%.2f\", $MEM_INIT/1024}") MB"

/root/.bun/bin/bun "$DIR/client_bench.ts" 5002 $CLIENT_COUNT $BROADCAST_COUNT

MEM_FINAL=$(ps -o rss= -p $FASTIFY_PID | tr -d ' ')
echo "Memory with $CLIENT_COUNT Live WebSockets: $(awk "BEGIN {printf \"%.2f\", $MEM_FINAL/1024}") MB"
kill $FASTIFY_PID 2>/dev/null || true
sleep 2
echo ""

# 3. NESTJS REALTIME
echo "----------------------------------------------------------------"
echo " [REALTIME] NestJS WebSocket Gateway (@nestjs/platform-ws)"
echo "----------------------------------------------------------------"
node "$DIR/nestjs_realtime/dist/main.js" 5003 &
NEST_PID=$!
sleep 3
wait_for_server 5003
MEM_INIT=$(ps -o rss= -p $NEST_PID | tr -d ' ')
echo "Initial Memory: $(awk "BEGIN {printf \"%.2f\", $MEM_INIT/1024}") MB"

/root/.bun/bin/bun "$DIR/client_bench.ts" 5003 $CLIENT_COUNT $BROADCAST_COUNT

MEM_FINAL=$(ps -o rss= -p $NEST_PID | tr -d ' ')
echo "Memory with $CLIENT_COUNT Live WebSockets: $(awk "BEGIN {printf \"%.2f\", $MEM_FINAL/1024}") MB"
kill $NEST_PID 2>/dev/null || true
sleep 1

echo "================================================================"
echo "Realtime benchmark suite completed."
