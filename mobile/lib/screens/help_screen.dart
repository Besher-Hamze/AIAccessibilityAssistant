import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/voice_commands.dart';
import '../providers/voice_assistant_provider.dart';
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'قل أي أمر بصوتك، أو اضغط عليه لتنفيذه مباشرة.\n'
                'لا حاجة للمس: قل «يا مساعد» ثم الأمر.',
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
                          side: BorderSide(color: AppColors.navy.withValues(alpha: 0.08)),
                        ),
                        tileColor: Colors.white,
                        leading: const Icon(Icons.mic_rounded, color: AppColors.rose),
                        title: Text(cmd),
                        onTap: () {
                          Navigator.pop(context);
                          context.read<VoiceAssistantProvider>().submitText(cmd);
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
