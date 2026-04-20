/// Clave de la API de OpenAI (ChatGPT). No la subas al repositorio.
///
/// Ejemplo:
/// `flutter run --dart-define=OPENAI_API_KEY=sk-...`
const String kOpenAiApiKey = String.fromEnvironment(
  'OPENAI_API_KEY',
  defaultValue: '',
);

/// Modelo de chat (por defecto un modelo rápido y económico).
const String kOpenAiModel = String.fromEnvironment(
  'OPENAI_MODEL',
  defaultValue: 'gpt-4o-mini',
);
