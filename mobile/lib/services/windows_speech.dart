import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Plays server-generated speech (Edge neural voice MP3) on Windows.
///
/// flutter_tts is not used on Windows: its plugin crashes the app
/// (null result in stop()), and Windows usually has no Arabic voice anyway.
/// Playback runs in a PowerShell process using the WPF MediaPlayer, so
/// stopping is just killing that process.
class WindowsSpeech {
  static const _script = r'''
param([string]$Path, [double]$Speed = 1.0)
Add-Type -AssemblyName PresentationCore
$p = New-Object System.Windows.Media.MediaPlayer
$p.Open([Uri]$Path)
$p.SpeedRatio = $Speed
$p.Play()
$t = 0
while (-not $p.NaturalDuration.HasTimeSpan -and $t -lt 100) { Start-Sleep -Milliseconds 50; $t++ }
if ($p.NaturalDuration.HasTimeSpan) {
  Start-Sleep -Milliseconds ([int]($p.NaturalDuration.TimeSpan.TotalMilliseconds / $Speed) + 150)
}
$p.Close()
''';

  Process? _process;
  String? _scriptPath;

  Future<String> _ensureScript(Directory dir) async {
    final existing = _scriptPath;
    if (existing != null) return existing;
    final file = File('${dir.path}/speak_mp3.ps1');
    await file.writeAsString(_script, flush: true);
    return _scriptPath = file.path;
  }

  /// Plays [mp3] and completes when playback ends or [stop] is called.
  Future<void> play(List<int> mp3, {double speed = 1.0}) async {
    await stop();
    final dir = await getTemporaryDirectory();
    final script = await _ensureScript(dir);
    final audio = File('${dir.path}/speech_${DateTime.now().microsecondsSinceEpoch}.mp3');
    await audio.writeAsBytes(mp3, flush: true);
    try {
      final process = await Process.start('powershell', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        script,
        '-Path',
        audio.path,
        '-Speed',
        speed.toStringAsFixed(2),
      ]);
      _process = process;
      await process.exitCode;
      if (identical(_process, process)) _process = null;
    } finally {
      try {
        await audio.delete();
      } catch (_) {}
    }
  }

  Future<void> stop() async {
    final process = _process;
    _process = null;
    process?.kill();
  }
}
