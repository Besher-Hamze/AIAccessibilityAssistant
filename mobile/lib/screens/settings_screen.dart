import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/accessibility_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/server_settings_card.dart';
import 'audit_screen.dart';
import 'help_screen.dart';
import 'users_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final a11y = context.watch<AccessibilityProvider>();
    final auth = context.watch<AuthProvider>();
    final chat = context.watch<ChatProvider>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.deepTeal, AppColors.teal],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'الإعدادات',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'السيرفر · الوصولية · المساعدة',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'السيرفر',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const ServerSettingsCard(),
        const SizedBox(height: 18),
        const Text(
          'الوصولية',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        _SwitchTile(
          title: 'تباين عالي',
          subtitle: 'ألوان أوضح ونصوص أقوى',
          value: a11y.highContrast,
          onChanged: a11y.setHighContrast,
          icon: Icons.contrast_rounded,
        ),
        _SwitchTile(
          title: 'أزرار كبيرة',
          subtitle: 'مساحات لمس أوسع وأسهل',
          value: a11y.largeControls,
          onChanged: a11y.setLargeControls,
          icon: Icons.touch_app_rounded,
        ),
        _SwitchTile(
          title: 'اضغط للتحدث',
          subtitle: 'ضغطة للبدء وضغطة للإيقاف (بدل الضغط المطوّل)',
          value: a11y.tapToTalk,
          onChanged: a11y.setTapToTalk,
          icon: Icons.mic_rounded,
        ),
        _SwitchTile(
          title: 'قراءة الردود صوتياً',
          subtitle: 'تشغيل Text-to-Speech تلقائياً',
          value: a11y.autoSpeak,
          onChanged: (v) {
            a11y.setAutoSpeak(v);
            chat.setAutoSpeak(v);
          },
          icon: Icons.volume_up_rounded,
        ),
        const SizedBox(height: 12),
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          tileColor: Colors.white,
          leading: const Icon(Icons.help_outline_rounded, color: AppColors.teal),
          title: const Text('أمثلة الأوامر الصوتية', style: TextStyle(fontWeight: FontWeight.w700)),
          trailing: const Icon(Icons.chevron_left),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HelpScreen()),
            );
          },
        ),
        if (auth.user?.isAdmin == true) ...[
          const SizedBox(height: 8),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            tileColor: Colors.white,
            leading: const Icon(Icons.people_alt_rounded, color: AppColors.teal),
            title: const Text('إدارة المستخدمين', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('إضافة مستخدمين وتعيين كلمة المرور'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UsersScreen()),
              );
            },
          ),
          const SizedBox(height: 8),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            tileColor: Colors.white,
            leading: const Icon(Icons.history_rounded, color: AppColors.coral),
            title: const Text('سجل العمليات', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('من نفّذ ماذا ومتى'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AuditScreen()),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData icon;

  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.deepTeal.withValues(alpha: 0.06)),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        secondary: Icon(icon, color: AppColors.teal),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      ),
    );
  }
}
