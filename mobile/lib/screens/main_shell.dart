import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/accessibility_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../providers/navigation_provider.dart';
import '../theme/app_theme.dart';
import 'customers_screen.dart';
import 'dashboard_screen.dart';
import 'help_screen.dart';
import 'invoices_screen.dart';
import 'products_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const _titles = ['محاسب+', 'العملاء', 'المنتجات', 'الفواتير', 'الإعدادات'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DataProvider>().loadAll();
    });
  }

  Future<void> _logout(BuildContext context) async {
    final nav = context.read<NavigationProvider>();
    final auth = context.read<AuthProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('خروج'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    nav.reset();
    await auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final nav = context.watch<NavigationProvider>();
    final index = nav.tab;
    final pages = <Widget>[
      const DashboardScreen(),
      const CustomersScreen(),
      const ProductsScreen(),
      const InvoicesScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[index]),
        leadingWidth: 64,
        leading: index == 0
            ? null
            : IconButton(
                tooltip: 'الرئيسية',
                onPressed: () => nav.goTab(0),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
        actions: [
          IconButton(
            tooltip: 'دليل الأوامر',
            onPressed: () => nav.push(const HelpScreen()),
            icon: const Icon(Icons.help_outline_rounded),
          ),
          IconButton(
            tooltip: 'الإعدادات',
            isSelected: index == NavigationProvider.settingsTab,
            onPressed: () => nav.goTab(NavigationProvider.settingsTab),
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded, color: AppColors.primary),
          ),
          PopupMenuButton<String>(
            tooltip: auth.user?.name ?? 'الحساب',
            onSelected: (v) {
              if (v == 'logout') _logout(context);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text(
                  '${auth.user?.name ?? ''} · ${auth.user?.isAdmin == true ? 'مدير' : 'مستخدم'}',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, color: AppColors.danger),
                    SizedBox(width: 10),
                    Text('تسجيل الخروج'),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: CircleAvatar(
                radius: 19,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  (auth.user?.name.isNotEmpty ?? false) ? auth.user!.name.characters.first : '؟',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: index,
        children: [
          for (var i = 0; i < pages.length; i++)
            PrimaryScrollController(
              controller: nav.scrollFor(i),
              automaticallyInheritForPlatforms: TargetPlatform.values.toSet(),
              child: pages[i],
            ),
        ],
      ),
      bottomNavigationBar: _VoiceNavBar(
        index: index,
        onSelect: nav.goTab,
      ),
    );
  }
}

/// Bottom bar with a free slot in the middle where the floating
/// assistant orb (drawn by AssistantLayer) sits.
class _VoiceNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;

  const _VoiceNavBar({required this.index, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final large = context.watch<AccessibilityProvider>().largeControls;

    Widget item(int i, IconData icon, IconData selectedIcon, String label) {
      final selected = index == i;
      return Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          label: label,
          excludeSemantics: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => onSelect(i),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    selected ? selectedIcon : icon,
                    size: large ? 28 : 24,
                    color: selected ? AppColors.primary : AppColors.muted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: large ? 13 : 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.primary : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: large ? 80 : 70,
          child: Row(
            children: [
              item(0, Icons.home_outlined, Icons.home_rounded, 'الرئيسية'),
              item(1, Icons.people_outline_rounded, Icons.people_rounded, 'العملاء'),
              const SizedBox(width: 96),
              item(2, Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'المنتجات'),
              item(3, Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'الفواتير'),
            ],
          ),
        ),
      ),
    );
  }
}
