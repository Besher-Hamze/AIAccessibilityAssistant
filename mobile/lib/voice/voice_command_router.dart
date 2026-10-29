import 'arabic_text.dart';

/// Places the user can open by voice.
enum AppDestination {
  home,
  customers,
  products,
  invoices,
  settings,
  help,
  users,
  audit,
  newInvoice,
}

enum VoiceActionType {
  navigate,
  back,
  scrollDown,
  scrollUp,
  scrollTop,
  scrollBottom,
  filterInvoices,
  readScreen,
  stopSpeaking,
  repeat,
  sleep,
  wake,
  collapse,
  expand,
  largerText,
  smallerText,
  highContrastOn,
  highContrastOff,
  slower,
  faster,
  autoSpeakOn,
  autoSpeakOff,
  clearChat,
  logout,
  login,
  refresh,
  pdfReport,
  demo,
  time,
  date,
  help,
  typeText,
}

class VoiceAction {
  final VoiceActionType type;
  final AppDestination? destination;

  /// Extra argument: login role ('admin'/'user'), or an invoice status
  /// (PAID/PENDING/DRAFT/CANCELLED, null = all) for PDF reports and filters.
  final String? arg;

  const VoiceAction(this.type, {this.destination, this.arg});

  @override
  String toString() => 'VoiceAction($type, $destination, $arg)';
}

/// Understands short app-control commands locally (MSA + Syrian dialect),
/// so navigation and settings work instantly without the LLM.
/// Anything it does not recognize is sent to the AI agent.
class VoiceCommandRouter {
  static List<String> _n(List<String> phrases) =>
      phrases.map(ArabicText.normalize).toList();

  static final wakeWords = _n([
    'يا مساعد',
    'يا مساعدي',
    'مساعد',
    'مساعدي',
    'يا محاسب',
    'اصحى',
    'اصحي',
    'فيق',
    'هاي مساعد',
    'مرحبا مساعد',
  ]);

  static final _fillers = _n([
    'يا مساعد',
    'يا مساعدي',
    'لو سمحت',
    'من فضلك',
    'اذا بتريد',
    'اذا سمحت',
    'بليز',
    'please',
    'هلق',
    'هلا',
    'طيب',
    'يلا',
  ]);

  /// Words that may surround a destination in a pure navigation command,
  /// e.g. "افتحلي العملاء", "روح عالفواتير", "خدني لصفحة المنتجات".
  static final _navGlue = _n([
    'افتح', 'افتحلي', 'افتحي', 'روح', 'روحي', 'روحلي', 'خدني', 'خذني', 'وديني',
    'اذهب', 'انتقل', 'حولني', 'ورجيني', 'فرجيني', 'وريني', 'رجعني', 'ارجع',
    'بدي', 'اريد', 'شاشه', 'صفحه', 'قسم', 'واجهه', 'لي', 'الي', 'لعند', 'ع',
    'على', 'عل', 'عال', 'ال', 'لل', 'ل', 'الى', 'لـ', 'الى', 'هات', 'جيب',
    'قائمة', 'كل', 'كلها', 'اعرض', 'اعرضلي', 'شوف', 'فرجيني', 'بدي شوف',
  ]).toSet();

  /// Word prefixes that mean "go to / open", tolerant of Whisper mistakes
  /// such as "فتحل" (افتحلي), "روحة" (روح), "ادخول" (ادخل).
  static final _navVerbStems = _n([
    'افتح', 'فتح', 'روح', 'رح', 'ادخل', 'ادخول', 'دخول', 'دخل', 'فوت', 'خدني', 'خذني',
    'ودي', 'انتقل', 'اذهب', 'حول', 'ورجي', 'فرجي', 'وري', 'اعرض', 'شوف', 'رجع', 'ارجع',
    'open', 'go',
  ]);

