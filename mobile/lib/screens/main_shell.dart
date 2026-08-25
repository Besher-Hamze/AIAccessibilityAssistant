import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/accessibility_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/data_provider.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import 'customers_screen.dart';
import 'dashboard_screen.dart';
import 'help_screen.dart';
import 'invoices_screen.dart';
import 'login_screen.dart';
import 'products_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DataProvider>().loadAll();
      final a11y = context.read<AccessibilityProvider>();
      context.read<ChatProvider>().setAutoSpeak(a11y.autoSpeak);
    });
  }

  void openChat() => setState(() => _index = 4);

  Future<void> _confirmClearChat(BuildContext context) async {
    final chat = context.read<ChatProvider>();
    if (chat.messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد محادثة لحذفها')),
      );
      return;
    }
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
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final pages = [
      DashboardScreen(onOpenChat: openChat),
      const CustomersScreen(),
      const ProductsScreen(),
      const InvoicesScreen(),
      const ChatScreen(),
      const SettingsScreen(),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            switch (_index) {
              0 => 'محاسب+',
              1 => 'العملاء',
              2 => 'المنتجات',
              3 => 'الفواتير',
              4 => 'المساعد الذكي',
              _ => 'الوصولية والإعدادات',
            },
          ),
          actions: [
            if (_index == 4)
              IconButton(
                tooltip: 'حذف المحادثة',
                onPressed: () => _confirmClearChat(context),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            IconButton(
              tooltip: 'دليل الأوامر',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HelpScreen()),
                );
              },
              icon: const Icon(Icons.help_outline_rounded),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.mint.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    auth.user?.name ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.teal,
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'تسجيل الخروج',
              onPressed: () async {
                await auth.logout();
                if (context.mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                }
              },
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        body: IndexedStack(index: _index, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index > 4 ? 5 : _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'الرئيسية',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people_rounded),
              label: 'عملاء',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2_rounded),
              label: 'منتجات',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'فواتير',
            ),
            NavigationDestination(
              icon: Icon(Icons.mic_none_rounded),
              selectedIcon: Icon(Icons.mic_rounded),
              label: 'مساعد',
            ),
            NavigationDestination(
              icon: Icon(Icons.accessibility_new_outlined),
              selectedIcon: Icon(Icons.accessibility_new_rounded),
              label: 'وصولية',
            ),
          ],
        ),
      ),
    );
  }
}
