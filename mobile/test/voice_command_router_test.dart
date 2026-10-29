import 'package:ai_accessibility_assistant/voice/arabic_text.dart';
import 'package:ai_accessibility_assistant/voice/voice_command_router.dart';
import 'package:flutter_test/flutter_test.dart';

VoiceAction? parse(String text) => VoiceCommandRouter.parse(ArabicText.normalize(text));

void main() {
  group('ArabicText.normalize', () {
    test('unifies hamza, taa marbuta and removes diacritics/punctuation', () {
      expect(ArabicText.normalize('إفْتَحْ الإعدادات!'), 'افتح الاعدادات');
      expect(ArabicText.normalize('الفاتورة؟'), 'الفاتوره');
    });

    test('flags common Whisper hallucinations as noise', () {
      expect(ArabicText.isLikelyNoise(ArabicText.normalize('ترجمة نانسي قنقر')), isTrue);
      expect(ArabicText.isLikelyNoise(ArabicText.normalize('افتح العملاء')), isFalse);
    });
  });

  group('navigation', () {
    final cases = {
      'افتح العملاء': AppDestination.customers,
      'افتحلي الزبائن': AppDestination.customers,
      'روح عالفواتير': AppDestination.invoices,
      'خدني لصفحة المنتجات': AppDestination.products,
      'الإعدادات': AppDestination.settings,
      'ارجع عالرئيسية': AppDestination.home,
      'يا مساعد افتح الفواتير لو سمحت': AppDestination.invoices,
      'افتح سجل العمليات': AppDestination.audit,
      'روح للعملاء': AppDestination.customers,
      'اعرض قائمة المنتجات': AppDestination.products,
      // Real Whisper transcripts from testing on device:
      'ادخول الى العملاءءء': AppDestination.customers,
      'روحة العملاءءت': AppDestination.customers,
      'فتحل الفواتير': AppDestination.invoices,
    };
    cases.forEach((text, dest) {
      test(text, () {
        final a = parse(text);
        expect(a?.type, VoiceActionType.navigate);
        expect(a?.destination, dest);
      });
    });

    test('questions about data go to the AI, not navigation', () {
      expect(parse('اعرض فواتير محمد الأحمد'), isNull);
      expect(parse('فواتير محمد'), isNull);
      expect(parse('كم عدد العملاء'), isNull);
      expect(parse('أضف عميل اسمه خالد'), isNull);
      expect(parse('أضف الفواتير، وروحة المدفوعة.'), isNull);
      expect(parse('أضف عميل اسمه سارة ورقمها 0944001122'), isNull);
      expect(parse('أنشئ فاتورة جديدة لمحمد الأحمد'), isNull);
      expect(parse('ما ملخص المحاسبة؟'), isNull);
    });
  });

  group('control commands', () {
    final cases = {
      'اسكت': VoiceActionType.stopSpeaking,
      'بس خلص': VoiceActionType.stopSpeaking,
      'عيد': VoiceActionType.repeat,
      'انزل': VoiceActionType.scrollDown,
      'نزيل لتحت': VoiceActionType.scrollDown,
      'سكرول داون': VoiceActionType.scrollDown,
      'Scroll down': VoiceActionType.scrollDown,
      'انزل شوي': VoiceActionType.scrollDown,
      'سكرول اب': VoiceActionType.scrollUp,
      'اطلع شوي لفوق': VoiceActionType.scrollUp,
      'انزل للاخير': VoiceActionType.scrollBottom,
      'لآخر الصفحة': VoiceActionType.scrollBottom,
      'اطلع لفوق': VoiceActionType.scrollUp,
      'ارجع': VoiceActionType.back,
      'اقرأ الشاشة': VoiceActionType.readScreen,
      'شو في عالشاشة': VoiceActionType.readScreen,
      'نام': VoiceActionType.sleep,
      'كبّر الخط': VoiceActionType.largerText,
      'شغل التباين': VoiceActionType.highContrastOn,
      'احكي أبطأ': VoiceActionType.slower,
      'سجل خروج': VoiceActionType.logout,
      'اطلع من الحساب': VoiceActionType.logout,
      'امسح المحادثة': VoiceActionType.clearChat,
      'كم الساعة': VoiceActionType.time,
      'شو بتقدر تعمل؟': VoiceActionType.help,
      'يا مساعد': VoiceActionType.wake,
      'ادخل': VoiceActionType.login,
    };
    cases.forEach((text, type) {
      test(text, () => expect(parse(text)?.type, type));
    });

    test('login role', () {
      expect(parse('ادخل كمستخدم')?.arg, 'user');
      expect(parse('سجل دخول كمدير')?.arg, 'admin');
    });

    test('pdf report with status filter', () {
      final a = parse('اعمل تقرير PDF للفواتير المعلقة');
      expect(a?.type, VoiceActionType.pdfReport);
      expect(a?.arg, 'PENDING');
    });

    test('short words inside longer requests are not hijacked', () {
      // "بس" (stop) inside a real request must reach the AI.
      expect(parse('اعرض المنتجات اللي سعرها بس أقل من ألف'), isNull);
    });
  });

  group('invoice filters', () {
    final cases = {
      'اعرض الفواتير المعلقة': 'PENDING',
      'الفواتير المدفوعة': 'PAID',
      'فلتر المسودة': 'DRAFT',
      'بس المسودات': 'DRAFT',
      'افتح الفواتير الملغاة': 'CANCELLED',
    };
    cases.forEach((text, status) {
      test(text, () {
        final a = parse(text);
        expect(a?.type, VoiceActionType.filterInvoices);
        expect(a?.arg, status);
      });
    });

    test('all invoices clears the filter', () {
      final a = parse('اعرض كل الفواتير');
      expect(a?.type, VoiceActionType.filterInvoices);
      expect(a?.arg, isNull);
    });
  });

  group('command sequences', () {
    List<VoiceActionType>? seq(String t) =>
        VoiceCommandRouter.parseSequence(t)?.map((a) => a.type).toList();

    test('the exact sentence from device testing', () {
      expect(seq('افتح الفواتير المدفوعة، وانزل للاخير'), [
        VoiceActionType.filterInvoices,
        VoiceActionType.scrollBottom,
      ]);
    });

    test('joined with و and ثم', () {
      expect(seq('افتح العملاء وانزل لتحت'), [
        VoiceActionType.navigate,
        VoiceActionType.scrollDown,
      ]);
      expect(seq('روح عالمنتجات ثم اقرأ الشاشة'), [
        VoiceActionType.navigate,
        VoiceActionType.readScreen,
      ]);
    });

    test('a single command or an AI request is not a sequence', () {
      expect(seq('افتح العملاء'), isNull);
      expect(seq('أضف عميل اسمه سارة، ورقمها 0944001122'), isNull);
    });
  });

  group('wake word & confirmation', () {
    test('afterWakeWord returns the remainder', () {
      expect(VoiceCommandRouter.afterWakeWord(ArabicText.normalize('يا مساعد افتح العملاء')), 'افتح العملاء');
      expect(VoiceCommandRouter.afterWakeWord(ArabicText.normalize('يا مساعد')), '');
      expect(VoiceCommandRouter.afterWakeWord(ArabicText.normalize('كيف حالك')), isNull);
    });

    test('yes / no', () {
      bool? c(String t) => VoiceCommandRouter.parseConfirmation(ArabicText.normalize(t));
      expect(c('نعم'), isTrue);
      expect(c('إي أكيد'), isTrue);
      expect(c('لا'), isFalse);
      expect(c('لأ ما بدي'), isFalse);
      expect(c('اعرض العملاء'), isNull);
    });
  });
}
