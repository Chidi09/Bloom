/// A diagnostic reported by `dart analyze --format=machine`.
class AnalyzerIssue {
  final String severity;
  final String type;
  final String code;
  final String file;
  final String message;
  final int line;
  final int column;
  final int length;

  const AnalyzerIssue({
    required this.severity,
    required this.type,
    required this.code,
    required this.file,
    required this.message,
    required this.line,
    required this.column,
    required this.length,
  });
}

/// Parses machine-format analyzer output, including escaped field separators.
List<AnalyzerIssue> parseMachineAnalyzerOutput(String output) {
  final issues = <AnalyzerIssue>[];
  for (final row in output.split(RegExp(r'\r?\n'))) {
    final fields = <String>[];
    final field = StringBuffer();
    for (var i = 0; i < row.length; i++) {
      final char = row[i];
      if (char == r'\' &&
          i + 1 < row.length &&
          (row[i + 1] == r'\' || row[i + 1] == '|')) {
        field.write(row[++i]);
      } else if (char == '|') {
        fields.add(field.toString());
        field.clear();
      } else {
        field.write(char);
      }
    }
    fields.add(field.toString());
    if (fields.length < 8) continue;
    final line = int.tryParse(fields[4]);
    final column = int.tryParse(fields[5]);
    final length = int.tryParse(fields[6]);
    if (line == null || column == null || length == null) continue;
    issues.add(AnalyzerIssue(
      severity: fields[0],
      type: fields[1],
      code: fields[2],
      file: fields[3],
      line: line,
      column: column,
      length: length,
      message: fields.skip(7).join('|'),
    ));
  }
  return issues;
}
