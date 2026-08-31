// lib/src/server/bloom_multipart.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

/// Exception thrown when an incoming request payload exceeds configured byte limits.
class BloomPayloadTooLargeException implements Exception {
  /// Descriptive message explaining the byte limit violation.
  final String message;

  /// Creates a [BloomPayloadTooLargeException] with an optional [message].
  BloomPayloadTooLargeException([this.message = 'Payload Too Large']);

  @override
  String toString() => 'BloomPayloadTooLargeException: $message';
}

/// Base class representing a single part parsed from a multipart/form-data payload.
abstract class BloomMultipartPart {
  /// The form field name specified in the part's `Content-Disposition` header.
  String get name;

  /// Lowercase map of all headers belonging to this multipart part.
  Map<String, String> get headers;
}

/// Represents a regular text form field within a multipart/form-data request.
class BloomMultipartField extends BloomMultipartPart {
  @override
  final String name;

  @override
  final Map<String, String> headers;

  /// The UTF-8 decoded text value of this form field.
  final String value;

  /// Creates a [BloomMultipartField] instance.
  BloomMultipartField({
    required this.name,
    required this.value,
    Map<String, String>? headers,
  }) : headers = headers != null ? Map.unmodifiable(headers) : const {};

  @override
  String toString() => 'BloomMultipartField(name: $name, value: $value)';
}

/// Represents a file upload within a multipart/form-data request.
///
/// Delivers file contents incrementally via [bytes] without loading the entire
/// file into memory. Enforces a single-consumption rule on [bytes].
class BloomMultipartFile extends BloomMultipartPart {
  @override
  final String name;

  /// The original filename supplied in `Content-Disposition`, if any.
  final String? filename;

  /// The MIME content type of the file from `Content-Type`, if any.
  final String? contentType;

  @override
  final Map<String, String> headers;

  final Stream<List<int>> _bytes;
  bool _bytesConsumed = false;

  /// Creates a [BloomMultipartFile] instance.
  BloomMultipartFile({
    required this.name,
    this.filename,
    this.contentType,
    Map<String, String>? headers,
    required Stream<List<int>> bytes,
  })  : headers = headers != null ? Map.unmodifiable(headers) : const {},
        _bytes = bytes;

  /// Incremental byte stream of the file content.
  ///
  /// Can be listened to or consumed exactly once. Calling [bytes] a second time
  /// throws a [StateError].
  Stream<List<int>> get bytes {
    if (_bytesConsumed) {
      throw StateError(
        'BloomMultipartFile bytes stream has already been consumed. '
        'A file stream may only be read once.',
      );
    }
    _bytesConsumed = true;
    return _bytes;
  }

  @override
  String toString() =>
      'BloomMultipartFile(name: $name, filename: $filename, contentType: $contentType)';
}

/// Extracts and validates the multipart boundary parameter from [contentType].
///
/// Throws [FormatException] if [contentType] is not `multipart/form-data` or if
/// the boundary parameter is missing, empty, or exceeds 70 characters.
String extractMultipartBoundary(String contentType) {
  if (contentType.trim().isEmpty) {
    throw const FormatException('Missing Content-Type header.');
  }

  final parts = contentType.split(';');
  final mime = parts[0].trim().toLowerCase();
  if (mime != 'multipart/form-data') {
    throw FormatException(
      'Invalid Content-Type "$contentType": expected multipart/form-data.',
    );
  }

  String? boundary;
  for (var i = 1; i < parts.length; i++) {
    final param = parts[i].trim();
    final eqIdx = param.indexOf('=');
    if (eqIdx != -1) {
      final key = param.substring(0, eqIdx).trim().toLowerCase();
      var val = param.substring(eqIdx + 1).trim();
      if (key == 'boundary') {
        if (val.startsWith('"') && val.endsWith('"') && val.length >= 2) {
          val = val.substring(1, val.length - 1);
        }
        boundary = val;
        break;
      }
    }
  }

  if (boundary == null || boundary.isEmpty) {
    throw const FormatException(
      'Missing or empty boundary in multipart/form-data Content-Type header.',
    );
  }

  if (boundary.length > 70) {
    throw FormatException(
      'Multipart boundary exceeds maximum length of 70 characters: "$boundary".',
    );
  }

  return boundary;
}

class _ParsedDisposition {
  final String type;
  final String name;
  final String? filename;
  final Map<String, String> parameters;

  _ParsedDisposition({
    required this.type,
    required this.name,
    this.filename,
    required this.parameters,
  });
}

