import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../theme/app_theme.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onSpeak;
  final bool isSpeaking;

  const MessageBubble({
    super.key,
    required this.message,
    this.onSpeak,
    this.isSpeaking = false,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isUser
                    ? const LinearGradient(colors: [AppColors.deepTeal, AppColors.teal])
                    : null,
                color: isUser ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 4 : 18),
                  bottomRight: Radius.circular(isUser ? 18 : 4),
                ),
                border: isUser
                    ? null
                    : Border.all(color: AppColors.deepTeal.withValues(alpha: 0.08)),
              ),
              child: message.isLoading
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isUser ? Colors.white : AppColors.teal,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          message.content,
                          style: TextStyle(color: isUser ? Colors.white : AppColors.ink),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          message.content,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.45,
                            color: isUser ? Colors.white : AppColors.ink,
                          ),
                        ),
                        if (isUser && message.speakerGenderAr != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'صوت ${message.speakerGenderAr}${message.confidence != null ? ' · ثقة ${(message.confidence! * 100).round()}٪' : ''}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                        if (!isUser && message.toolLabel != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            message.toolLabel!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.teal.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
            if (!isUser && !message.isLoading)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(message.createdAt),
                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                  if (onSpeak != null)
                    IconButton(
                      tooltip: isSpeaking ? 'إيقاف القراءة' : 'قراءة الرسالة',
                      visualDensity: VisualDensity.compact,
                      onPressed: onSpeak,
                      icon: Icon(
                        isSpeaking
                            ? Icons.stop_circle_rounded
                            : Icons.volume_up_rounded,
                        size: 20,
                        color: isSpeaking ? AppColors.danger : AppColors.teal,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
