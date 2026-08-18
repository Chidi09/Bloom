#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "----------------------------------------------------------------"
echo " [QUERY BENCHMARK] 1. Bloom Data Engine (Dart / Signals)"
echo "----------------------------------------------------------------"
(cd "$DIR/../../packages/bloom_framework" && flutter test test/bloom_data_benchmark_test.dart)
echo ""

echo "----------------------------------------------------------------"
echo " [QUERY BENCHMARK] 2. TanStack Query Core (TypeScript / V5)"
echo "----------------------------------------------------------------"
(cd "$DIR/tanstack_query" && /root/.bun/bin/bun run main.ts)
echo ""
