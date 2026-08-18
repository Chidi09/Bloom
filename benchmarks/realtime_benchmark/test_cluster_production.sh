#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT=5005
CLIENT_COUNT=1000
BROADCAST_COUNT=50

echo "================================================================"
echo "      BLOOM REALTIME CLUSTER PRODUCTION STRESS TEST            "
echo "================================================================"
echo "Host Specs: $(nproc) vCPUs, Linux x64"
echo "Target:     BloomRealtimeCluster (8 Isolates, shared: true)"
echo "Settings:   TCP_NODELAY=true, compressionOff=true"
echo "Load:       $CLIENT_COUNT concurrent WebSockets, $BROADCAST_COUNT burst broadcasts (50,000 deliveries)"
echo "================================================================"
echo ""

(cd "$DIR/bloom_realtime" && dart run --no-enable-asserts bin/run_cluster_server.dart $PORT) &
SERVER_PID=$!

sleep 5

# Check initial memory
RSS_INIT=$(ps -o rss= -p $SERVER_PID 2>/dev/null | tr -d ' ' || echo "0")
echo "Initial Cluster RSS Memory: $(awk "BEGIN {printf \"%.2f\", $RSS_INIT/1024}") MB"
echo ""

# Run 1000 clients stress test
/root/.bun/bin/bun "$DIR/client_bench.ts" $PORT $CLIENT_COUNT $BROADCAST_COUNT

echo ""
RSS_FINAL=$(ps -o rss= -p $SERVER_PID 2>/dev/null | tr -d ' ' || echo "0")
echo "Cluster RSS Memory with $CLIENT_COUNT Active Sockets: $(awk "BEGIN {printf \"%.2f\", $RSS_FINAL/1024}") MB"

kill $SERVER_PID 2>/dev/null || true
echo ""
echo "================================================================"
echo "✓ BloomRealtimeCluster production stress test completed."
echo "================================================================"
