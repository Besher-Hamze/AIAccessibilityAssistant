import 'dart:typed_data';

import 'package:ai_accessibility_assistant/voice/wav_trim.dart';
import 'package:flutter_test/flutter_test.dart';

/// 16 kHz mono 16-bit WAV whose samples are 0, 1, 2, ... with an optional
/// LIST chunk before `data` (as some recorders write).
Uint8List wav(int samples, {bool withList = false}) {
  final b = BytesBuilder();
  final d = ByteData(4);
  void u32(int v) {
    d.setUint32(0, v, Endian.little);
    b.add(d.buffer.asUint8List(0, 4));
  }

  void u16(int v) {
    d.setUint16(0, v, Endian.little);
    b.add(d.buffer.asUint8List(0, 2));
  }

  final list = withList ? [...'LIST'.codeUnits, 4, 0, 0, 0, ...'INFO'.codeUnits] : <int>[];
  b.add('RIFF'.codeUnits);
  u32(4 + 24 + list.length + 8 + samples * 2);
  b.add('WAVE'.codeUnits);
  b.add('fmt '.codeUnits);
  u32(16);
  u16(1); // PCM
  u16(1); // mono
  u32(16000);
  u32(32000);
  u16(2); // block align
  u16(16);
  b.add(list);
  b.add('data'.codeUnits);
  u32(samples * 2);
  for (var i = 0; i < samples; i++) {
    u16(i);
  }
  return b.toBytes();
}

int firstSample(Uint8List bytes) =>
    ByteData.sublistView(bytes).getUint16(44, Endian.little);

void main() {
  test('drops the requested milliseconds and rewrites a clean header', () {
    final out = trimWavBytes(wav(16000), 250)!; // 250ms = 4000 samples
    expect(String.fromCharCodes(out.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(out.sublist(36, 40)), 'data');
    expect(ByteData.sublistView(out).getUint32(40, Endian.little), (16000 - 4000) * 2);
    expect(firstSample(out), 4000);
    expect(out.length, 44 + (16000 - 4000) * 2);
  });

  test('skips extra chunks before data', () {
    final out = trimWavBytes(wav(16000, withList: true), 500)!;
    expect(firstSample(out), 8000);
  });

  test('returns null when trimming everything or for non-WAV data', () {
    expect(trimWavBytes(wav(1600), 200), isNull); // 100ms of audio
    expect(trimWavBytes(Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]), 10), isNull);
  });
}
