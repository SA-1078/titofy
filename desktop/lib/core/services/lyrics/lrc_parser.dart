import '../../models/lyric_line.dart';

/// Parser tolerante y completo para archivos y cadenas en formato LRC estándar
class LrcParser {
  /// Parsea una cadena de texto en formato LRC estándar
  static List<LyricLine> parse(String content) {
    final result = <LyricLine>[];
    final lines = content.split('\n');
    double offsetSeconds = 0;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Offset [offset:+/-NNN]
      final offsetMatch = RegExp(r'\[offset:([+-]?\d+)\]', caseSensitive: false).firstMatch(trimmed);
      if (offsetMatch != null) {
        offsetSeconds = (int.tryParse(offsetMatch.group(1)!) ?? 0) / 1000.0;
        continue;
      }

      // Metadata tags
      if (trimmed.startsWith('[ti:') || trimmed.startsWith('[ar:') || trimmed.startsWith('[al:') || trimmed.startsWith('[by:')) {
        continue;
      }

      // Timestamp matches
      final regExp = RegExp(r'\[(\d+):(\d+)(?:\.(\d+))?\]');
      final matches = regExp.allMatches(trimmed);
      if (matches.isEmpty) continue;

      // Extract text by removing all timestamps
      final text = trimmed.replaceAll(regExp, '').trim();
      if (text.isEmpty) continue;

      for (final match in matches) {
        final minutes = int.tryParse(match.group(1)!) ?? 0;
        final seconds = int.tryParse(match.group(2)!) ?? 0;
        final fracStr = match.group(3);
        final fraction = fracStr != null ? (double.tryParse('0.$fracStr') ?? 0.0) : 0.0;
        final totalSeconds = (minutes * 60 + seconds + fraction + offsetSeconds);
        final totalMs = (totalSeconds * 1000).round();

        result.add(LyricLine(
          time: Duration(milliseconds: totalMs < 0 ? 0 : totalMs),
          text: text,
        ));
      }
    }

    result.sort((a, b) => a.time.compareTo(b.time));

    // Des-colapsar marcas de tiempo idénticas para evitar saltos simultáneos
    if (result.length > 1) {
      int i = 0;
      while (i < result.length) {
        int j = i + 1;
        while (j < result.length && result[j].time == result[i].time) {
          j++;
        }
        final count = j - i;
        if (count > 1) {
          final commonTime = result[i].time;
          final prevTime = (i > 0) ? result[i - 1].time : Duration.zero;
          final availableBeforeMs = commonTime.inMilliseconds - prevTime.inMilliseconds;

          if (i > 0 && availableBeforeMs >= count * 1500) {
            final startMs = commonTime.inMilliseconds - (count - 1) * 2000;
            final actualStartMs = startMs < prevTime.inMilliseconds + 500
                ? prevTime.inMilliseconds + 500
                : startMs;
            final stepMs = ((commonTime.inMilliseconds - actualStartMs) / (count - 1)).round();
            for (int k = 0; k < count - 1; k++) {
              final newMs = actualStartMs + (k * stepMs);
              result[i + k] = LyricLine(time: Duration(milliseconds: newMs), text: result[i + k].text);
            }
          } else {
            for (int k = 1; k < count; k++) {
              final newMs = commonTime.inMilliseconds + (k * 1500);
              result[i + k] = LyricLine(time: Duration(milliseconds: newMs), text: result[i + k].text);
            }
          }
        }
        i = j;
      }

      result.sort((a, b) => a.time.compareTo(b.time));
      for (int k = 1; k < result.length; k++) {
        if (result[k].time <= result[k - 1].time) {
          result[k] = LyricLine(
            time: result[k - 1].time + const Duration(milliseconds: 800),
            text: result[k].text,
          );
        }
      }
    }

    return result;
  }
}
