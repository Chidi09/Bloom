import { QueryClient } from '@tanstack/query-core';

async function main() {
  console.log('================================================================');
  console.log('           TANSTACK QUERY ENGINE BENCHMARK (JS/TS)              ');
  console.log('================================================================');

  const queryClient = new QueryClient({
    defaultOptions: {
      queries: {
        staleTime: 10 * 60 * 1000,
        gcTime: 30 * 60 * 1000,
        retry: false,
      },
    },
  });

  // Test 1: Bulk Cache Insertion & Retrieval (10,000 keys)
  const entryCount = 10000;
  const sw1Start = performance.now();
  for (let i = 0; i < entryCount; i++) {
    queryClient.setQueryData(['user', i], {
      id: i,
      name: `User ${i}`,
      email: `user${i}@bloom.dev`,
      active: true,
    });
  }
  const writeMs = (performance.now() - sw1Start).toFixed(2);

  const sw1ReadStart = performance.now();
  let verifyCount = 0;
  for (let i = 0; i < entryCount; i++) {
    const data = queryClient.getQueryData<{ id: number }>(['user', i]);
    if (data && data.id === i) {
      verifyCount++;
    }
  }
  const readMs = (performance.now() - sw1ReadStart).toFixed(2);

  console.log('1. Bulk Cache Operations (10,000 records):');
  console.log(`   - Set Query Data:   ${writeMs}ms (${(entryCount / (parseFloat(writeMs) / 1000)).toFixed(0)} ops/sec)`);
  console.log(`   - Get Query Data:   ${readMs}ms (${(entryCount / (parseFloat(readMs) / 1000)).toFixed(0)} ops/sec)`);
  console.log(`   - Integrity Check:  ${verifyCount} / ${entryCount} matched`);
  console.log('');

  // Test 2: In-Flight Request Deduplication (1,000 concurrent callers across 50 keys)
  queryClient.clear();
  let actualFetchCount = 0;
  async function mockApiFetch(keyId: number): Promise<string> {
    actualFetchCount++;
    await new Promise((r) => setTimeout(r, 10));
    return `data_${keyId}`;
  }

  const concurrentCallers = 1000;
  const uniqueKeys = 50;
  const sw2Start = performance.now();

  const promises: Promise<any>[] = [];
  for (let i = 0; i < concurrentCallers; i++) {
    const keyId = i % uniqueKeys;
    promises.push(
      queryClient.fetchQuery({
        queryKey: ['resource', keyId],
        queryFn: () => mockApiFetch(keyId),
      })
    );
  }
  await Promise.all(promises);
  const dedupeMs = (performance.now() - sw2Start).toFixed(2);

  console.log('2. In-Flight Request Deduplication (1,000 calls / 50 unique keys):');
  console.log(`   - Resolution Time:  ${dedupeMs}ms`);
  console.log(`   - Actual Network Hits: ${actualFetchCount} (Expected: ${uniqueKeys})`);
  console.log(`   - Deduplicated Calls: ${concurrentCallers - actualFetchCount} / ${concurrentCallers} (${(((concurrentCallers - actualFetchCount) / concurrentCallers) * 100).toFixed(1)}%)`);
  console.log('');

  // Test 3: Optimistic Mutation & Manual Rollback (1,000 cycles)
  queryClient.clear();
  const mutationCycles = 1000;
  const sw3Start = performance.now();

  for (let i = 0; i < mutationCycles; i++) {
    const key = ['item', i];
    queryClient.setQueryData(key, 100);

    const previousData = queryClient.getQueryData<number>(key);
    queryClient.setQueryData(key, (old: number = 0) => old + 50);

    try {
      // Simulate network mutation throwing error
      throw new Error('Simulated network error');
    } catch (_) {
      // Rollback
      queryClient.setQueryData(key, previousData);
    }
  }
  const mutationMs = (performance.now() - sw3Start).toFixed(2);

  console.log('3. Optimistic Updates & Rollback (1,000 cycles):');
  console.log(`   - Total Execution:  ${mutationMs}ms (${(mutationCycles / (parseFloat(mutationMs) / 1000)).toFixed(0)} ops/sec)`);
  console.log(`   - Average Latency:  ${(parseFloat(mutationMs) / mutationCycles).toFixed(3)}ms per optimistic rollback cycle`);
  console.log('');

  // Test 4: Cache Invalidation (1,000 keys)
  for (let i = 0; i < 1000; i++) {
    queryClient.setQueryData(['item', i], i);
  }
  const sw4Start = performance.now();
  for (let i = 0; i < 1000; i++) {
    queryClient.invalidateQueries({ queryKey: ['item', i] });
  }
  const invalidateMs = (performance.now() - sw4Start).toFixed(2);

  console.log('4. Query Invalidation Cascade (1,000 keys):');
  console.log(`   - Invalidation Time:${invalidateMs}ms (${(1000 / (parseFloat(invalidateMs) / 1000)).toFixed(0)} ops/sec)`);
  console.log('');

  // Test 5: Memory Usage
  queryClient.clear();
  for (let i = 0; i < 10000; i++) {
    queryClient.setQueryData(['large_user', i], {
      id: i,
      guid: `f81d4fae-7dec-11d0-a765-00a0c91e6bf6_${i}`,
      name: `Long User Name ${i}`,
      roles: ['admin', 'editor', 'viewer'],
      metadata: { loginCount: i * 3, preferences: { theme: 'dark', notifications: true } },
    });
  }

  const memMb = (process.memoryUsage().rss / 1024 / 1024).toFixed(2);
  console.log('5. Memory Footprint (10,000 Complex JSON Records in Cache):');
  console.log(`   - Process RSS Memory: ${memMb} MB`);
  console.log('================================================================');
}

main();
