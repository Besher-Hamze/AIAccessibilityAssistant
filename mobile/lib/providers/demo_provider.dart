import 'package:flutter/foundation.dart';
import '../constants/voice_commands.dart';
import 'chat_provider.dart';
import 'data_provider.dart';

class DemoProvider extends ChangeNotifier {
  bool running = false;
  int currentStep = 0;
  String? status;

  Future<void> runDemo(ChatProvider chat, DataProvider data) async {
    if (running) return;
    running = true;
    currentStep = 0;
    status = 'بدء العرض التجريبي...';
    notifyListeners();

    try {
      for (var i = 0; i < VoiceCommands.demoSteps.length; i++) {
        currentStep = i + 1;
        final cmd = VoiceCommands.demoSteps[i];
        status = 'الخطوة $currentStep/${VoiceCommands.demoSteps.length}: $cmd';
        notifyListeners();

        final mutated = await chat.sendTextMessage(cmd);
        if (mutated) await data.loadAll();
        await Future.delayed(const Duration(milliseconds: 900));
      }
      status = 'اكتمل العرض التجريبي بنجاح';
    } catch (e) {
      status = 'توقف العرض: ${e.toString().replaceAll('Exception: ', '')}';
    }

    running = false;
    notifyListeners();
  }
}
