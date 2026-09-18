import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineRequest {
  const OfflineRequest({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
  });

  final String id;
  final String type;
  final Map<String, dynamic> payload;
  final int createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'payload': payload,
    'createdAt': createdAt,
  };

  factory OfflineRequest.fromJson(Map<String, dynamic> json) {
    return OfflineRequest(
      id: json['id'].toString(),
      type: json['type'].toString(),
      payload: Map<String, dynamic>.from(
        json['payload'] as Map? ?? const {},
      ),
      createdAt: int.tryParse(json['createdAt'].toString()) ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }
}

class OfflineRequestQueue {
  OfflineRequestQueue._();

  static const _queueKey = 'karigarkart_offline_request_queue';

  static final SharedPreferencesAsync _prefs = SharedPreferencesAsync();
  static final Connectivity _connectivity = Connectivity();

  static StreamSubscription<List<ConnectivityResult>>? _subscription;
  static Future<void> Function(OfflineRequest request)? _dispatcher;
  static bool _started = false;
  static bool _flushing = false;

  static Future<void> initialize() async {
    if (_started) return;
    _started = true;

    _subscription = _connectivity.onConnectivityChanged.listen((result) {
      if (_isOnline(result)) {
        flush();
      }
    });

    try {
      final result = await _connectivity.checkConnectivity();
      if (_isOnline(result)) {
        await flush();
      }
    } catch (_) {}
  }

  static void registerDispatcher(
      Future<void> Function(OfflineRequest request) dispatcher,
      ) {
    _dispatcher = dispatcher;
  }

  static Future<bool> isOnline() async {
    try {
      return _isOnline(await _connectivity.checkConnectivity());
    } catch (_) {
      return false;
    }
  }

  static bool _isOnline(List<ConnectivityResult> result) {
    return result.any((item) => item != ConnectivityResult.none);
  }

  static Future<void> enqueue({
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    final current = await _read();
    final request = OfflineRequest(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      type: type,
      payload: payload,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    current.add(request);
    await _write(current);

    if (await isOnline()) {
      await flush();
    }
  }

  static Future<int> pendingCount() async {
    return (await _read()).length;
  }

  static Future<void> flush() async {
    if (_flushing || _dispatcher == null) return;

    _flushing = true;
    try {
      final requests = await _read();
      if (requests.isEmpty) return;

      final remaining = <OfflineRequest>[];

      for (final request in requests) {
        try {
          await _dispatcher!(request);
        } catch (_) {
          remaining.add(request);
        }
      }

      await _write(remaining);
    } finally {
      _flushing = false;
    }
  }

  static Future<List<OfflineRequest>> _read() async {
    final raw = await _prefs.getString(_queueKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      return decoded
          .whereType<Map>()
          .map(
            (item) => OfflineRequest.fromJson(
          Map<String, dynamic>.from(item),
        ),
      )
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _write(List<OfflineRequest> requests) async {
    await _prefs.setString(
      _queueKey,
      jsonEncode(
        requests.map((request) => request.toJson()).toList(),
      ),
    );
  }

  static Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _started = false;
  }
}
