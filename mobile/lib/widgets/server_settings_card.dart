import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../theme/app_theme.dart';

class ServerSettingsCard extends StatefulWidget {
  final bool compact;

  const ServerSettingsCard({super.key, this.compact = false});

  @override
  State<ServerSettingsCard> createState() => _ServerSettingsCardState();
}

class _ServerSettingsCardState extends State<ServerSettingsCard> {
  late final TextEditingController _controller;
  bool _saving = false;
  bool _testing = false;
  String? _message;
  bool _ok = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ApiConfig.host);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await ApiConfig.setHost(_controller.text);
      _controller.text = ApiConfig.host;
      setState(() {
        _ok = true;
        _message = 'تم الحفظ: ${ApiConfig.baseUrl}';
      });
    } catch (e) {
      setState(() {
        _ok = false;
        _message = e.toString().replaceAll('Exception: ', '');
      });
    }
    setState(() => _saving = false);
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _message = null;
    });
    try {
      await ApiConfig.setHost(_controller.text);
      _controller.text = ApiConfig.host;
      final response = await http
          .get(Uri.parse('http://${ApiConfig.host}/api'))
          .timeout(const Duration(seconds: 4));
      // Any HTTP response means the backend host is reachable.
      setState(() {
        _ok = true;
        _message = 'الاتصال ناجح (${response.statusCode}) — ${ApiConfig.baseUrl}';
      });
    } catch (e) {
      setState(() {
        _ok = false;
        _message = 'فشل الاتصال. تأكد من IP وأن Backend يعمل.';
      });
    }
    setState(() => _testing = false);
  }

  Future<void> _reset() async {
    await ApiConfig.resetToDefault();
    _controller.text = ApiConfig.host;
    setState(() {
      _ok = true;
      _message = 'تمت الاستعادة للافتراضي: ${ApiConfig.host}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(widget.compact ? 14 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.deepTeal.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.dns_rounded, color: AppColors.teal),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'عنوان السيرفر (Backend)',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              TextButton(
                onPressed: _reset,
                child: const Text('افتراضي', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'أدخل IP الجهاز الذي يشغّل NestJS\nمثال: 192.168.1.10 أو 192.168.1.10:3000',
            style: TextStyle(color: AppColors.muted, fontSize: widget.compact ? 11 : 12, height: 1.35),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Host / IP',
              hintText: '192.168.1.10:3000',
              prefixIcon: Icon(Icons.lan_outlined),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'API: ${ApiConfig.baseUrl}',
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _testing ? null : _test,
                  icon: _testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering_rounded),
                  label: const Text('اختبار'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_rounded),
                  label: const Text('حفظ'),
                ),
              ),
            ],
          ),
          if (_message != null) ...[
            const SizedBox(height: 10),
            Text(
              _message!,
              style: TextStyle(
                color: _ok ? AppColors.success : AppColors.danger,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
