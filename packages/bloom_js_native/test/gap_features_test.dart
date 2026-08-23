import 'dart:convert';

import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  group('query string parsing', () {
    test('percent-decodes keys and values', () {
      final q = parseQueryString('/s?na%20me=John%20Doe&caf%C3%A9=au%20lait');
      expect(q['na me'], 'John Doe');
      expect(q['café'], 'au lait');
    });

    test('treats + as a space', () {
      final q = parseQueryString('/s?q=red+running+shoes');
      expect(q['q'], 'red running shoes');
    });

    test('a key with no = is present with an empty value', () {
      final q = parseQueryString('/s?debug&page=2');
      expect(q.containsKey('debug'), isTrue,
          reason: 'a bare flag must be visible, not dropped');
      expect(q['debug'], '');
      expect(q['page'], '2');
    });

    test('tolerates a trailing & and an empty query', () {
      expect(parseQueryString('/s?a=1&'), {'a': '1'});
      expect(parseQueryString('/s?'), isEmpty);
      expect(parseQueryString('/s'), isEmpty);
    });

    test('repeated keys: single map takes the last, All keeps every value', () {
      expect(parseQueryString('/s?tag=a&tag=b&tag=c')['tag'], 'c');
      expect(parseQueryStringAll('/s?tag=a&tag=b&tag=c')['tag'], ['a', 'b', 'c']);
    });

    test('a value containing an encoded & or = survives intact', () {
      final q = parseQueryString('/s?filter=a%26b&eq=x%3Dy');
      expect(q['filter'], 'a&b');
      expect(q['eq'], 'x=y');
    });

    test('the fragment is not swallowed into the query', () {
      final q = parseQueryString('/docs?page=2#section-3');
      expect(q['page'], '2',
          reason: 'the fragment must not leak into the last query value');
      expect(parseFragment('/docs?page=2#section-3'), 'section-3');
      expect(parseFragment('/docs?page=2'), isEmpty);
    });

    test('buildQueryString round-trips through the parser', () {
      // buildQueryString emits its own leading '?', so it appends directly.
      final built = buildQueryString({'q': 'red shoes', 'page': 2});
      expect(built.startsWith('?'), isTrue);
      expect(parseQueryString('/s$built')['q'], 'red shoes');
      expect(parseQueryString('/s$built')['page'], '2');
      expect(buildQueryString({}), isEmpty,
          reason: 'an empty map must not produce a bare "?"');
      expect(parseQueryStringAll('/s${buildQueryString({
            'tag': ['a', 'b']
          })}')['tag'],
          ['a', 'b'],
          reason: 'an Iterable value must expand to repeated keys');
    });
  });

  group('router carries the query through a match', () {
    final router = BloomRouter([
      BloomRoute('/search', (p) => Div(text: 'search')),
      BloomRoute('/user/:id', (p) => Div(text: 'user')),
    ]);

    test('a query string does not prevent the path from matching', () {
      final m = router.match('/search?q=shoes&page=2');
      expect(m, isNotNull, reason: 'path matching must ignore the query');
      expect(m!.query['q'], 'shoes');
      expect(m.query['page'], '2');
    });

    test('path params and query coexist', () {
      final m = router.match('/user/42?tab=billing');
      expect(m!.params['id'], '42');
      expect(m.query['tab'], 'billing');
    });

    test('a match with no query exposes an empty map, not null', () {
      expect(router.match('/search')!.query, isEmpty);
    });

    test('a fragment does not prevent matching', () {
      expect(router.match('/search#results'), isNotNull);
    });
  });

  group('SSR cache dehydration', () {
    setUp(BloomData.clear);
    tearDown(BloomData.clear);

    test('a hydrated query starts in success and does NOT refetch', () async {
      // Server side: fill the cache, then dehydrate.
      BloomData.putEntry(QueryCacheEntry<Map<String, dynamic>>(
        key: ['user', 1],
        data: {'name': 'Ada'},
        updatedAt: DateTime.now(),
      ));
      final payload = BloomData.dehydrate();
      BloomData.clear();

      // Client side: hydrate, then construct the query the page would build.
      BloomData.hydrate(payload);

      var fetchCount = 0;
      final q = BloomQuery<Map<String, dynamic>>(
        key: ['user', 1],
        fetch: () async {
          fetchCount++;
          return {'name': 'Ada'};
        },
      );
      addTearDown(q.dispose);

      expect(q.data.value, {'name': 'Ada'},
          reason: 'hydrated data must be available synchronously');
      expect(q.status.value, QueryStatus.success,
          reason: 'must not start in idle after hydration');

      // Give any scheduled fetch a chance to run.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fetchCount, 0,
          reason: 'THE POINT OF THE FEATURE: no SSR double-fetch');
    });

    test('shouldDehydrate can exclude entries', () {
      BloomData.putEntry(
          QueryCacheEntry<String>(key: ['public'], data: 'ok', updatedAt: DateTime.now()));
      BloomData.putEntry(
          QueryCacheEntry<String>(key: ['secret'], data: 'shh', updatedAt: DateTime.now()));

      final payload = BloomData.dehydrate(
        shouldDehydrate: (e) => e.key.first != 'secret',
      );
      final encoded = jsonEncode(payload);
      expect(encoded, contains('public'));
      expect(encoded, isNot(contains('shh')),
          reason: 'excluded entries must not leak into the payload');
    });

    test('non-encodable data without a serializer fails loudly', () {
      BloomData.putEntry(
          QueryCacheEntry<Object>(
              key: ['bad'], data: Object(), updatedAt: DateTime.now()));
      expect(() => BloomData.dehydrate(), throwsA(isA<Object>()),
          reason: 'must not silently emit a broken payload');
    });

    test('serialize/deserialize round-trips a domain object', () {
      BloomData.putEntry(QueryCacheEntry<DateTime>(
          key: ['when'],
          data: DateTime.utc(2026, 8, 23),
          updatedAt: DateTime.now()));
      final payload = BloomData.dehydrate(
        serialize: (d, k) => (d as DateTime).toIso8601String(),
      );
      final json = jsonEncode(payload);
      BloomData.clear();

      BloomData.hydrate(
        jsonDecode(json) as Map<String, dynamic>,
        deserialize: (j, k) => DateTime.parse(j as String),
      );
      expect(BloomData.getQueryData<DateTime>(['when']),
          DateTime.utc(2026, 8, 23));
    });

    test('the script tag payload escapes a </script> in the data', () {
      BloomData.putEntry(QueryCacheEntry<String>(
          key: ['xss'],
          data: '</script><script>alert(1)</script>',
          updatedAt: DateTime.now()));
      final tag = BloomData.dehydrateToScriptTag();
      expect(tag.contains('</script><script>alert(1)'), isFalse,
          reason: 'an unescaped </script> would break out of the JSON block');
    });
  });

  group('infinite query', () {
    setUp(BloomData.clear);
    tearDown(BloomData.clear);

    BloomInfiniteQuery<List<int>, int> makeQuery({
      Duration delay = Duration.zero,
      int lastPage = 2,
      void Function()? onFetch,
    }) {
      return BloomInfiniteQuery<List<int>, int>(
        key: ['items'],
        initialPageParam: 0,
        fetch: (p) async {
          onFetch?.call();
          if (delay > Duration.zero) await Future<void>.delayed(delay);
          return [p * 10, p * 10 + 1];
        },
        getNextPageParam: (last, all) =>
            all.length > lastPage ? null : all.length,
      );
    }

    test('accumulates pages in order and reports hasNextPage', () async {
      final q = makeQuery();
      addTearDown(q.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(q.data.value, [
        [0, 1]
      ]);
      expect(q.hasNextPage.value, isTrue);

      await q.fetchNextPage();
      expect(q.data.value!.length, 2);
      expect(q.data.value!.last, [10, 11],
          reason: 'pages must append in order');
    });

    test('concurrent fetchNextPage does not double-append', () async {
      final q = makeQuery(delay: const Duration(milliseconds: 40));
      addTearDown(q.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final before = q.data.value!.length;

      // Fire two without awaiting the first.
      final a = q.fetchNextPage();
      final b = q.fetchNextPage();
      await Future.wait([a, b]);

      expect(q.data.value!.length, before + 1,
          reason: 'the in-flight guard must drop the second concurrent call');
    });

    test('hasNextPage goes false at the end and stops fetching', () async {
      final q = makeQuery(lastPage: 1);
      addTearDown(q.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      await q.fetchNextPage();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(q.hasNextPage.value, isFalse);

      final len = q.data.value!.length;
      await q.fetchNextPage();
      expect(q.data.value!.length, len,
          reason: 'fetchNextPage past the end must be a no-op');
    });

    test('isFetchingNextPage is distinct from isFetching', () async {
      final q = makeQuery(delay: const Duration(milliseconds: 40));
      addTearDown(q.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      final f = q.fetchNextPage();
      expect(q.isFetchingNextPage.value, isTrue,
          reason: 'a bottom spinner needs to distinguish these');
      await f;
      expect(q.isFetchingNextPage.value, isFalse);
    });
  });

  group('form: new field kinds', () {
    test('the existing String field API is unchanged', () {
      final f = BloomFormField(
          initialValue: 'x', validators: [required(), minLength(2)]);
      expect(f.value.value, 'x');
      expect(f.validate(), isFalse);
      f.setValue('hello');
      expect(f.validate(), isTrue);
      expect(f.isDirty.value, isTrue);
      f.reset();
      expect(f.value.value, 'x');
    });

    test('a typed field holds a real int, not a string', () {
      final age = BloomTypedFormField<int>(initialValue: 0);
      age.setValue(42);
      expect(age.value.value, 42);
      expect(age.value.value, isA<int>());
      expect(age.rawValue, 42);
    });

    test('a field array is reactive on add and remove', () {
      final arr = BloomFieldArray<BloomFormField>(
        initialValues: [BloomFormField(initialValue: 'a')],
      );
      var notifications = 0;
      final d = effect(() {
        arr.fields.value.length;
        notifications++;
      });
      addTearDown(d.call);

      final before = notifications;
      arr.add(BloomFormField(initialValue: 'b'));
      expect(arr.fields.value.length, 2);
      expect(notifications, greaterThan(before),
          reason: 'adding must notify a Live reading the array');

      arr.removeAt(0);
      expect(arr.fields.value.length, 1);
      expect(arr.fields.value.first.value.value, 'b');
    });

    test('an array aggregates child validity', () {
      final arr = BloomFieldArray<BloomFormField>(
        initialValues: [
          BloomFormField(initialValue: '', validators: [required()]),
        ],
      );
      expect(arr.validate(), isFalse);
      arr.fields.value.first.setValue('filled');
      expect(arr.validate(), isTrue);
    });

    test('a mixed form validates and resets every field kind', () {
      final form = BloomForm({
        'name': BloomFormField(initialValue: '', validators: [required()]),
        'age': BloomTypedFormField<int>(initialValue: 0),
      });
      expect(form.validate(), isFalse, reason: 'name is required and empty');

      form.getField('name').setValue('Ada');
      expect(form.validate(), isTrue);

      form.reset();
      expect(form.getField('name').value.value, '');
    });

    test('a file field tracks selection without a browser type', () {
      final f = BloomFileField();
      expect(f.value.value, isEmpty);
      f.setFiles([
        BloomFile(name: 'a.png', size: 1024, mimeType: 'image/png'),
      ]);
      expect(f.value.value.single.name, 'a.png');
      expect(f.rawValue, isNotNull);
    });
  });
}
