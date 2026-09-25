/// Rejects raw HTML attributes that can execute attacker-controlled content.
///
/// Bloom event handlers belong in the typed `on:` map. URL attributes are
/// checked after decoding the character references SSR would decode and
/// removing control characters browsers may ignore while parsing a scheme.
void validateBloomAttribute(String name, String value) {
  final normalizedName = name.toLowerCase();
  if (normalizedName.startsWith('on') && normalizedName.length > 2) {
    throw ArgumentError(
      'Inline event attribute "$name" is not allowed. Use the element\'s on: event handlers instead.',
    );
  }
  if (normalizedName == 'srcdoc') {
    throw ArgumentError(
      'The srcdoc attribute is not allowed because it embeds executable HTML.',
    );
  }

  const urlAttributes = {
    'action',
    'archive',
    'background',
    'cite',
    'codebase',
    'data',
    'formaction',
    'href',
    'longdesc',
    'manifest',
    'poster',
    'profile',
    'src',
    'xlink:href',
  };
  if (!urlAttributes.contains(normalizedName) && normalizedName != 'srcset') {
    return;
  }

  final decodedValue = _decodeRelevantCharacterReferences(value);
  final normalizedValue = decodedValue
      .replaceAll(RegExp(r'[\u0000-\u0020\u007f]+'), '')
      .toLowerCase();
  final hasScriptScheme = normalizedName == 'srcset'
      ? normalizedValue.contains('javascript:') ||
          normalizedValue.contains('vbscript:')
      : normalizedValue.startsWith('javascript:') ||
          normalizedValue.startsWith('vbscript:');
  if (hasScriptScheme) {
    throw ArgumentError('Unsafe script URL in HTML attribute "$name".');
  }

  final hasDataScheme = normalizedName == 'srcset'
      ? normalizedValue.contains('data:')
      : normalizedValue.startsWith('data:');
  if (hasDataScheme &&
      !(normalizedName == 'src' && _isSafeRasterDataImage(normalizedValue))) {
    throw ArgumentError('Unsafe data URL in HTML attribute "$name".');
  }
}

/// Escapes text and quoted attribute content for safe HTML serialization.
String escapeBloomHtml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#x27;');

/// Escapes JSON text placed inside an HTML `<script>` element.
///
/// The HTML parser recognizes `</script>` without regard to case, even inside
/// JavaScript strings and non-executable JSON script elements. Escaping every
/// `<` prevents the HTML parser from seeing any attacker-controlled end tag.
String escapeBloomJsonForScript(String json) => json
    .replaceAll('<', r'\u003c')
    .replaceAll('\u2028', r'\u2028')
    .replaceAll('\u2029', r'\u2029');

String _decodeRelevantCharacterReferences(String value) {
  final references = RegExp(
    r'&(?:#(x[0-9a-f]+|[0-9]+)|(colon|tab|newline));?',
    caseSensitive: false,
  );
  return value.replaceAllMapped(references, (match) {
    final numeric = match[1];
    if (numeric != null) {
      final isHex = numeric.toLowerCase().startsWith('x');
      final digits = isHex ? numeric.substring(1) : numeric;
      final codePoint = int.tryParse(digits, radix: isHex ? 16 : 10);
      if (codePoint != null && codePoint > 0 && codePoint <= 0x10ffff) {
        return String.fromCharCode(codePoint);
      }
      return '';
    }
    return switch (match[2]?.toLowerCase()) {
      'colon' => ':',
      'tab' => '\t',
      'newline' => '\n',
      _ => match[0]!,
    };
  });
}

bool _isSafeRasterDataImage(String value) => RegExp(
      r'^data:image/(?:png|gif|jpe?g|webp|avif);base64,',
    ).hasMatch(value);
