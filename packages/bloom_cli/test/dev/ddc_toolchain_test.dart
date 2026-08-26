import 'dart:io';
import 'package:bloom_cli/src/dev/ddc_dev_compiler.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('DdcToolchain', () {
    test('sanitizeVersion produces clean filesystem-safe tokens', () {
      expect(DdcToolchain.sanitizeVersion('3.13.0 (stable) (Wed Aug 5 00:28:05 2026 -0700) on "linux_x64"'),
          equals('3.13.0'));
      expect(DdcToolchain.sanitizeVersion('3.14.0-edge.1234'), equals('3.14.0-edge.1234'));
      expect(DdcToolchain.sanitizeVersion('foo/bar:baz'), equals('foo_bar_baz'));
    });

    test('discover identifies real host Dart SDK DDC toolchain', () {
      final toolchain = DdcToolchain.discover();
      expect(toolchain.isAvailable, isTrue);
      expect(toolchain.snapshotPath, isNotNull);
      expect(toolchain.runnerExecutable, isNotNull);
      expect(toolchain.ddcPlatformDillPath, isNotNull);
      expect(toolchain.requireJsPath, isNotNull);
      expect(File(toolchain.snapshotPath!).existsSync(), isTrue);
      expect(File(toolchain.runnerExecutable!).existsSync(), isTrue);
      expect(File(toolchain.ddcPlatformDillPath!).existsSync(), isTrue);
      expect(File(toolchain.requireJsPath!).existsSync(), isTrue);
    });

    test('discover gracefully handles missing DDC snapshots in fake SDK tree', () {
      final fakeDir = Directory.systemTemp.createTempSync('fake_sdk_');
      try {
        final fakeBin = Directory(p.join(fakeDir.path, 'bin'))..createSync(recursive: true);
        final fakeDart = File(p.join(fakeBin.path, 'dart'))..writeAsStringSync('#!/bin/sh\n');

        final toolchain = DdcToolchain.discover(
          customExecutable: fakeDart.path,
        );

        expect(toolchain.isAvailable, isFalse);
        expect(toolchain.snapshotPath, isNull);
        expect(toolchain.runnerExecutable, isNull);
      } finally {
        fakeDir.deleteSync(recursive: true);
      }
    });

    test('discover prefers AOT snapshot over JIT snapshot', () {
      final fakeDir = Directory.systemTemp.createTempSync('fake_sdk_aot_');
      try {
        final fakeBin = Directory(p.join(fakeDir.path, 'bin'))..createSync(recursive: true);
        final fakeDart = File(p.join(fakeBin.path, 'dart'))..writeAsStringSync('');
        final fakeSnapshots = Directory(p.join(fakeBin.path, 'snapshots'))..createSync();
        final fakeInternal = Directory(p.join(fakeDir.path, 'lib', '_internal'))..createSync(recursive: true);
        final fakeAmd = Directory(p.join(fakeDir.path, 'lib', 'dev_compiler', 'amd'))..createSync(recursive: true);

        File(p.join(fakeInternal.path, 'ddc_platform.dill')).writeAsStringSync('');
        File(p.join(fakeAmd.path, 'require.js')).writeAsStringSync('');
        final aot = File(p.join(fakeSnapshots.path, 'dartdevc_aot.dart.snapshot'))..writeAsStringSync('');
        final jit = File(p.join(fakeSnapshots.path, 'dartdevc.dart.snapshot'))..writeAsStringSync('');

        final toolchain = DdcToolchain.discover(
          customExecutable: fakeDart.path,
        );

        expect(toolchain.isAvailable, isTrue);
        expect(toolchain.snapshotPath, equals(aot.path));
        expect(toolchain.runnerExecutable, contains('dartaotruntime'));

        // If AOT is deleted, falls back to JIT snapshot + dart runner
        aot.deleteSync();
        final toolchainJit = DdcToolchain.discover(
          customExecutable: fakeDart.path,
        );
        expect(toolchainJit.isAvailable, isTrue);
        expect(toolchainJit.snapshotPath, equals(jit.path));
        expect(toolchainJit.runnerExecutable, endsWith('dart'));
      } finally {
        fakeDir.deleteSync(recursive: true);
      }
    });
  });
}
