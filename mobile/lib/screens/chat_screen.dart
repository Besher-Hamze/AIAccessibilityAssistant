import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/voice_commands.dart';
import '../providers/accessibility_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/data_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chat = context.read<ChatProvider>();
      chat.loadHistory();
      chat.loadModels();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send(ChatProvider chat, String text) async {
    _textController.clear();
    final mutated = await chat.sendTextMessage(text);
    if (mutated && mounted) {
      await context.read<DataProvider>().loadAll();
    }
  }

  Future<void> _handleMicTap(ChatProvider chat, AccessibilityProvider a11y) async {
    if (chat.isProcessing) return;
    if (!a11y.tapToTalk) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اضغط مطولاً على الميكروفون، أو فعّل "اضغط للتحدث" من الوصولية')),
      );
      return;
    }
    if (chat.isRecording) {
      await chat.stopRecordingAndSend();
      if (mounted) await context.read<DataProvider>().loadAll();
    } else {
      await chat.startRecording();
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    Future.delayed(const Duration(milliseconds: 80), () {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final a11y = context.watch<AccessibilityProvider>();
    final micSize = a11y.largeControls ? 64.0 : 52.0;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Column(
      children: [
        if (chat.error != null)
          MaterialBanner(
            content: Text(chat.error!),
            backgroundColor: AppColors.danger.withValues(alpha: 0.12),
            leading: const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            actions: [
              TextButton(onPressed: chat.clearError, child: const Text('إغلاق')),
            ],
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              const Icon(Icons.memory_rounded, size: 18, color: AppColors.teal),
              const SizedBox(width: 8),
              const Text(
                'الموديل',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.deepTeal.withValues(alpha: 0.12),
                    ),
                  ),
                  child: chat.modelsLoading && chat.availableModels.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'جاري جلب الموديلات...',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        )
                      : DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: chat.availableModels.contains(chat.selectedModel)
                                ? chat.selectedModel
                                : null,
                            hint: Text(
                              chat.availableModels.isEmpty
                                  ? 'لا توجد موديلات (تحقق من Ollama)'
                                  : 'اختر الموديل',
                            ),
                            items: chat.availableModels
                                .map(
                                  (m) => DropdownMenuItem(
                                    value: m,
                                    child: Text(m, overflow: TextOverflow.ellipsis),
                                  ),
                                )
                                .toList(),
                            onChanged: chat.isProcessing
                                ? null
                                : (value) => chat.setSelectedModel(value),
                          ),
                        ),
                ),
              ),
              IconButton(
                tooltip: 'تحديث الموديلات',
                onPressed: chat.modelsLoading ? null : chat.loadModels,
                icon: chat.modelsLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, color: AppColors.teal),
              ),
            ],
          ),
        ),
        SizedBox(
          height: a11y.largeControls ? 56 : 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: VoiceCommands.examples.map((cmd) {
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ActionChip(
                  avatar: const Icon(Icons.bolt_rounded, size: 16, color: AppColors.teal),
                  label: Text(cmd),
                  onPressed: chat.isProcessing ? null : () => _send(chat, cmd),
                ),
              );
            }).toList(),
          ),
        ),
        if (chat.isRecording)
          Container(
            width: double.infinity,
            color: AppColors.danger.withValues(alpha: 0.1),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              a11y.tapToTalk
                  ? 'جاري التسجيل... اضغط الميكروفون مرة أخرى للإرسال'
                  : 'جاري التسجيل... أفلت الزر للإرسال',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        Expanded(
          child: chat.messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 78,
                          height: 78,
                          decoration: BoxDecoration(
                            color: AppColors.mint.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.record_voice_over_rounded, size: 36, color: AppColors.teal),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'المساعد جاهز',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          a11y.tapToTalk
                              ? 'اضغط الميكروفون للتحدث ثم اضغط مرة أخرى للإرسال.\nيمكنك بالصوت: إضافة عميل، إنشاء فاتورة، عرض المنتجات، والملخص.'
                              : 'اضغط مطولاً على الميكروفون للتحدث.\nيمكنك بالصوت: إضافة عميل، إنشاء فاتورة، عرض المنتجات، والملخص.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.muted, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: chat.messages.length,
                  itemBuilder: (context, index) {
                    final msg = chat.messages[index];
                    return MessageBubble(
                      message: msg,
                      onSpeak: msg.isAssistant && !msg.isLoading
                          ? () => chat.speakMessage(msg.content)
                          : null,
                      isSpeaking:
                          chat.isSpeaking && chat.speakingText == msg.content,
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                IconButton(
                  tooltip: chat.isSpeaking
                      ? 'إيقاف القراءة الآن'
                      : (chat.autoSpeak ? 'إيقاف القراءة التلقائية' : 'تفعيل القراءة التلقائية'),
                  onPressed: () async {
                    if (chat.isSpeaking) {
                      await chat.stopSpeaking();
                    } else {
                      await chat.toggleAutoSpeak();
                    }
                  },
                  icon: Icon(
                    chat.isSpeaking
                        ? Icons.stop_circle_rounded
                        : (chat.autoSpeak
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded),
                    color: chat.isSpeaking ? AppColors.danger : AppColors.teal,
                    size: a11y.largeControls ? 28 : 24,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(fontSize: a11y.largeControls ? 17 : 15),
                    decoration: InputDecoration(
                      hintText: 'اكتب أمرك المحاسبي...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: a11y.largeControls ? 16 : 12,
                      ),
                    ),
                    onSubmitted: (text) => _send(chat, text),
                    enabled: !chat.isProcessing,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _handleMicTap(chat, a11y),
                  onLongPressStart: a11y.tapToTalk || chat.isProcessing
                      ? null
                      : (_) => chat.startRecording(),
                  onLongPressEnd: a11y.tapToTalk || chat.isProcessing
                      ? null
                      : (_) async {
                          await chat.stopRecordingAndSend();
                          if (context.mounted) {
                            context.read<DataProvider>().loadAll();
                          }
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: micSize,
                    height: micSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: chat.isRecording ? AppColors.danger : AppColors.coral,
                      boxShadow: chat.isRecording
                          ? [BoxShadow(color: AppColors.danger.withValues(alpha: 0.35), blurRadius: 14)]
                          : null,
                    ),
                    child: Icon(
                      chat.isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                      color: Colors.white,
                      size: a11y.largeControls ? 30 : 24,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: chat.isProcessing
                      ? null
                      : () => _send(chat, _textController.text),
                  icon: Icon(Icons.send_rounded, size: a11y.largeControls ? 28 : 24),
                  color: AppColors.teal,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
