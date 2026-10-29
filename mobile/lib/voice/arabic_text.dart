/// Arabic text helpers for matching spoken commands.
///
/// Whisper output varies a lot (hamza forms, taa marbuta, diacritics,
/// punctuation), so every comparison is done on a normalized form.
class ArabicText {
  static final _diacritics = RegExp(r'[ؐ-ًؚ-ٰٟۖ-ۭـ]');
  static final _punctuation = RegExp(r'''[.,!?؟،؛:;"'«»()\[\]{}\-_…]''');
  static final _spaces = RegExp(r'\s+');
  static final _repeatedLetter = RegExp(r'([ء-ي])\1+');

  static String normalize(String input) {
    var s = input.toLowerCase().replaceAll(_diacritics, '');
    s = s
        .replaceAll(RegExp('[أإآٱ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي');
    s = s.replaceAll(_punctuation, ' ');
    // Whisper sometimes stretches letters ("العملاءءء"); collapse Arabic repeats.
    s = s.replaceAllMapped(_repeatedLetter, (m) => m[1]!);
    return s.replaceAll(_spaces, ' ').trim();
  }

  static int wordCount(String normalized) =>
      normalized.isEmpty ? 0 : normalized.split(' ').length;

  /// Whisper is known to "hear" these phrases in silence or background noise.
  static const _hallucinations = [
    'ترجمه نانسي قنقر',
    'اشتركوا في القناه',
    'اشترك في القناه',
    'شكرا للمشاهده',
    'موسيقى',
    'نانسي قنقر',
    'subtitles',
    'thank you',
  ];

  static bool isLikelyNoise(String normalized) {
    if (normalized.length < 2) return true;
    return _hallucinations.any(normalized.contains);
  }
}
