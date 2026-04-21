import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Optional ChatGPT suggestions for restock.
///
/// Pass the key at **build time** only (do not commit real keys):
/// `flutter run --dart-define=OPENAI_API_KEY=sk-...`
/// Optional: `--dart-define=OPENAI_MODEL=gpt-4o-mini`
///
/// Note: shipping API keys inside a client app is inherently exposed; for
/// production, proxy OpenAI through your backend.
class OpenAiRestockService {
  OpenAiRestockService._();

  static const _apiKey =
      String.fromEnvironment('OPENAI_API_KEY', defaultValue: '');
  static const _model =
      String.fromEnvironment('OPENAI_MODEL', defaultValue: 'gpt-4o-mini');

  static bool get isConfigured => _apiKey.isNotEmpty;

  /// Returns raw card maps (`title`, `body`, `isCritical`) or null on failure.
  static Future<List<Map<String, dynamic>>?> fetchSuggestionMaps({
    required Map<String, dynamic> contextPayload,
  }) async {
    if (!isConfigured) return null;
    try {
      final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
      final body = <String, dynamic>{
        'model': _model,
        'temperature': 0.35,
        'response_format': const {'type': 'json_object'},
        'messages': [
          {
            'role': 'system',
            'content': '''
Eres un asistente de inventario para comercios minoristas. Devuelve SOLO JSON válido con esta forma exacta:
{"cards":[{"title":"string corto","body":"string, 1 a 4 oraciones en español","isCritical":false}]}
Entre 1 y 4 tarjetas. Sé concreto y accionable. Si faltan datos, recomendaciones conservadoras.''',
          },
          {
            'role': 'user',
            'content': jsonEncode(contextPayload),
          },
        ],
      };

      final res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 25));

      if (res.statusCode != 200) {
        debugPrint('[OpenAI] HTTP ${res.statusCode}');
        return null;
      }

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final choices = decoded['choices'] as List<dynamic>?;
      final first = choices != null && choices.isNotEmpty
          ? choices.first as Map<String, dynamic>
          : null;
      final msg = first?['message'] as Map<String, dynamic>?;
      final content = msg?['content'] as String?;
      if (content == null || content.isEmpty) return null;

      final obj = jsonDecode(content) as Map<String, dynamic>;
      final cards = obj['cards'];
      if (cards is! List<dynamic>) return null;

      return cards
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e, st) {
      debugPrint('[OpenAI] restock suggestions error: $e\n$st');
      return null;
    }
  }
}
