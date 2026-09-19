import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Adds a presentation-language instruction, without changing any tool schema,
/// database identifier, health evidence, request limit or provider settings.
List<Map<String, dynamic>> aiMessagesForLanguage(
    List<Map<String, dynamic>> messages, String? language) {
  if (language?.split(RegExp('[-_]')).first != 'ru') return messages;
  const instruction = '\n\nResponse language: Russian (ru). Write all '
      'user-facing prose, explanations, chart titles and labels, journal reply '
      'and note in natural, idiomatic Russian. Preserve the required output '
      'format. Do NOT translate JSON keys, tool/function names, SQL identifiers, '
      'canonical journal tag vocabulary, enum values, technical identifiers, '
      'proper names or quoted user data. Never alter numbers or invent data. '
      'If the user explicitly requests another language, follow that request.';
  final out = [for (final m in messages) Map<String, dynamic>.from(m)];
  final system = out.indexWhere((m) => m['role'] == 'system');
  if (system >= 0 && out[system]['content'] is String) {
    out[system]['content'] = '${out[system]['content']}$instruction';
  } else {
    out.insert(0, {'role': 'system', 'content': instruction.trim()});
  }
  return out;
}

Future<String?> savedAiResponseLanguage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('locale_override') ??
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  } catch (_) {
    // A headless test without Flutter/plugins retains the original prompt.
    return null;
  }
}