_ParsedDisposition _parseContentDisposition(String headerValue) {
  final parts = <String>[];
  var current = StringBuffer();
  bool inQuotes = false;

  for (var i = 0; i < headerValue.length; i++) {
    final char = headerValue[i];
    if (char == '"') {
      inQuotes = !inQuotes;
      current.write(char);
    } else if (char == ';' && !inQuotes) {
      parts.add(current.toString().trim());
      current = StringBuffer();
    } else {
      current.write(char);
    }
  }
  if (current.isNotEmpty) {
    parts.add(current.toString().trim());
  }

  if (parts.isEmpty) {
    throw const FormatException('Empty Content-Disposition header.');
  }

  final type = parts[0].toLowerCase();
  if (type != 'form-data') {
    throw FormatException(
      'Invalid Content-Disposition type "$type": expected form-data.',
    );
  }

  final params = <String, String>{};
  for (var i = 1; i < parts.length; i++) {
    final segment = parts[i];
    final eqIdx = segment.indexOf('=');
    if (eqIdx == -1) continue;

    final key = segment.substring(0, eqIdx).trim().toLowerCase();
    var val = segment.substring(eqIdx + 1).trim();

    if (val.startsWith('"') && val.endsWith('"') && val.length >= 2) {
      val = val.substring(1, val.length - 1).replaceAll(r'\"', '"');
    }
    params[key] = val;
  }

  final name = params['name'];
  if (name == null || name.isEmpty) {
    throw const FormatException(
      'Multipart part Content-Disposition is missing required "name" parameter.',
    );
  }

  String? filename = params['filename'];
  if (filename == null && params.containsKey('filename*')) {
    final encoded = params['filename*']!;
    final singleQuoteIdx = encoded.lastIndexOf("''");
    if (singleQuoteIdx != -1) {
      try {
        filename = Uri.decodeComponent(encoded.substring(singleQuoteIdx + 2));
      } catch (_) {
        filename = encoded.substring(singleQuoteIdx + 2);
      }
    } else {
      filename = encoded;
    }
  }

  return _ParsedDisposition(
    type: type,
    name: name,
    filename: filename,
    parameters: params,
  );
}

int _indexOf(List<int> buffer, List<int> pattern, [int start = 0]) {
  if (pattern.isEmpty) return start;
  final n = buffer.length;
  final m = pattern.length;
  if (n - start < m) return -1;
  final first = pattern[0];
  final limit = n - m;
  for (int i = start; i <= limit; i++) {
    if (buffer[i] == first) {
      bool found = true;
      for (int j = 1; j < m; j++) {
        if (buffer[i + j] != pattern[j]) {
          found = false;
          break;
        }
      }
      if (found) return i;
    }
  }
  return -1;
}

int _longestMatchingPrefix(List<int> buffer, List<int> pattern) {
  final maxK =
      buffer.length < pattern.length ? buffer.length : pattern.length - 1;
  for (int k = maxK; k > 0; k--) {
    bool match = true;
    for (int i = 0; i < k; i++) {
      if (buffer[buffer.length - k + i] != pattern[i]) {
        match = false;
        break;
      }
    }
    if (match) return k;
  }
  return 0;
}

int _findHeaderEnd(List<int> buffer) {
  for (int i = 0; i < buffer.length - 1; i++) {
    if (buffer[i] == 10 && buffer[i + 1] == 10) {
      return i;
    }
    if (i < buffer.length - 3 &&
        buffer[i] == 13 &&
        buffer[i + 1] == 10 &&
        buffer[i + 2] == 13 &&
        buffer[i + 3] == 10) {
      return i;
    }
  }
  return -1;
}

class _MultipartChunkReader {
  final StreamIterator<List<int>> _iterator;
  final int? maxBytes;
  int _totalBytesRead = 0;
  List<int> _buffer = [];
  bool _isDone = false;

  _MultipartChunkReader(Stream<List<int>> stream, {this.maxBytes})
      : _iterator = StreamIterator(stream);

  List<int> get buffer => _buffer;

  Future<bool> ensureBytes(int count) async {
    while (_buffer.length < count) {
      if (_isDone) return false;
      if (!await _iterator.moveNext()) {
        _isDone = true;
        return false;
      }
      final chunk = _iterator.current;
      _totalBytesRead += chunk.length;
      if (maxBytes != null && _totalBytesRead > maxBytes!) {
        throw BloomPayloadTooLargeException(
          'Request body exceeded maximum allowed size of $maxBytes bytes.',
        );
      }
      _buffer.addAll(chunk);
    }
    return true;
  }

  Future<bool> pullChunk() async {
    if (_isDone) return false;
    if (!await _iterator.moveNext()) {
      _isDone = true;
      return false;
    }
    final chunk = _iterator.current;
    _totalBytesRead += chunk.length;
    if (maxBytes != null && _totalBytesRead > maxBytes!) {
      throw BloomPayloadTooLargeException(
        'Request body exceeded maximum allowed size of $maxBytes bytes.',
      );
    }
    _buffer.addAll(chunk);
    return true;
  }

