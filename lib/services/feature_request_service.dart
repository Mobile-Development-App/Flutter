import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:uuid/uuid.dart';

import '../core/constants/api_constants.dart';
import '../services/api_service.dart';
import '../storage/persistence/feature_request_local_store.dart';
import 'bq_cache_service.dart';

Future<List<Map<String, dynamic>>> _safeComputeRows(
    List<Map<String, dynamic>> rows) {
  if (kIsWeb) return Future.value(_aggregateRepeatedRequests(rows));
  return compute(_aggregateRepeatedRequests, rows);
}

List<Map<String, dynamic>> _aggregateRepeatedRequests(
    List<Map<String, dynamic>> rows) {
  final cutoff =
      DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch;
  final buckets = <String, Map<String, dynamic>>{};

  for (final row in rows) {
    final submittedAt = row['submittedAtMs'] as int? ?? 0;
    if (submittedAt < cutoff) continue;

    final key = row['normalizedTitle'] as String? ?? '';
    if (key.isEmpty) continue;

    buckets.putIfAbsent(
      key,
      () => {
        'normalizedTitle': key,
        'displayTitle': row['title'] as String? ?? key,
        'accounts': <String, String>{},
        'submissionCount': 0,
        'lastSubmittedAtMs': 0,
      },
    );

    final bucket = buckets[key]!;
    final accounts = bucket['accounts'] as Map<String, String>;
    final accountId = row['accountId'] as String? ?? '';
    final accountLabel = row['accountLabel'] as String? ?? accountId;
    if (accountId.isNotEmpty) {
      accounts[accountId] = accountLabel;
    }
    bucket['submissionCount'] = (bucket['submissionCount'] as int) + 1;
    if (submittedAt > (bucket['lastSubmittedAtMs'] as int)) {
      bucket['lastSubmittedAtMs'] = submittedAt;
      bucket['displayTitle'] = row['title'] as String? ?? key;
    }
  }

  final result = buckets.values.map((b) {
    final accounts = b['accounts'] as Map<String, String>;
    return {
      'normalizedTitle': b['normalizedTitle'],
      'displayTitle': b['displayTitle'],
      'accountCount': accounts.length,
      'submissionCount': b['submissionCount'],
      'accountLabels': accounts.values.toList(),
      'lastSubmittedAtMs': b['lastSubmittedAtMs'],
    };
  }).toList();

  result.sort((a, b) {
    final byAccounts =
        (b['accountCount'] as int).compareTo(a['accountCount'] as int);
    if (byAccounts != 0) return byAccounts;
    return (b['submissionCount'] as int)
        .compareTo(a['submissionCount'] as int);
  });

  return result;
}

class BQ10RepeatedRequest {
  final String normalizedTitle;
  final String displayTitle;
  final int accountCount;
  final int submissionCount;
  final List<String> accountLabels;
  final DateTime lastSubmittedAt;

  const BQ10RepeatedRequest({
    required this.normalizedTitle,
    required this.displayTitle,
    required this.accountCount,
    required this.submissionCount,
    required this.accountLabels,
    required this.lastSubmittedAt,
  });
}

class BQ10Dashboard {
  final int totalSubmissions;
  final int distinctAccounts;
  final int repeatedThemes;
  final List<BQ10RepeatedRequest> topRequests;

  const BQ10Dashboard({
    required this.totalSubmissions,
    required this.distinctAccounts,
    required this.repeatedThemes,
    required this.topRequests,
  });
}

class FeatureRequestService {
  FeatureRequestService._();
  static final FeatureRequestService shared = FeatureRequestService._();

  Future<void> init() async {
    await FeatureRequestLocalStore.shared.init();
  }

  Future<void> submit({
    required String title,
    required String accountId,
    required String accountLabel,
  }) async {
    await init();
    final trimmed = title.trim();
    if (trimmed.length < 4) {
      throw ArgumentError('La solicitud debe tener al menos 4 caracteres');
    }

    final record = FeatureRequestRecord(
      id: const Uuid().v4(),
      title: trimmed,
      normalizedTitle: FeatureRequestLocalStore.normalizeTitle(trimmed),
      accountId: accountId,
      accountLabel: accountLabel,
      submittedAtMs: DateTime.now().millisecondsSinceEpoch,
    );

    await FeatureRequestLocalStore.shared.insert(record);

    try {
      await ApiService.shared.post(kFeatureRequests, {
        'title': trimmed,
        'accountId': accountId,
        'accountLabel': accountLabel,
      });
    } catch (_) {}
  }

