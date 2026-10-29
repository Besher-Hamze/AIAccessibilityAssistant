import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/voice_commands.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/data_provider.dart';
import '../providers/demo_provider.dart';
import '../providers/voice_assistant_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/report_pdf_helper.dart';
import '../widgets/status_badge.dart';
import '../widgets/voice_orb.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<void> _runDemo(BuildContext context) async {
    final voice = context.read<VoiceAssistantProvider>();
    voice.expand();
    await context.read<DemoProvider>().runDemo(
          context.read<ChatProvider>(),
          context.read<DataProvider>(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final data = context.watch<DataProvider>();
    final demo = context.watch<DemoProvider>();
    final voice = context.watch<VoiceAssistantProvider>();
    final s = data.summary;
    final width = MediaQuery.sizeOf(context).width;
    // Keep content readable on wide desktop windows.
    final side = width > 820 ? (width - 780) / 2 : 16.0;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: data.loadAll,
      child: ListView(
        padding: EdgeInsets.fromLTRB(side, 4, side, 120),
        children: [
          _VoiceHero(
            name: auth.user?.name ?? '',
            role: auth.user?.isAdmin == true ? 'مدير النظام' : 'مستخدم',
            status: voice.statusLabel,
            phase: voice.phase,
            level: voice.level,
            onTap: voice.expand,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ActionTile(
                  icon: demo.running ? Icons.hourglass_top_rounded : Icons.play_circle_rounded,
                  label: demo.running ? 'جاري العرض…' : 'عرض تجريبي',
                  color: AppColors.violet,
                  onTap: demo.running ? null : () => _runDemo(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionTile(
                  icon: Icons.picture_as_pdf_rounded,
                  label: 'تقرير PDF',
                  color: AppColors.rose,
                  onTap: () => generateAndOpenInvoiceReportPdf(context),
                ),
              ),
            ],
          ),
          if (demo.status != null) ...[
            const SizedBox(height: 8),
            Text(demo.status!, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          ],
          const SizedBox(height: 22),
          const _SectionTitle('نظرة عامة'),
          const SizedBox(height: 10),
          if (data.loadingSummary && s == null)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else ...[
            GridView(
              shrinkWrap: true,
              primary: false,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: width > 700 ? 4 : 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: 92,
              ),
              children: [
                _StatTile(
                  title: 'الفواتير',
                  value: '${s?['totalInvoices'] ?? 0}',
                  icon: Icons.receipt_long_rounded,
                  color: AppColors.primary,
                ),
                _StatTile(
                  title: 'العملاء',
                  value: '${s?['customersCount'] ?? 0}',
                  icon: Icons.people_alt_rounded,
                  color: AppColors.accent,
                ),
                _StatTile(
                  title: 'المنتجات',
                  value: '${s?['productsCount'] ?? 0}',
                  icon: Icons.inventory_2_rounded,
                  color: AppColors.amber,
                ),
                _StatTile(
                  title: 'معلقة',
                  value: '${s?['pendingCount'] ?? 0}',
                  icon: Icons.pending_actions_rounded,
                  color: AppColors.rose,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MoneyTile(
                    title: 'المبلغ المدفوع',
                    value: AppFormat.money(num.tryParse('${s?['paidAmount'] ?? 0}') ?? 0),
                    color: AppColors.success,
                    icon: Icons.check_circle_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MoneyTile(
                    title: 'المبلغ المعلق',
                    value: AppFormat.money(num.tryParse('${s?['pendingAmount'] ?? 0}') ?? 0),
                    color: AppColors.warning,
                    icon: Icons.schedule_rounded,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 22),
          const _SectionTitle('جرّب أن تقول'),
          const SizedBox(height: 10),
          ...VoiceCommands.examples.take(4).map(
                (cmd) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SayCard(text: cmd, onTap: () => voice.submitText(cmd)),
                ),
              ),
          const SizedBox(height: 18),
          const _SectionTitle('آخر الفواتير'),
          const SizedBox(height: 10),
          if (s?['recentInvoices'] is List && (s!['recentInvoices'] as List).isNotEmpty)
            ...((s['recentInvoices'] as List).map((raw) {
              final inv = raw as Map<String, dynamic>;
              final customer = inv['customer'] as Map<String, dynamic>?;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.navy.withValues(alpha: 0.06)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.receipt_rounded, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer?['name']?.toString() ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                          Text(
                            inv['number']?.toString() ?? '',
                            style: const TextStyle(color: AppColors.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          AppFormat.money(num.tryParse('${inv['total']}') ?? 0),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        StatusBadge(status: inv['status']?.toString() ?? 'PENDING'),
                      ],
                    ),
                  ],
                ),
              );
            }))
          else
            const Text('لا توجد فواتير حديثة', style: TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _VoiceHero extends StatelessWidget {
  final String name;
  final String role;
  final String status;
  final VoicePhase phase;
  final ValueNotifier<double> level;
  final VoidCallback onTap;

  const _VoiceHero({
    required this.name,
    required this.role,
    required this.status,
    required this.phase,
    required this.level,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'افتح المساعد الصوتي',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Ink(
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 8, 18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مرحباً، $name',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          role,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            status,
                            style: const TextStyle(color: Color(0xFFC5F6FA), fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'تحكّم بكل شيء بصوتك — اضغط هنا لفتح المساعد',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  VoiceOrb(phase: phase, level: level, size: 132),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700));
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionTile({required this.icon, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SayCard extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _SayCard({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.navy.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [AppColors.accent, AppColors.violet]),
                ),
                child: const Icon(Icons.mic_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('«$text»', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              const Icon(Icons.chevron_left_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$title: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.navy.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    child: Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                  ),
                  Text(title, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoneyTile extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _MoneyTile({required this.title, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            child: Text(value, style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
