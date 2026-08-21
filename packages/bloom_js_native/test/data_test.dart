import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  setUp(() {
    BloomData.clear();
  });

  group('BloomData & BloomQuery', () {
    test('query fetches and updates signal data', () async {
      final q = query<String>(
        key: ['users', 1],
        fetch: () async => 'Alice',
      );
      expect(q.isLoading, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(q.isSuccess, isTrue);
      expect(q.data.value, 'Alice');
      q.dispose();
    });

    test('deduplicates concurrent fetches for same key', () async {
      int fetchCount = 0;
      Future<String> fetcher() async {
        fetchCount++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return 'Data';
      }

      final q1 = query<String>(key: ['items'], fetch: fetcher);
      final q2 = query<String>(key: ['items'], fetch: fetcher);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fetchCount, 1);
      expect(q1.data.value, 'Data');
      expect(q2.data.value, 'Data');
      q1.dispose();
      q2.dispose();
    });

    test('invalidateQueries triggers refetch on active queries', () async {
      int count = 0;
      final q = query<int>(
        key: ['counter'],
        fetch: () async => ++count,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(q.data.value, 1);

      BloomData.invalidateQueries(['counter']);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(q.data.value, 2);
      q.dispose();
    });
  });
}
