import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
      context.read<ChatProvider>().loadHistory();
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
                        const Text(
                          'اكتب أو اضغط مطولاً على الميكروفون\nمثال: أنشئ فاتورة لمحمد بمنتج برنامج محاسبة',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted, height: 1.5),
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
                      onSpeak: msg.isAssistant ? () => chat.speakMessage(msg.content) : null,
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
                  tooltip: chat.autoSpeak ? 'إيقاف الصوت' : 'تفعيل الصوت',
                  onPressed: chat.toggleAutoSpeak,
                  icon: Icon(
                    chat.autoSpeak ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                    color: AppColors.teal,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      hintText: 'اكتب أمرك المحاسبي...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (text) => _send(chat, text),
                    enabled: !chat.isProcessing,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onLongPressStart: chat.isProcessing ? null : (_) => chat.startRecording(),
                  onLongPressEnd: chat.isProcessing
                      ? null
                      : (_) async {
                          await chat.stopRecordingAndSend();
                          if (context.mounted) {
                            context.read<DataProvider>().loadAll();
                          }
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 52,
                    height: 52,
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
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: chat.isProcessing
                      ? null
                      : () => _send(chat, _textController.text),
                  icon: const Icon(Icons.send_rounded),
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
