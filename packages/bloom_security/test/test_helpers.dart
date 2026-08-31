import 'dart:async';
import 'dart:io';

int _totalTests = 0;
int _passedTests = 0;
int _failedTests = 0;
String _currentGroup = '';
Future<void> _executionQueue = Future.value();

/// Declares a test group.
Future<void> group(String name, FutureOr<void> Function() body) async {
  final prevGroup = _currentGroup;
  _currentGroup = prevGroup.isEmpty ? name : '$prevGroup > $name';
  try {
    await body();
  } finally {
    _currentGroup = prevGroup;
  }
  // Await any queued tests within this group
  await _executionQueue;
}

/// Declares an individual test case.
void test(String name, FutureOr<void> Function() body) {
  _totalTests++;
  final testName = _currentGroup.isEmpty ? name : '$_currentGroup > $name';

  _executionQueue = _executionQueue.then((_) async {
    try {
      await body();
      _passedTests++;
      stdout.writeln('  [PASS] $testName');
    } catch (e, st) {
      _failedTests++;
      stderr.writeln('  [FAIL] $testName: $e\n$st');
    }
  });
}

/// Simple matcher interface.
abstract class Matcher {
  bool matches(dynamic item);
  String describeMismatch(dynamic item);
}

class _EqualsMatcher implements Matcher {
  final dynamic expected;
  const _EqualsMatcher(this.expected);

  @override
  bool matches(dynamic item) {
    if (expected is List && item is List) {
      if (expected.length != item.length) return false;
      for (var i = 0; i < expected.length; i++) {
        if (expected[i] != item[i]) return false;
      }
      return true;
    }
    if (expected is Map && item is Map) {
      if (expected.length != item.length) return false;
      for (final key in expected.keys) {
        if (!item.containsKey(key) || item[key] != expected[key]) return false;
      }
      return true;
    }
    if (expected is Set && item is Set) {
      if (expected.length != item.length) return false;
      return expected.containsAll(item) && item.containsAll(expected);
    }
    return item == expected;
  }

  @override
  String describeMismatch(dynamic item) =>
      'Expected: $expected, but got: $item';
}

class _ContainsMatcher implements Matcher {
  final dynamic expected;
  const _ContainsMatcher(this.expected);

  @override
  bool matches(dynamic item) {
    if (item is String && expected is String) {
      return item.contains(expected);
    }
    if (item is Iterable) {
      return item.contains(expected);
    }
    if (item is Map) {
      return item.containsKey(expected);
    }
    return false;
  }

  @override
  String describeMismatch(dynamic item) =>
      'Expected to contain: $expected, but was: $item';
}

class _GreaterThanMatcher implements Matcher {
  final num expected;
  const _GreaterThanMatcher(this.expected);

  @override
  bool matches(dynamic item) => item is num && item > expected;

  @override
  String describeMismatch(dynamic item) =>
      'Expected > $expected, but got: $item';
}

class _LessThanMatcher implements Matcher {
  final num expected;
  const _LessThanMatcher(this.expected);

  @override
  bool matches(dynamic item) => item is num && item < expected;

  @override
  String describeMismatch(dynamic item) =>
      'Expected < $expected, but got: $item';
}

Matcher equals(dynamic expected) => _EqualsMatcher(expected);
Matcher contains(dynamic expected) => _ContainsMatcher(expected);
Matcher greaterThan(num expected) => _GreaterThanMatcher(expected);
Matcher lessThan(num expected) => _LessThanMatcher(expected);

const Matcher isTrue = _EqualsMatcher(true);
const Matcher isFalse = _EqualsMatcher(false);
const Matcher isNull = _EqualsMatcher(null);

class _NotNullMatcher implements Matcher {
  const _NotNullMatcher();
  @override
  bool matches(dynamic item) => item != null;
  @override
  String describeMismatch(dynamic item) => 'Expected non-null, but got null';
}

const Matcher isNotNull = _NotNullMatcher();

class _TypeMatcher<T> implements Matcher {
  const _TypeMatcher();
  @override
  bool matches(dynamic item) => item is T;
  @override
  String describeMismatch(dynamic item) =>
      'Expected type $T, but got ${item.runtimeType}';
}

Matcher isA<T>() => _TypeMatcher<T>();

/// Asserts that [actual] matches [matcherOrValue].
void expect(dynamic actual, dynamic matcherOrValue, [String? reason]) {
  final Matcher matcher = matcherOrValue is Matcher
      ? matcherOrValue
      : _EqualsMatcher(matcherOrValue);

  if (!matcher.matches(actual)) {
    final msg = matcher.describeMismatch(actual);
    throw TestFailure(reason != null ? '$reason: $msg' : msg);
  }
}

/// Asserts that invoking [callback] throws an error matching [T].
Future<void> expectThrows<T>(FutureOr<void> Function() callback,
    [String? reason]) async {
  bool threw = false;
  try {
    await callback();
  } catch (e) {
    threw = true;
    if (e is! T) {
      throw TestFailure(
        reason != null
            ? '$reason: Expected exception of type $T, but got: $e'
            : 'Expected exception of type $T, but got: $e',
      );
    }
  }
  if (!threw) {
    throw TestFailure(
      reason != null
          ? '$reason: Expected exception of type $T, but nothing was thrown'
          : 'Expected exception of type $T, but nothing was thrown',
    );
  }
}

class TestFailure implements Exception {
  final String message;
  TestFailure(this.message);

  @override
  String toString() => 'TestFailure: $message';
}

/// Awaits all pending tests and reports results.
Future<int> reportTestResults() async {
  await _executionQueue;
  stdout.writeln('\n========================================');
  stdout.writeln(
      'Total: $_totalTests | Passed: $_passedTests | Failed: $_failedTests');
  stdout.writeln('========================================\n');
  if (_failedTests > 0) {
    return 1;
  }
  return 0;
}

void resetTestCounts() {
  _totalTests = 0;
  _passedTests = 0;
  _failedTests = 0;
  _executionQueue = Future.value();
}
