import 'package:bloom_server/bloom_server.dart';
import 'package:bloom_rest/bloom_rest.dart';
import 'package:test/test.dart';

void main() {
  group('PageNumberPagination', () {
    test('computes correct page slice and envelope', () {
      const paginator = PageNumberPagination(
        defaultPageSize: 10,
        maxPageSize: 50,
      );

      final req = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/items?page=3&page_size=15'),
      );

      expect(paginator.pageSize(req), 15);
      final slice = paginator.slice(req, 100);
      expect(slice.limit, 15);
      expect(slice.offset, 30); // (3 - 1) * 15

      final envelope = paginator.envelope(req, 100, [
        {'id': 1}
      ]);
      expect(envelope['count'], 100);
      expect(envelope['page'], 3);
      expect(envelope['total_pages'], 7);
      expect(envelope['results'], [
        {'id': 1}
      ]);
    });

    test('enforces maxPageSize ceiling', () {
      const paginator = PageNumberPagination(
        defaultPageSize: 10,
        maxPageSize: 25,
      );

      final req = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/items?page=1&page_size=1000'),
      );

      expect(paginator.pageSize(req), 25);
    });
  });

  group('LimitOffsetPagination', () {
    test('computes correct limit/offset slice and envelope', () {
      const paginator = LimitOffsetPagination(
        defaultLimit: 20,
        maxLimit: 100,
      );

      final req = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/items?limit=30&offset=60'),
      );

      expect(paginator.pageSize(req), 30);
      final slice = paginator.slice(req, 150);
      expect(slice.limit, 30);
      expect(slice.offset, 60);

      final envelope = paginator.envelope(req, 150, [
        {'id': 2}
      ]);
      expect(envelope['count'], 150);
      expect(envelope['limit'], 30);
      expect(envelope['offset'], 60);
      expect(envelope['results'], [
        {'id': 2}
      ]);
    });
  });

  group('CursorPagination & Cursor Encoding', () {
    test('honors custom orderingField', () {
      const paginator = CursorPagination(
        defaultPageSize: 20,
        orderingField: '-created_at',
      );
      expect(paginator.orderingField, '-created_at');
    });

    test('encodes and decodes cursors with int and string PKs', () {
      final cursorInt = encodeCursor(101, '2026-08-30T10:00:00Z');
      final decodedInt = decodeCursor(cursorInt);
      expect(decodedInt?.$1, 101);
      expect(decodedInt?.$2, '2026-08-30T10:00:00Z');

      final cursorStr = encodeCursor('uuid-789', null);
      final decodedStr = decodeCursor(cursorStr);
      expect(decodedStr?.$1, 'uuid-789');
      expect(decodedStr?.$2, isNull);
    });

    test('decodeCursor safely returns null on malformed cursors', () {
      expect(decodeCursor(''), isNull);
      expect(decodeCursor('!!!not_base64!!!'), isNull);
      expect(decodeCursor('eyJuYW1lIjoiYWxpY2UifQ=='),
          isNull); // json without 'pk'
    });

    test('envelopeWithCursor creates standard response envelope', () {
      const paginator = CursorPagination(defaultPageSize: 10);
      final env = paginator.envelopeWithCursor(
        50,
        [
          {'id': 1},
          {'id': 2}
        ],
        nextCursor: 'next_cursor_token',
        previousCursor: 'prev_cursor_token',
      );

      expect(env['count'], 50);
      expect(env['results'], [
        {'id': 1},
        {'id': 2}
      ]);
      expect(env['next_cursor'], 'next_cursor_token');
      expect(env['previous_cursor'], 'prev_cursor_token');
    });
  });
}
