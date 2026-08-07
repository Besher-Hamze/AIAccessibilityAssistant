import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'config/api_config.dart';
import 'providers/accessibility_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/data_provider.dart';
import 'providers/demo_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.init();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AccessibilityProvider()..init()),
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => DemoProvider()),
        ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
          create: (ctx) => ChatProvider(ctx.read<AuthProvider>().apiService),
          update: (_, auth, previous) {
            return previous ?? ChatProvider(auth.apiService);
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, DataProvider>(
          create: (ctx) => DataProvider(ctx.read<AuthProvider>().apiService),
          update: (_, auth, previous) {
            return previous ?? DataProvider(auth.apiService);
          },
        ),
      ],
      child: Consumer<AccessibilityProvider>(
        builder: (context, a11y, _) {
          return MaterialApp(
            title: 'محاسب+',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(
              highContrast: a11y.highContrast,
              largeControls: a11y.largeControls,
            ),
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(a11y.largeControls ? 1.08 : 1.0),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: const _AuthGate(),
          );
        },
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isAuthenticated) {
          return const MainShell();
        }
        return const Directionality(
          textDirection: TextDirection.rtl,
          child: LoginScreen(),
        );
      },
    );
  }
}
