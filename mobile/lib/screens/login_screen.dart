import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../providers/voice_assistant_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/server_settings_card.dart';
import '../widgets/voice_orb.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController(text: 'admin@accounting.local');
  final _passwordController = TextEditingController(text: 'admin123');
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  late final VoiceAssistantProvider _voice;

  @override
  void initState() {
    super.initState();
    _voice = context.read<VoiceAssistantProvider>();
    _voice.loginHandler = _voiceLogin;
  }

  @override
  void dispose() {
    if (_voice.loginHandler == _voiceLogin) _voice.loginHandler = null;
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// "ادخل كمدير" / "ادخل كمستخدم" fill the demo account; "ادخل" uses the form.
  Future<bool> _voiceLogin(String? role) async {
    if (role == 'user') {
      _emailController.text = 'user@accounting.local';
      _passwordController.text = 'user123';
    } else if (role == 'admin' && _emailController.text.trim().isEmpty) {
      _emailController.text = 'admin@accounting.local';
      _passwordController.text = 'admin123';
    }
    return _login();
  }

  Future<bool> _login() async {
    if (!_formKey.currentState!.validate()) return false;
    // The auth gate swaps to the main shell when this succeeds.
    return context.read<AuthProvider>().login(
          _emailController.text.trim(),
          _passwordController.text,
        );
  }

  void _openServerSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.viewInsetsOf(ctx).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              const ServerSettingsCard(compact: true),
            ],
          ),
        );
      },
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final voice = context.watch<VoiceAssistantProvider>();
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  tooltip: 'إعدادات السيرفر',
                  onPressed: _openServerSettings,
                  icon: const Icon(Icons.settings_ethernet_rounded, color: Colors.white),
                ),
              ),
              Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 420, minHeight: size.height * 0.7),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Semantics(
                      button: true,
                      label: 'المساعد الصوتي. ${voice.statusLabel}',
                      child: GestureDetector(
                        onTap: voice.onOrbTap,
                        child: VoiceOrb(phase: voice.phase, level: voice.level, size: 170),
                      ),
                    ),
                    Text(
                      voice.hint ?? voice.statusLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF99E9F2), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'محاسب+',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'مساعد محاسبة صوتي لذوي الإعاقة الحركية',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.mic_rounded, color: Color(0xFF99E9F2)),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'بدون يدين: قل «ادخل» لتسجيل الدخول بصوتك',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'تسجيل الدخول',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink),
                            ),
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textDirection: TextDirection.ltr,
                              decoration: const InputDecoration(
                                labelText: 'البريد الإلكتروني',
                                prefixIcon: Icon(Icons.mail_outline_rounded),
                              ),
                              validator: (v) => v != null && v.contains('@') ? null : 'أدخل بريداً صحيحاً',
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscure,
                              textDirection: TextDirection.ltr,
                              decoration: InputDecoration(
                                labelText: 'كلمة المرور',
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                ),
                              ),
                              validator: (v) => v != null && v.length >= 6 ? null : '6 أحرف على الأقل',
                            ),
                            if (auth.error != null) ...[
                              const SizedBox(height: 12),
                              Text(auth.error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                            ],
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 52,
                              child: FilledButton(
                                onPressed: auth.loading ? null : _login,
                                child: auth.loading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text('دخول'),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'تجريبي: admin@accounting.local / admin123',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.muted.withValues(alpha: 0.9), fontSize: 12),
                            ),
                            const SizedBox(height: 10),
                            TextButton.icon(
                              onPressed: _openServerSettings,
                              icon: const Icon(Icons.dns_rounded, size: 18),
                              label: Text(
                                'السيرفر: ${ApiConfig.host}',
                                textDirection: TextDirection.ltr,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
