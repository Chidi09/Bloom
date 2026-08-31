import 'dart:io';
import 'package:test/test.dart';

// This guard lives in bloom_server rather than bloom_framework for two
// reasons. bloom_framework's tests run under flutter_test and so need the
// Flutter SDK, whereas the invariant being protected here is precisely that
// bloom_server needs no Flutter at all -- a guard that requires Flutter to run
// cannot be trusted to run in a pure-Dart CI job. And bloom_server is the
// package that must stay Flutter-free, so it owns its own invariant.
//
// The tests only read files from disk; nothing here imports bloom_framework.

/// Resolves a path relative to the packages/ directory, regardless of the
/// directory `dart test` was invoked from.
String _repoPath(String relative) {
  var dir = Directory.current;
  while (!File('${dir.path}/pubspec.yaml').existsSync() ||
      !File('${dir.path}/pubspec.yaml')
          .readAsStringSync()
          .contains('name: bloom_server')) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      fail('Could not locate the bloom_server package root.');
    }
    dir = parent;
  }
  return '${dir.parent.path}/$relative';
}

void main() {
  group('server core is defined exactly once', () {
    const duplicatedPaths = [
      'lib/src/server/api_router.dart',
      'lib/src/server/bloom_middleware.dart',
      'lib/src/server/bloom_request.dart',
      'lib/src/server/bloom_response.dart',
      'lib/src/core/env.dart',
      'lib/src/core/logger.dart',
      'lib/src/di/container.dart',
      'lib/src/di/scope.dart',
      'lib/src/config/env_schema.dart',
    ];

    for (final path in duplicatedPaths) {
      test('bloom_framework holds only a re-export shim for $path', () {
        final framework = File(_repoPath('bloom_framework/$path'));
        final server = File(_repoPath('bloom_server/$path'));

        expect(
          server.existsSync(),
          isTrue,
          reason: '$path must exist in bloom_server, its single home.',
        );

        // The path still exists in bloom_framework, because 29 files there
        // import these by relative path. What it must NOT be is a second
        // implementation: it may only re-export the real one. Two real copies
        // drift silently — that is how rpc_mount.dart ended up in only one
        // package.
        expect(framework.existsSync(), isTrue,
            reason:
                'the shim at $path is what keeps relative imports resolving');

        final source = framework.readAsStringSync();
        // A package: URI addresses lib/ implicitly, so drop the prefix.
        final packageUri =
            'package:bloom_server/${path.substring('lib/'.length)}';
        expect(
          source,
          contains("export '$packageUri';"),
          reason: 'bloom_framework/$path must re-export the bloom_server '
              'definition rather than define its own.',
        );

        // A shim carries no declarations. If any appear, someone has started
        // reimplementing here and the duplication is back.
        expect(
          RegExp(r'^\s*(class|mixin|enum|extension)\s', multiLine: true)
              .hasMatch(source),
          isFalse,
          reason: 'bloom_framework/$path declares a type. It must contain '
              'nothing but a re-export of package:bloom_server.',
        );
      });
    }
  });

  group('dependency direction', () {
    test('bloom_server does not depend on bloom_framework', () {
      final pubspec =
          File(_repoPath('bloom_server/pubspec.yaml')).readAsStringSync();
      expect(
        pubspec.contains('bloom_framework'),
        isFalse,
        reason: 'bloom_server must stay Flutter-free. Depending on '
            'bloom_framework would pull in the Flutter SDK and break '
            '`dart compile exe` for every pure-Dart backend.',
      );
    });

    test('bloom_server declares no Flutter dependency', () {
      final pubspec =
          File(_repoPath('bloom_server/pubspec.yaml')).readAsStringSync();
      expect(
        pubspec.contains('sdk: flutter'),
        isFalse,
        reason: 'bloom_server is deliberately Flutter-free.',
      );
    });

    test('bloom_framework depends on bloom_server', () {
      final pubspec =
          File(_repoPath('bloom_framework/pubspec.yaml')).readAsStringSync();
      expect(pubspec.contains('bloom_server'), isTrue);
    });
  });
}