  /// A word containing one of these is about that section, whatever Whisper
  /// attached to it ("عالفواتير", "العملاءت", "للمنتجات").
  static final Map<AppDestination, List<String>> _destinationStems = {
    AppDestination.customers: _n(['عملا', 'زباي', 'زبائن']),
    AppDestination.products: _n(['منتج', 'بضاع', 'مخزون', 'اصناف']),
    AppDestination.invoices: _n(['فواتير', 'فاتورات', 'فواتر']),
    AppDestination.home: _n(['رئيسي', 'بداية', 'هوم']),
    AppDestination.settings: _n(['اعداد', 'ضبط', 'وصولي', 'سيتنج', 'settings']),
    AppDestination.help: _n(['اوامر', 'دليل', 'تعليمات']),
    AppDestination.users: _n(['مستخدمين']),
  };

  static final _scrollDownWords = _n([
    'تحت', 'لتحت', 'داون', 'down', 'للأسفل', 'أسفل', 'لاسفل', 'نازل',
  ]).toSet();
  static final _scrollUpWords = _n([
    'فوق', 'لفوق', 'اب', 'up', 'للأعلى', 'أعلى', 'لاعلى', 'طالع',
  ]).toSet();
  static final _scrollBottomWords = _n([
    'للاخير', 'لاخر', 'الاخير', 'اخر', 'للنهاية', 'النهاية', 'لتحت خالص', 'للآخر',
  ]).toSet();
  static final _scrollNeutral = _n([
    'سكرول', 'scroll', 'شوي', 'شوية', 'كمان', 'الصفحة', 'صفحة', 'لي', 'ع', 'عل', 'لل', 'ال', 'يا',
  ]).toSet();

  static final Map<AppDestination, List<String>> _destinations = {
    AppDestination.newInvoice: _n(['فاتورة جديدة', 'شاشة فاتورة جديدة', 'انشاء فاتورة']),
    AppDestination.home: _n([
      'الصفحة الرئيسية', 'الرئيسية', 'رئيسية', 'لوحة التحكم', 'البداية', 'الهوم', 'الواجهة الرئيسية',
    ]),
    AppDestination.customers: _n(['العملاء', 'عملاء', 'الزبائن', 'زبائن', 'الزباين', 'زباين']),
    AppDestination.products: _n([
      'المنتجات', 'منتجات', 'البضاعة', 'البضاعه', 'المواد', 'المخزون', 'الأصناف', 'اصناف',
    ]),
    AppDestination.invoices: _n(['الفواتير', 'فواتير', 'الفاتورات']),
    AppDestination.settings: _n(['الإعدادات', 'اعدادات', 'الضبط', 'الوصولية', 'وصولية']),
    AppDestination.help: _n(['دليل الأوامر', 'الأوامر', 'اوامر', 'التعليمات', 'الدليل']),
    AppDestination.users: _n(['إدارة المستخدمين', 'المستخدمين', 'مستخدمين']),
    AppDestination.audit: _n(['سجل العمليات', 'السجل', 'العمليات']),
  };

