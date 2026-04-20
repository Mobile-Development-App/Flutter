import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/constants/openai_config.dart';

/// Sugerencias de reabastecimiento vía **OpenAI** (ChatGPT), solo cliente.
class OpenAiRestockSuggestionsService {
  OpenAiRestockSuggestionsService._();
  static final OpenAiRestockSuggestionsService instance =
      OpenAiRestockSuggestionsService._();

  static const _url = 'https://api.openai.com/v1/chat/completions';

  /// Devuelve lista de mapas `{title, body, isCritical?}` o vacío si no hay clave / error.
  Future<List<Map<String, dynamic>>> fetchInsightCards({
    required Map<String, dynamic> inventoryContext,
  }) async {
    final key = kOpenAiApiKey.trim();
    if (key.isEmpty) return const [];

    const system = '''
Eres un asistente de inventario para PYMEs en español (Latinoamérica).
Recibes un JSON con productos a reabastecer y ventas por id en una ventana de días.
Responde SOLO un JSON válido con esta forma exacta:
{"cards":[{"title":"string corto","body":"string útil max 400 caracteres","isCritical":false}]}
entre 3 y 6 tarjetas. title y body en español. isCritical true si hay riesgo de quiebre o capital inmovilizado.
Sin markdown, sin texto fuera del JSON.
''';

    final user = jsonEncode(inventoryContext);

    try {
      final res = await http
          .post(
            Uri.parse(_url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $key',
            },
            body: jsonEncode({
              'model': kOpenAiModel,
              'temperature': 0.35,
              'response_format': {'type': 'json_object'},
              'messages': [
                {'role': 'system', 'content': system},
                {'role': 'user', 'content': user},
              ],
            }),
          )
          .timeout(const Duration(seconds: 55));

      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint('[OpenAI] HTTP ${res.statusCode} ${res.body.length > 200 ? res.body.substring(0, 200) : res.body}');
        return const [];
      }

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final choices = decoded['choices'] as List?;
      if (choices == null || choices.isEmpty) return const [];
      final msg = choices.first as Map<String, dynamic>;
      final content = (msg['message'] as Map<String, dynamic>?)?['content'] as String?;
      if (content == null || content.isEmpty) return const [];

      final parsed = jsonDecode(content) as Map<String, dynamic>;
      final cards = parsed['cards'];
      if (cards is! List) return const [];

      final out = <Map<String, dynamic>>[];
      for (final item in cards) {
        if (item is Map<String, dynamic>) {
          out.add(item);
        } else if (item is Map) {
          out.add(Map<String, dynamic>.from(item));
        }
      }
      return out;
    } catch (e, st) {
      debugPrint('[OpenAI] $e\n$st');
      return const [];
    }
  }
}
