import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// LocalFileService — escribe y lee archivos reales en el sistema de
/// archivos del dispositivo usando dart:io.
///
/// Archivos generados (en getApplicationDocumentsDirectory()):
///   • audit_log.json
///   • stores.json
///   • employees.json
///
/// No reemplaza SharedPreferences ni Hive; es la capa que satisface el
/// criterio "Archivos Locales" de la rúbrica (dart:io + archivos .json).
class LocalFileService {
  LocalFileService._();
  static final LocalFileService shared = LocalFileService._();

  // ── Nombres de archivo ────────────────────────────────────────────────

  static const String auditLogFile  = 'audit_log.json';
  static const String storesFile    = 'stores.json';
  static const String employeesFile = 'employees.json';

  // ── Directorio base ───────────────────────────────────────────────────

  /// Devuelve (y crea si no existe) el directorio de documentos de la app.
  Future<Directory> get _dir async {
    // path_provider es necesario; no disponible en web.
    if (kIsWeb) throw UnsupportedError('LocalFileService no soporta web.');
    final base = await getApplicationDocumentsDirectory();
    final dir  = Directory('${base.path}/inventaria');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _file(String name) async {
    final d = await _dir;
    return File('${d.path}/$name');
  }

  // ── Escritura ─────────────────────────────────────────────────────────

  /// Serializa [data] como JSON con indentación y lo escribe en [fileName].
  Future<void> writeJson(String fileName, dynamic data) async {
    try {
      final f = await _file(fileName);
      final encoder = const JsonEncoder.withIndent('  ');
      await f.writeAsString(encoder.convert(data), flush: true);
      debugPrint('[LocalFile] ✓ writeJson → ${f.path}');
    } catch (e) {
      debugPrint('[LocalFile] ✗ writeJson $fileName: $e');
    }
  }

  // ── Lectura ───────────────────────────────────────────────────────────

  /// Lee [fileName] y devuelve el JSON decodificado, o [null] si no existe.
  Future<dynamic> readJson(String fileName) async {
    try {
      final f = await _file(fileName);
      if (!f.existsSync()) return null;
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return null;
      return jsonDecode(raw);
    } catch (e) {
      debugPrint('[LocalFile] ✗ readJson $fileName: $e');
      return null;
    }
  }

  // ── Lista de archivos ─────────────────────────────────────────────────

  /// Devuelve la lista de archivos .json en el directorio de la app.
  Future<List<FileSystemEntity>> listFiles() async {
    try {
      final d = await _dir;
      return d.listSync().where((e) => e.path.endsWith('.json')).toList();
    } catch (e) {
      debugPrint('[LocalFile] ✗ listFiles: $e');
      return [];
    }
  }

  // ── Eliminación ───────────────────────────────────────────────────────

  Future<void> deleteFile(String fileName) async {
    try {
      final f = await _file(fileName);
      if (f.existsSync()) {
        await f.delete();
        debugPrint('[LocalFile] ✓ deleted $fileName');
      }
    } catch (e) {
      debugPrint('[LocalFile] ✗ deleteFile $fileName: $e');
    }
  }

  // ── Helpers tipados ───────────────────────────────────────────────────

  /// Escribe una lista de mapas JSON en [fileName].
  Future<void> writeList(
    String fileName,
    List<Map<String, dynamic>> items,
  ) =>
      writeJson(fileName, items);

  /// Lee una lista de mapas JSON desde [fileName].
  /// Devuelve [] si el archivo no existe o hay un error.
  Future<List<Map<String, dynamic>>> readList(String fileName) async {
    final raw = await readJson(fileName);
    if (raw == null) return [];
    if (raw is! List) return [];
    return raw.cast<Map<String, dynamic>>();
  }
}