  /// Ordered: more specific commands come before ones they could be confused with.
  static final List<(VoiceActionType, List<String>, int)> _commands = [
    (VoiceActionType.logout, _n([
      'سجل خروج', 'سجل الخروج', 'تسجيل الخروج', 'تسجيل خروج', 'اطلع من الحساب', 'اخرج من الحساب',
    ]), 6),
    (VoiceActionType.clearChat, _n([
      'امسح المحادثة', 'احذف المحادثة', 'مسح المحادثة', 'نظف المحادثة', 'امسح الرسائل', 'احذف الرسائل',
    ]), 6),
    (VoiceActionType.collapse, _n([
      'سكر المساعد', 'اخفي المساعد', 'صغر المساعد', 'اغلق المساعد', 'خبي المساعد', 'سكر الدائرة',
    ]), 5),
    (VoiceActionType.expand, _n(['افتح المساعد', 'كبر المساعد', 'وريني المساعد']), 5),
    (VoiceActionType.sleep, _n([
      'روح نام', 'نام', 'نامي', 'توقف عن الاستماع', 'بطل تسمع', 'وقف الاستماع', 'سكر المايك',
      'اطفي المايك', 'اوقف الميكروفون', 'استراحة', 'خلص هلق',
    ]), 4),
    (VoiceActionType.autoSpeakOff, _n([
      'لا تقرأ الردود', 'بلا صوت', 'بدون صوت', 'وقف القراءة', 'اطفي الصوت', 'كتم الصوت',
    ]), 5),
    (VoiceActionType.autoSpeakOn, _n([
      'اقرأ الردود', 'شغل الصوت', 'رجع الصوت', 'فعل القراءة', 'شغل القراءة',
    ]), 5),
    (VoiceActionType.stopSpeaking, _n([
      'اسكت', 'اسكتي', 'سكوت', 'بس', 'خلص', 'وقف', 'وقفي', 'توقف', 'كفى', 'كفاية', 'بكفي', 'stop',
    ]), 3),
    (VoiceActionType.repeat, _n([
      'عيد', 'عيدي', 'أعد', 'كرر', 'شو قلت', 'ما سمعت', 'ما فهمت', 'أعد الرد', 'كمان مرة', 'مرة تانية',
    ]), 4),
    (VoiceActionType.readScreen, _n([
      'اقرأ الشاشة', 'اقرالي الشاشة', 'شو في بالشاشة', 'شو في عالشاشة', 'شو في على الشاشة',
      'شو عالشاشة', 'شو على الشاشة', 'وين أنا',
      'اقرأ الصفحة', 'شو في هون', 'اقرالي', 'ماذا يوجد على الشاشة', 'أين أنا',
    ]), 5),
    (VoiceActionType.scrollTop, _n([
      'لأول الصفحة', 'لراس الصفحة', 'أول الصفحة', 'لفوق خالص', 'للأعلى تماما',
    ]), 4),
    (VoiceActionType.scrollDown, _n([
      'انزل', 'نزل', 'لتحت', 'نزلني', 'انزل لتحت', 'نزل لتحت', 'التالي', 'للأسفل', 'سكرول لتحت',
    ]), 3),
    (VoiceActionType.scrollUp, _n([
      'اطلع', 'طلع', 'لفوق', 'طلعني', 'اطلع لفوق', 'طلع لفوق', 'السابق', 'للأعلى', 'سكرول لفوق',
    ]), 3),
    (VoiceActionType.back, _n([
      'ارجع', 'ارجعي', 'رجوع', 'رجعني', 'للخلف', 'لورا', 'رجعني لورا', 'الرجوع', 'رجعة',
    ]), 3),
    (VoiceActionType.largerText, _n([
      'كبر الخط', 'كبر الكتابة', 'كبر الأزرار', 'خط كبير', 'كبر الكلام',
    ]), 4),
    (VoiceActionType.smallerText, _n([
      'صغر الخط', 'صغر الكتابة', 'صغر الأزرار', 'خط صغير', 'صغر الكلام',
    ]), 4),
    (VoiceActionType.highContrastOff, _n([
      'اطفي التباين', 'الغي التباين', 'بدون تباين', 'وقف التباين', 'تباين عادي',
    ]), 4),
    (VoiceActionType.highContrastOn, _n([
      'تباين عالي', 'شغل التباين', 'فعل التباين', 'التباين العالي',
    ]), 4),
    (VoiceActionType.slower, _n([
      'احكي أبطأ', 'على مهلك', 'بشويش', 'أبطأ', 'شوي شوي', 'بالراحة', 'خفف السرعة', 'تكلم ببطء',
    ]), 4),
    (VoiceActionType.faster, _n([
      'احكي أسرع', 'أسرع', 'بسرعة', 'زيد السرعة', 'عجل', 'تكلم بسرعة',
    ]), 4),
    (VoiceActionType.refresh, _n([
      'حدث', 'تحديث', 'حدث البيانات', 'حدث الصفحة', 'اعمل تحديث', 'رفرش',
    ]), 4),
    (VoiceActionType.demo, _n(['عرض تجريبي', 'العرض التجريبي', 'ديمو', 'demo']), 5),
    (VoiceActionType.time, _n([
      'كم الساعة', 'قديش الساعة', 'الساعة كم', 'شو الساعة', 'كم الوقت', 'الوقت',
    ]), 4),
    (VoiceActionType.date, _n([
      'شو التاريخ', 'التاريخ', 'أي يوم اليوم', 'شو اليوم', 'تاريخ اليوم', 'ما هو التاريخ',
    ]), 4),
    (VoiceActionType.help, _n([
      'شو بتقدر تعمل', 'شو فيك تعمل', 'شو بقدر قول', 'شو فيني قول', 'ساعدني', 'كيف استخدمك',
      'شو بتعرف', 'مساعدة', 'المساعدة', 'ماذا تستطيع', 'ماذا يمكنك',
    ]), 5),
    (VoiceActionType.typeText, _n([
      'بدي اكتب', 'افتح الكيبورد', 'لوحة المفاتيح', 'الكتابة', 'كيبورد',
    ]), 4),
  ];