  void consume(int count) {
    if (count >= _buffer.length) {
      _buffer = [];
    } else {
      _buffer.removeRange(0, count);
    }
  }

  Future<void> cancel() async {
    _isDone = true;
    await _iterator.cancel();
  }
}

/// Parses an incoming multipart byte [stream] delimited by [boundary].
///
/// Incrementally yields [BloomMultipartPart] instances without pre-buffering
/// uploaded files into memory. Enforces [maxBytes] during stream consumption.
Stream<BloomMultipartPart> parseMultipartStream({
  required Stream<List<int>> stream,
  required String boundary,
  int? maxBytes,
}) {
  final controller = StreamController<BloomMultipartPart>();
  final reader = _MultipartChunkReader(stream, maxBytes: maxBytes);

  void run() async {
    StreamController<List<int>>? currentFileController;
    try {
      final firstDelimiter = utf8.encode('--$boundary');
      final delimiter = utf8.encode('\r\n--$boundary');

      // 1. Locate initial boundary delimiter
      int firstIdx = _indexOf(reader.buffer, firstDelimiter);
      while (firstIdx == -1) {
        if (!await reader.pullChunk()) {
          throw const FormatException(
            'Multipart stream ended before initial boundary was found.',
          );
        }
        firstIdx = _indexOf(reader.buffer, firstDelimiter);
      }

      reader.consume(firstIdx + firstDelimiter.length);

      if (!await reader.ensureBytes(2)) {
        if (reader.buffer.isNotEmpty && reader.buffer[0] == 10) {
          reader.consume(1);
        } else {
          throw const FormatException(
            'Multipart stream ended immediately after initial boundary.',
          );
        }
      }

      if (reader.buffer.length >= 2 &&
          reader.buffer[0] == 45 &&
          reader.buffer[1] == 45) {
        reader.consume(2);
        await reader.cancel();
        await controller.close();
        return;
      }

      if (reader.buffer.length >= 2 &&
          reader.buffer[0] == 13 &&
          reader.buffer[1] == 10) {
        reader.consume(2);
      } else if (reader.buffer.isNotEmpty && reader.buffer[0] == 10) {
        reader.consume(1);
      } else {
        throw const FormatException(
          'Malformed multipart initial boundary delimiter format.',
        );
      }

      // 2. Parse individual parts in sequence
      while (true) {
        int headerEnd = _findHeaderEnd(reader.buffer);
        while (headerEnd == -1) {
          if (!await reader.pullChunk()) {
            throw const FormatException(
              'Multipart stream ended prematurely while reading headers.',
            );
          }
          headerEnd = _findHeaderEnd(reader.buffer);
        }

        final isCrlf = reader.buffer[headerEnd] == 13;
        final headerEndMarkerLen = isCrlf ? 4 : 2;
        final headerBytes = reader.buffer.sublist(0, headerEnd);
        reader.consume(headerEnd + headerEndMarkerLen);

        final headerText = utf8.decode(headerBytes);
        final headers = <String, String>{};
        for (final line in const LineSplitter().convert(headerText)) {
          final colon = line.indexOf(':');
          if (colon != -1) {
            final k = line.substring(0, colon).trim().toLowerCase();
            final v = line.substring(colon + 1).trim();
            headers[k] = v;
          }
        }

        final dispositionStr = headers['content-disposition'];
        if (dispositionStr == null || dispositionStr.isEmpty) {
          throw const FormatException(
            'Multipart part is missing Content-Disposition header.',
          );
        }

        final disposition = _parseContentDisposition(dispositionStr);
        final name = disposition.name;
        final filename = disposition.filename;
        final contentType = headers['content-type'];

        if (filename != null) {
          final listenCompleter = Completer<void>();
          Completer<void>? pauseCompleter;
          bool isFileCancelled = false;

          late final StreamController<List<int>> fileController;
          fileController = StreamController<List<int>>(
            onListen: () {
              if (!listenCompleter.isCompleted) {
                listenCompleter.complete();
              }
            },
            onPause: () {
              if (pauseCompleter == null || pauseCompleter!.isCompleted) {
                pauseCompleter = Completer<void>();
              }
            },
            onResume: () {
              if (pauseCompleter != null && !pauseCompleter!.isCompleted) {
                pauseCompleter!.complete();
              }
            },
            onCancel: () {
              isFileCancelled = true;
              if (!listenCompleter.isCompleted) {
                listenCompleter.complete();
              }
              if (pauseCompleter != null && !pauseCompleter!.isCompleted) {
                pauseCompleter!.complete();
              }
            },
          );
          currentFileController = fileController;

          final file = BloomMultipartFile(
            name: name,
            filename: filename,
            contentType: contentType,
            headers: headers,
            bytes: fileController.stream,
          );

          controller.add(file);

          // Wait until the consumer attaches a listener to file.bytes (or cancels)
          await listenCompleter.future;

          bool delimiterFound = false;
          while (!delimiterFound) {
            if (isFileCancelled) {
              final delimIdx = _indexOf(reader.buffer, delimiter);
              if (delimIdx != -1) {
                reader.consume(delimIdx + delimiter.length);
                delimiterFound = true;
              } else {
                final matchLen =
                    _longestMatchingPrefix(reader.buffer, delimiter);
                final emitLen = reader.buffer.length - matchLen;
                if (emitLen > 0) {
                  reader.consume(emitLen);
                }
                if (!await reader.pullChunk()) {
                  final err = FormatException(
                    'Multipart stream ended prematurely in file body for "$name".',
                  );
                  throw err;
                }
              }
            } else {
              final delimIdx = _indexOf(reader.buffer, delimiter);
              if (delimIdx != -1) {
                if (delimIdx > 0) {
                  final data =
                      Uint8List.fromList(reader.buffer.sublist(0, delimIdx));
                  fileController.add(data);
                }
                await fileController.close();
                reader.consume(delimIdx + delimiter.length);
                delimiterFound = true;
              } else {
                final matchLen =
                    _longestMatchingPrefix(reader.buffer, delimiter);
                final emitLen = reader.buffer.length - matchLen;
                if (emitLen > 0) {
                  final data =
                      Uint8List.fromList(reader.buffer.sublist(0, emitLen));
                  fileController.add(data);
                  reader.consume(emitLen);
                }

                if (fileController.isPaused &&
                    pauseCompleter != null &&
                    !pauseCompleter!.isCompleted) {
                  await pauseCompleter!.future;
                }

                if (!isFileCancelled) {
                  if (!await reader.pullChunk()) {
                    final err = FormatException(
                      'Multipart stream ended prematurely in file body for "$name".',
                    );
                    fileController.addError(err);
                    await fileController.close();
                    throw err;
                  }
                }
              }
            }
          }

          currentFileController = null;
        } else {
          final fieldBytes = BytesBuilder(copy: false);
          bool delimiterFound = false;
          while (!delimiterFound) {
            final delimIdx = _indexOf(reader.buffer, delimiter);
            if (delimIdx != -1) {
              if (delimIdx > 0) {
                fieldBytes.add(reader.buffer.sublist(0, delimIdx));
              }
              reader.consume(delimIdx + delimiter.length);
              delimiterFound = true;
            } else {
              final matchLen = _longestMatchingPrefix(reader.buffer, delimiter);
              final emitLen = reader.buffer.length - matchLen;
              if (emitLen > 0) {
                fieldBytes.add(reader.buffer.sublist(0, emitLen));
                reader.consume(emitLen);
              }
              if (!await reader.pullChunk()) {
                throw FormatException(
                  'Multipart stream ended prematurely in field value for "$name".',
                );
              }
            }
          }

          final value = utf8.decode(fieldBytes.takeBytes());
          final field = BloomMultipartField(
            name: name,
            value: value,
            headers: headers,
          );

          controller.add(field);
        }

        if (!await reader.ensureBytes(2)) {
          if (reader.buffer.isNotEmpty && reader.buffer[0] == 10) {
            reader.consume(1);
          } else {
            await reader.cancel();
            await controller.close();
            return;
          }
        }

        if (reader.buffer.length >= 2 &&
            reader.buffer[0] == 45 &&
            reader.buffer[1] == 45) {
          reader.consume(2);
          await reader.cancel();
          await controller.close();
          return;
        }

        if (reader.buffer.length >= 2 &&
            reader.buffer[0] == 13 &&
            reader.buffer[1] == 10) {
          reader.consume(2);
        } else if (reader.buffer.isNotEmpty && reader.buffer[0] == 10) {
          reader.consume(1);
        } else {
          throw const FormatException(
            'Malformed multipart delimiter format after part.',
          );
        }
      }
    } catch (e, st) {
      if (currentFileController != null && !currentFileController.isClosed) {
        currentFileController.addError(e, st);
        await currentFileController.close().catchError((_) {});
      }
      controller.addError(e, st);
      await reader.cancel();
      await controller.close();
    }
  }

  controller.onListen = run;
  controller.onCancel = () async {
    await reader.cancel();
  };

  return controller.stream;
}
