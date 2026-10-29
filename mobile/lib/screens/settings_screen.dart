import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/accessibility_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/navigation_provider.dart';
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
    final nav = context.read<NavigationProvider>();

    final width = MediaQuery.sizeOf(context).width;
    final side = width > 820 ? (width - 780) / 2 : 16.0;

    return ListView(
      padding: EdgeInsets.fromLTRB(side, 8, side, 120),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(24),
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
                'التحكم الصوتي · الوصولية · السيرفر',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'التحكم الصوتي',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        _SwitchTile(
          title: 'الاستماع الدائم (بدون لمس)',
          subtitle: 'يستمع المساعد تلقائياً بعد كل رد، دون الحاجة لأي ضغطة',
          value: a11y.handsFree,
          onChanged: a11y.setHandsFree,
          icon: Icons.hearing_rounded,
        ),
        _SwitchTile(
          title: 'وضع الراحة وكلمة التنبيه',
          subtitle: 'بعد دقيقة من الصمت ينام المساعد، ويستيقظ عند قول «يا مساعد»',
          value: a11y.autoSleep,
          onChanged: a11y.setAutoSleep,
          icon: Icons.bedtime_rounded,
        ),
        _SwitchTile(
          title: 'قراءة الردود صوتياً',
          subtitle: 'تشغيل Text-to-Speech تلقائياً',
          value: a11y.autoSpeak,
          onChanged: a11y.setAutoSpeak,
          icon: Icons.volume_up_rounded,
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.navy.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.speed_rounded, color: AppColors.primary),
                  SizedBox(width: 12),
                  Text('سرعة الكلام', style: TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
              Slider(
                value: a11y.speechRate,
                min: 0.2,
                max: 0.9,
                divisions: 7,
                label: a11y.speechRate < 0.42
                    ? 'بطيء'
                    : (a11y.speechRate > 0.62 ? 'سريع' : 'عادي'),
                onChanged: a11y.setSpeechRate,
              ),
            ],
          ),
        ),
        _ModelPicker(chat: chat),
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
        const SizedBox(height: 18),
        const Text(
          'السيرفر',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const ServerSettingsCard(),
        const SizedBox(height: 12),
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          tileColor: Colors.white,
          leading: const Icon(Icons.delete_outline_rounded, color: AppColors.rose),
          title: const Text('حذف المحادثة', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('مسح كل رسائل المساعد من هذا الحساب'),
          trailing: const Icon(Icons.chevron_left),
          onTap: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('حذف المحادثة'),
                content: const Text(
                  'سيتم حذف كل الرسائل من هذا الحساب. لا يمكن التراجع.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('إلغاء'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('حذف'),
                  ),
                ],
              ),
            );
            if (confirmed != true || !context.mounted) return;
            final ok = await chat.clearHistory();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(ok ? 'تم حذف المحادثة' : 'تعذر حذف المحادثة')),
            );
          },
        ),
        const SizedBox(height: 8),
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          tileColor: Colors.white,
          leading: const Icon(Icons.help_outline_rounded, color: AppColors.primary),
          title: const Text('أمثلة الأوامر الصوتية', style: TextStyle(fontWeight: FontWeight.w700)),
          trailing: const Icon(Icons.chevron_left),
          onTap: () {
            nav.push(const HelpScreen());
          },
        ),
        if (auth.user?.isAdmin == true) ...[
          const SizedBox(height: 8),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            tileColor: Colors.white,
            leading: const Icon(Icons.people_alt_rounded, color: AppColors.primary),
            title: const Text('إدارة المستخدمين', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('إضافة مستخدمين وتعيين كلمة المرور'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              nav.push(const UsersScreen());
            },
          ),
          const SizedBox(height: 8),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            tileColor: Colors.white,
            leading: const Icon(Icons.history_rounded, color: AppColors.rose),
            title: const Text('سجل العمليات', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('من نفّذ ماذا ومتى'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              nav.push(const AuditScreen());
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
        border: Border.all(color: AppColors.navy.withValues(alpha: 0.06)),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        secondary: Icon(icon, color: AppColors.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      ),
    );
  }
}

class _ModelPicker extends StatelessWidget {
  final ChatProvider chat;

  const _ModelPicker({required this.chat});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.navy.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          const Icon(Icons.memory_rounded, color: AppColors.primary),
          const SizedBox(width: 12),
          const Text('نموذج الذكاء', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(width: 12),
          Expanded(
            child: chat.modelsLoading && chat.availableModels.isEmpty
                ? const Text('جاري جلب النماذج...', style: TextStyle(color: AppColors.muted))
                : DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: chat.availableModels.contains(chat.selectedModel)
                          ? chat.selectedModel
                          : null,
                      hint: Text(
                        chat.availableModels.isEmpty
                            ? 'لا توجد نماذج (تحقق من Ollama)'
                            : 'اختر النموذج',
                      ),
                      items: chat.availableModels
                          .map((m) => DropdownMenuItem(
                                value: m,
                                child: Text(m, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: chat.isProcessing ? null : chat.setSelectedModel,
                    ),
                  ),
          ),
          IconButton(
            tooltip: 'تحديث النماذج',
            onPressed: chat.modelsLoading ? null : chat.loadModels,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