  static final _loginAdmin = _n([
    'ادخل كمدير', 'دخول كمدير', 'دخول مدير', 'سجل دخول كمدير', 'ادخل مدير', 'افتح حساب المدير',
  ]);
  static final _loginUser = _n([
    'ادخل كمستخدم', 'دخول كمستخدم', 'دخول مستخدم', 'سجل دخول كمستخدم', 'ادخل مستخدم',
  ]);
  static final _loginGeneric = _n(['سجل دخول', 'تسجيل الدخول', 'تسجيل دخول', 'ادخل', 'دخول']);

  static final _yes = _n([
    'نعم', 'اي', 'ايه', 'ايوا', 'ايوه', 'أكيد', 'تمام', 'موافق', 'yes', 'اوكي', 'ok', 'okay', 'صح',
    'بالتأكيد', 'طبعا', 'اعمل', 'اعملها', 'نفذ', 'أجل',
  ]);
  static final _no = _n([
    'لا', 'لاء', 'لأ', 'الغي', 'إلغاء', 'بلاش', 'لا تعمل', 'no', 'كنسل', 'ما بدي', 'خليها', 'رجعت',
  ]);

  static final _pdf = _n(['pdf', 'بي دي اف', 'بي دي إف', 'بيدياف']);

  static bool _hasPhrase(String text, String phrase) =>
      ' $text '.contains(' $phrase ');

  static bool _matches(String text, List<String> phrases, int maxWords) {
    final words = ArabicText.wordCount(text);
    for (final p in phrases) {
      if (text == p) return true;
      if (words <= maxWords && _hasPhrase(text, p)) return true;
    }
    return false;
  }

  static String _stripFillers(String text) {
    var s = ' $text ';
    for (final f in _fillers) {
      s = s.replaceAll(' $f ', ' ');
    }
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// If [normalized] contains a wake word, returns the rest of the sentence
  /// (possibly empty). Returns null when no wake word was spoken.
  static String? afterWakeWord(String normalized) {
    final padded = ' $normalized ';
    for (final w in wakeWords) {
      final i = padded.indexOf(' $w ');
      if (i >= 0) {
        return padded.substring(i + w.length + 2).trim();
      }
    }
    return null;
  }

  /// true = yes, false = no, null = neither.
  static bool? parseConfirmation(String normalized) {
    final text = _stripFillers(normalized);
    if (ArabicText.wordCount(text) > 4) return null;
    if (_matches(text, _no, 4)) return false;
    if (_matches(text, _yes, 4)) return true;
    return null;
  }

  /// Glue words may carry an attached preposition: "لصفحة", "عالشاشة".
  static bool _isGlue(String word) {
    if (_navGlue.contains(word)) return true;
    for (final prefix in const ['ل', 'ع', 'ب', 'وال', 'عال', 'لل', 'بال']) {
      if (word.length > prefix.length + 1 &&
          word.startsWith(prefix) &&
          _navGlue.contains(word.substring(prefix.length))) {
        return true;
      }
    }
    return false;
  }

  static bool _isNavVerb(String word) =>
      _navVerbStems.any((stem) => word.startsWith(stem));

  static AppDestination? _stemDestination(String word) {
    for (final entry in _destinationStems.entries) {
      if (entry.value.any(word.contains)) return entry.key;
    }
    return null;
  }

  /// Tolerant navigation: one section word plus only verbs/glue/1-letter noise.
  static AppDestination? _fuzzyDestination(String text) {
    final words = text.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty || words.length > 5) return null;
    AppDestination? found;
    final rest = <String>[];
    for (final w in words) {
      final d = _stemDestination(w);
      if (d == null) {
        rest.add(w);
      } else if (found != null && found != d) {
        return null;
      } else {
        found = d;
      }
    }
    if (found == null) return null;
    final onlyGlue = rest.every((w) => _isNavVerb(w) || _isGlue(w) || w.length <= 1);
    return onlyGlue ? found : null;
  }

