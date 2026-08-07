import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/voice_commands.dart';
import '../providers/chat_provider.dart';
import '../providers/data_provider.dart';
import '../theme/app_theme.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('دليل الأوامر')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.mint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'اضغط على أي أمر لإرساله مباشرة إلى المساعد الذكي.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
            ...VoiceCommands.helpSections.map((section) {
              final items = section['items'] as List<String>;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section['title'] as String,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  ...items.map(
                    (cmd) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: AppColors.deepTeal.withValues(alpha: 0.08)),
                        ),
                        tileColor: Colors.white,
                        leading: const Icon(Icons.mic_rounded, color: AppColors.coral),
                        title: Text(cmd),
                        onTap: () async {
                          Navigator.pop(context);
                          final mutated =
                              await context.read<ChatProvider>().sendTextMessage(cmd);
                          if (mutated && context.mounted) {
                            await context.read<DataProvider>().loadAll();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            }),
            const Text(
              'الصلاحيات',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              '• المستخدم: بحث، إنشاء عميل، إنشاء فاتورة\n'
              '• المدير: كل ما سبق + تعديل/حذف + تغيير حالة الفاتورة + سجل العمليات',
              style: TextStyle(height: 1.5, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