  Future<BQ10Dashboard> loadDashboard({bool preferRemote = true}) async {
    await init();
    final cache = BQCacheService.shared;
    const cacheKey = 'bq10_dashboard';

    if (!preferRemote || !ApiService.shared.isAuthenticated) {
      final cached = await cache.read(cacheKey);
      final parsed = _fromCache(cached);
      if (parsed != null) return parsed;
    }

    List<Map<String, dynamic>> rows = [];

    if (preferRemote && ApiService.shared.isAuthenticated) {
      try {
        final data = await ApiService.shared.get(kFeatureRequestsAggregate);
        rows = _extractRows(data);
      } catch (_) {}
    }

    if (rows.isEmpty) {
      rows = FeatureRequestLocalStore.shared
          .all()
          .map((r) => r.toJson())
          .toList();
    }

    final aggregated = await _safeComputeRows(rows);
    final dashboard = _buildDashboard(aggregated, rows);
    await cache.save(cacheKey, _toCache(dashboard));
    return dashboard;
  }

  List<Map<String, dynamic>> _extractRows(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      for (final key in ['requests', 'items', 'data', 'results']) {
        final val = map[key];
        if (val is List) {
          return val
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    }
    return [];
  }

  BQ10Dashboard _buildDashboard(
    List<Map<String, dynamic>> aggregated,
    List<Map<String, dynamic>> rawRows,
  ) {
    final cutoff =
        DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch;
    final recent = rawRows
        .where((r) => ((r['submittedAtMs'] as num?)?.toInt() ?? 0) >= cutoff);
    final accounts = <String>{};
    for (final r in recent) {
      final id = r['accountId'] as String? ?? '';
      if (id.isNotEmpty) accounts.add(id);
    }

    final top = aggregated
        .where((e) => (e['accountCount'] as int? ?? 0) >= 2)
        .map((e) => BQ10RepeatedRequest(
              normalizedTitle: e['normalizedTitle'] as String? ?? '',
              displayTitle: e['displayTitle'] as String? ?? '',
              accountCount: e['accountCount'] as int? ?? 0,
              submissionCount: e['submissionCount'] as int? ?? 0,
              accountLabels: (e['accountLabels'] as List<dynamic>?)
                      ?.map((x) => x.toString())
                      .toList() ??
                  const [],
              lastSubmittedAt: DateTime.fromMillisecondsSinceEpoch(
                e['lastSubmittedAtMs'] as int? ?? 0,
              ),
            ))
        .toList();

    return BQ10Dashboard(
      totalSubmissions: recent.length,
      distinctAccounts: accounts.length,
      repeatedThemes: top.length,
      topRequests: top,
    );
  }

  Map<String, dynamic> _toCache(BQ10Dashboard d) => {
        'totalSubmissions': d.totalSubmissions,
        'distinctAccounts': d.distinctAccounts,
        'repeatedThemes': d.repeatedThemes,
        'topRequests': d.topRequests
            .map((r) => {
                  'normalizedTitle': r.normalizedTitle,
                  'displayTitle': r.displayTitle,
                  'accountCount': r.accountCount,
                  'submissionCount': r.submissionCount,
                  'accountLabels': r.accountLabels,
                  'lastSubmittedAtMs': r.lastSubmittedAt.millisecondsSinceEpoch,
                })
            .toList(),
      };

  BQ10Dashboard? dashboardFromCache(Map<String, dynamic>? cached) =>
      _fromCache(cached);

  BQ10Dashboard? _fromCache(Map<String, dynamic>? cached) {
    if (cached == null) return null;
    final top = (cached['topRequests'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => BQ10RepeatedRequest(
              normalizedTitle: e['normalizedTitle'] as String? ?? '',
              displayTitle: e['displayTitle'] as String? ?? '',
              accountCount: e['accountCount'] as int? ?? 0,
              submissionCount: e['submissionCount'] as int? ?? 0,
              accountLabels: (e['accountLabels'] as List<dynamic>?)
                      ?.map((x) => x.toString())
                      .toList() ??
                  const [],
              lastSubmittedAt: DateTime.fromMillisecondsSinceEpoch(
                (e['lastSubmittedAtMs'] as num?)?.toInt() ?? 0,
              ),
            ))
        .toList();
    return BQ10Dashboard(
      totalSubmissions: cached['totalSubmissions'] as int? ?? 0,
      distinctAccounts: cached['distinctAccounts'] as int? ?? 0,
      repeatedThemes: cached['repeatedThemes'] as int? ?? 0,
      topRequests: top,
    );
  }
}