  /// 1 = down, -1 = up, 2 = bottom, null = not a scroll command.
  /// Accepts "نزيل لتحت", "سكرول داون", "اطلع شوي", "انزل للاخير".
  static int? _fuzzyScroll(String text) {
    final words = text.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty || words.length > 4) return null;
    var down = 0;
    var up = 0;
    var bottom = false;
    for (final w in words) {
      if (_scrollBottomWords.contains(w)) {
        bottom = true;
      } else if (_scrollDownWords.contains(w) || w.startsWith('نز') || w.startsWith('انز')) {
        down++;
      } else if (_scrollUpWords.contains(w) || w.startsWith('طلع') || w.startsWith('اطلع')) {
        up++;
      } else if (!_scrollNeutral.contains(w)) {
        return null;
      }
    }
    if (bottom && up == 0) return 2;
    if (down > 0 && up == 0) return 1;
    if (up > 0 && down == 0) return -1;
    return null;
  }

  static final _filterWords = _n([
    'فلتر', 'فلترة', 'صفي', 'تصفية', 'بس', 'فقط', 'خلي', 'خليها', 'اعرض', 'افتح', 'شوف',
    'الفواتير', 'فواتير', 'الفاتورات', 'يلي', 'اللي', 'التي', 'هي', 'على', 'ع', 'ال', 'لل',
  ]).toSet();

  /// Status named in a word, e.g. "المدفوعة", "مسودة", "المعلقات".
  static String? _statusOf(String word) {
    if (word.contains('مدفوع')) return 'PAID';
    if (word.contains('معلق')) return 'PENDING';
    if (word.contains('مسود')) return 'DRAFT';
    if (word.contains('ملغ')) return 'CANCELLED';
    return null;
  }

  /// "الفواتير المدفوعة", "فلتر المسودة", "بس المعلقة", "كل الفواتير".
  /// Returns null if it is not a filter command; arg null means "all".
  static VoiceAction? _invoiceFilter(String text) {
    final words = text.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty || words.length > 5) return null;
    String? status;
    var mentionsInvoices = false;
    var mentionsFilter = false;
    var all = false;
    for (final w in words) {
      final st = _statusOf(w);
      if (st != null) {
        if (status != null && status != st) return null;
        status = st;
      } else if (w == 'الكل' || w == 'كل' || w == 'كلها') {
        all = true;
      } else if (_filterWords.contains(w) || _isNavVerb(w) || w.length <= 1) {
        if (w.contains('فواتير') || w.contains('فاتورات')) mentionsInvoices = true;
        if (w.startsWith('فلتر') || w.startsWith('صف') || w == 'بس' || w == 'فقط') {
          mentionsFilter = true;
        }
      } else {
        return null;
      }
    }
    if (status != null && (mentionsInvoices || mentionsFilter || words.length == 1)) {
      return VoiceAction(VoiceActionType.filterInvoices, arg: status);
    }
    if (status == null && all && (mentionsInvoices || mentionsFilter)) {
      return const VoiceAction(VoiceActionType.filterInvoices);
    }
    return null;
  }

  static final _sequenceSplit = RegExp(r'[،,؛;]|\s+(?:ثم|بعدين|وبعدين|وبعدها|بعدها)\s+');

  /// Several commands in one sentence: "افتح الفواتير المدفوعة، وانزل للاخير".
  /// Returns null unless every part is a local command (otherwise the whole
  /// sentence goes to the AI).
  static List<VoiceAction>? parseSequence(String text) {
    final parts = <String>[];
    for (final chunk in text.split(_sequenceSplit)) {
      parts.addAll(_splitOnAnd(ArabicText.normalize(chunk)));
    }
    final clean = parts.where((p) => p.isNotEmpty).toList();
    if (clean.length < 2) return null;
    final actions = <VoiceAction>[];
    for (final part in clean) {
      final a = parse(part) ?? (part.startsWith('و') ? parse(part.substring(1)) : null);
      if (a == null || a.type == VoiceActionType.wake) return null;
      actions.add(a);
    }
    return actions;
  }

  /// Splits "افتح العملاء وانزل لتحت" before a word starting with "و" when
  /// both sides are commands on their own.
  static List<String> _splitOnAnd(String normalized) {
    final words = normalized.split(' ');
    for (var i = 1; i < words.length; i++) {
      if (!words[i].startsWith('و') || words[i].length < 3) continue;
      final left = words.sublist(0, i).join(' ');
      final right = '${words[i].substring(1)} ${words.sublist(i + 1).join(' ')}'.trim();
      if (parse(left) != null && parse(right) != null) {
        return [left, ..._splitOnAnd(right)];
      }
    }
    return [normalized];
  }

  static AppDestination? _matchDestination(String text) {
    for (final entry in _destinations.entries) {
      for (final kw in entry.value) {
        if (!text.contains(kw)) continue;
        final rest = text.replaceFirst(kw, ' ').split(' ').where((w) => w.isNotEmpty);
        if (rest.every(_isGlue)) return entry.key;
      }
    }
    return null;
  }

  static VoiceAction? parse(String normalized) {
    final text = _stripFillers(normalized);
    if (text.isEmpty) {
      return const VoiceAction(VoiceActionType.wake);
    }

    if (_pdf.any(text.contains)) {
      final status = text.contains('معلق')
          ? 'PENDING'
          : text.contains('مدفوع')
              ? 'PAID'
              : null;
      return VoiceAction(VoiceActionType.pdfReport, arg: status);
    }

    if (_matches(text, _loginAdmin, 5)) {
      return const VoiceAction(VoiceActionType.login, arg: 'admin');
    }
    if (_matches(text, _loginUser, 5)) {
      return const VoiceAction(VoiceActionType.login, arg: 'user');
    }

    final filter = _invoiceFilter(text);
    if (filter != null) return filter;

    // Destinations first so "ارجع عالرئيسية" navigates instead of just going back.
    final dest = _matchDestination(text) ?? _fuzzyDestination(text);
    if (dest != null) {
      return VoiceAction(VoiceActionType.navigate, destination: dest);
    }

    // Before the plain "انزل" phrase so "انزل للاخير" goes to the bottom.
    if (_fuzzyScroll(text) == 2) return const VoiceAction(VoiceActionType.scrollBottom);

    for (final (type, phrases, maxWords) in _commands) {
      if (_matches(text, phrases, maxWords)) return VoiceAction(type);
    }

    final scroll = _fuzzyScroll(text);
    if (scroll != null) {
      return VoiceAction(switch (scroll) {
        2 => VoiceActionType.scrollBottom,
        1 => VoiceActionType.scrollDown,
        _ => VoiceActionType.scrollUp,
      });
    }

    if (_matches(text, _loginGeneric, 3)) {
      return const VoiceAction(VoiceActionType.login, arg: 'admin');
    }

    if (wakeWords.contains(text)) {
      return const VoiceAction(VoiceActionType.wake);
    }
    return null;
  }
}
