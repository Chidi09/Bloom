import 'dart:io';
import 'cors_test.dart';
import 'rate_limit_test.dart';
import 'security_headers_test.dart';
import 'test_helpers.dart';
import 'websocket_test.dart';

void main() async {
  resetTestCounts();
  stdout.writeln('========================================');
  stdout.writeln('Running Bloom Security Automated Test Suite');
  stdout.writeln('========================================\n');

  await runCorsTests();
  await runRateLimitTests();
  await runWebSocketTests();
  await runSecurityHeadersTests();

  final exit = await reportTestResults();
  if (exit != 0) {
    exitCode = exit;
  }
}
