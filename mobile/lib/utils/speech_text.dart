/// Cleans assistant text before TTS so symbols and invoice codes are not spoken.
String sanitizeForSpeech(String input) {
  var text = input;

  // Markdown / emphasis markers
  text = text.replaceAll(RegExp(r'[*_`#]+'), ' ');

  // Invoice codes: INV-SEED-001, INV_123, etc.
  text = text.replaceAll(
    RegExp(r'\bINV[-_][A-Za-z0-9_-]+\b', caseSensitive: false),
    ' ',
  );

  // "رقم الفاتورة: INV-..." → keep the Arabic words only
  text = text.replaceAllMapped(
    RegExp(
      r'رقم\s*الفاتورة\s*[:：]?\s*[A-Za-z0-9_-]+',
      caseSensitive: false,
    ),
    (_) => 'رقم الفاتورة',
  );

  // Bare alphanumerics that look like invoice ids after Arabic "فاتورة"
  text = text.replaceAllMapped(
    RegExp(
      r'(الفاتورة|فاتورة)\s+([A-Za-z]{2,}[-_][A-Za-z0-9_-]+)',
      caseSensitive: false,
    ),
    (m) => m.group(1)!,
  );

  // Collapse whitespace / leftover punctuation clusters
  text = text.replaceAll(RegExp(r'[|•·]+'), ' ');
  text = text.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  return text;
}
