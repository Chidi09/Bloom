import 'dart:convert';
import 'dart:io';
import 'package:bloom_cli/src/upgrade/update_notifier.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('bloom_update_notice_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('shouldRun excludes CI, disabled, noninteractive, upgrade, and version',
      () {
    bool should(List<String> args, Map<String, String> env,
            [bool terminal = true]) =>
        UpdateNotifier.shouldRun(args, env, hasTerminal: terminal);
    expect(should(['doctor'], {}), isTrue);
    expect(should(['doctor'], {'CI': ''}), isFalse);
    expect(should(['doctor'], {'BLOOM_NO_UPDATE_CHECK': '0'}), isFalse);
    expect(should(['doctor'], {}, false), isFalse);
    expect(should(['upgrade'], {}), isFalse);
    expect(should(['--version'], {}), isFalse);
    expect(should([], {}), isFalse);
  });

  test('fresh cache does not fetch and newer version produces notice',
      () async {
    final cache = File('${tempDir.path}/update.json')
      ..writeAsStringSync(jsonEncode({
        'checkedAt': DateTime.now().toIso8601String(),
        'latest': '9.0.0',
      }));
    var calls = 0;
    final notifier = UpdateNotifier(
      currentVersion: '0.8.0',
      cacheFile: cache,
      fetchLatest: (_) async {
        calls++;
        return '10.0.0';
      },
    );
    notifier.start();
    final notice = await notifier.finish();
    expect(calls, 0);
    expect(notice, contains('bloom upgrade'));
  });

  test('stale cache fetches once and rewrites cache', () async {
    final cache = File('${tempDir.path}/update.json')
      ..writeAsStringSync(jsonEncode({
        'checkedAt': DateTime.utc(2000).toIso8601String(),
        'latest': '0.8.0',
      }));
    var calls = 0;
    final notifier = UpdateNotifier(
      currentVersion: '0.8.0',
      cacheFile: cache,
      now: () => DateTime.utc(2026),
      fetchLatest: (_) async {
        calls++;
        return '1.0.0';
      },
    );
    notifier.start();
    notifier.start();
    expect(await notifier.finish(), contains('1.0.0'));
    expect(calls, 1);
    expect(jsonDecode(cache.readAsStringSync())['latest'], '1.0.0');
  });

  test('same and older versions return no notice', () async {
    for (final latest in ['0.8.0', '0.7.9']) {
      final cache = File('${tempDir.path}/$latest.json')
        ..writeAsStringSync(jsonEncode({
          'checkedAt': DateTime.now().toIso8601String(),
          'latest': latest,
        }));
      final notifier = UpdateNotifier(
        currentVersion: '0.8.0',
        cacheFile: cache,
        fetchLatest: (_) async => fail('fresh cache should not fetch'),
      );
      notifier.start();
      expect(await notifier.finish(), isNull);
    }
  });

  test('corrupt cache and throwing fetcher are swallowed', () async {
    final cache = File('${tempDir.path}/update.json')..writeAsStringSync('{');
    final notifier = UpdateNotifier(
      currentVersion: '0.8.0',
      cacheFile: cache,
      fetchLatest: (_) async => throw StateError('offline'),
    );
    expect(() => notifier.start(), returnsNormally);
    expect(await notifier.finish(), isNull);
  });
}
