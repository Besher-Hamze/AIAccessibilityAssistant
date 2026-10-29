import 'dart:io';
import 'dart:typed_data';

/// Removes the first [ms] milliseconds of PCM audio from a WAV file.
///
/// Used after a barge-in: the recording started while the assistant was
/// still talking, and that part must not reach Whisper. Handles extra RIFF
/// chunks (some recorders write LIST/fact chunks before `data`).
Future<void> trimWavStart(String path, int ms) async {
  if (ms <= 0) return;
  final file = File(path);
  final trimmed = trimWavBytes(await file.readAsBytes(), ms);
  if (trimmed != null) await file.writeAsBytes(trimmed, flush: true);
}

/// Pure version of [trimWavStart]; returns null if the data is not a PCM WAV
/// or there is nothing left after trimming.
Uint8List? trimWavBytes(Uint8List bytes, int ms) {
  if (bytes.length < 12 ||
      String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF' ||
      String.fromCharCodes(bytes.sublist(8, 12)) != 'WAVE') {
    return null;
  }
  final view = ByteData.sublistView(bytes);
  Uint8List? fmt;
  var sampleRate = 16000;
  var blockAlign = 2;
  int? dataStart;
  int? dataLength;

  var pos = 12;
  while (pos + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes.sublist(pos, pos + 4));
    var size = view.getUint32(pos + 4, Endian.little);
    final body = pos + 8;
    if (id == 'fmt ') {
      fmt = bytes.sublist(body, body + size);
      sampleRate = view.getUint32(body + 4, Endian.little);
      blockAlign = view.getUint16(body + 12, Endian.little);
    } else if (id == 'data') {
      // Streaming writers may leave the size unset; use the rest of the file.
      if (size == 0 || body + size > bytes.length) size = bytes.length - body;
      dataStart = body;
      dataLength = size;
      break;
    }
    pos = body + size + (size & 1);
  }
  if (fmt == null || dataStart == null || dataLength == null || blockAlign == 0) {
    return null;
  }

  final skip = (ms * sampleRate ~/ 1000) * blockAlign;
  if (skip >= dataLength) return null;
  final pcm = bytes.sublist(dataStart + skip, dataStart + dataLength);

  final out = BytesBuilder();
  final header = ByteData(4);
  void u32(int v) {
    header.setUint32(0, v, Endian.little);
    out.add(header.buffer.asUint8List());
  }

  out.add('RIFF'.codeUnits);
  u32(4 + 8 + fmt.length + 8 + pcm.length);
  out.add('WAVE'.codeUnits);
  out.add('fmt '.codeUnits);
  u32(fmt.length);
  out.add(fmt);
  out.add('data'.codeUnits);
  u32(pcm.length);
  out.add(pcm);
  return out.toBytes();
}
