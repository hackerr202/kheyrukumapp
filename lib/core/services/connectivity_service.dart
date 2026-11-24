import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'supabase_service.dart';

/// Exception thrown cleanly before hitting network when an online-only
/// administrative, authentication, or financial approval action is attempted offline.
class OfflineActionException implements Exception {
  final String message;

  const OfflineActionException([
    this.message = 'Internet connection required for this action.',
  ]);

  @override
  String toString() => message;
}

/// Real-time network & server reachability monitor for Kheyrukum.
/// Combines OS interface state (`connectivity_plus`) with a lightweight
/// DNS + TLS socket reachability probe to detect captive portals / dead towers,
/// plus app resume re-checks and immediate failure reporting.
class ConnectivityService with WidgetsBindingObserver {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final ValueNotifier<bool> isOnlineNotifier = ValueNotifier<bool>(true);
  bool get isOnline => isOnlineNotifier.value;

  final StreamController<void> _reconnectedController =
      StreamController<void>.broadcast();
  Stream<void> get onReconnected => _reconnectedController.stream;

  bool _initialized = false;
  bool _checking = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _debouncedProbeTimer;

  /// Initialize connectivity listeners and perform an initial reachability check.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (e) {
      debugPrint('[ConnectivityService] Observer note: $e');
    }

    try {
      _connectivitySub =
          Connectivity().onConnectivityChanged.listen((results) {
        unawaited(_evaluateConnectivityResults(results));
      });
    } catch (e) {
      debugPrint('[ConnectivityService] Stream setup note: $e');
    }

    await checkNow();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(checkNow());
    }
  }

  /// Checks current network transport and real reachability to Supabase host.
  Future<bool> checkNow() async {
    if (_checking) return isOnline;
    _checking = true;
    try {
      final results = await Connectivity().checkConnectivity();
      return await _evaluateConnectivityResults(results);
    } catch (e) {
      debugPrint('[ConnectivityService] checkNow note: $e');
      return isOnline;
    } finally {
      _checking = false;
    }
  }

  Future<bool> _evaluateConnectivityResults(
    List<ConnectivityResult> results,
  ) async {
    final hasInterface =
        results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);
    if (!hasInterface) {
      _setOnlineState(false);
      return false;
    }

    if (kIsWeb) {
      _setOnlineState(true);
      return true;
    }

    final reachable = await _probeBackendReachability();
    _setOnlineState(reachable);
    return reachable;
  }

  Future<bool> _probeBackendReachability() async {
    final host = Uri.tryParse(SupabaseService.supabaseUrl)?.host ?? '';
    if (host.isEmpty) return false;

    Socket? socket;
    try {
      final addresses = await InternetAddress.lookup(host)
          .timeout(const Duration(seconds: 3));
      if (addresses.isEmpty) return false;

      socket = await Socket.connect(
        host,
        443,
        timeout: const Duration(seconds: 3),
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      try {
        socket?.destroy();
      } catch (_) {}
    }
  }

  void _setOnlineState(bool nextOnline) {
    final previous = isOnlineNotifier.value;
    if (previous != nextOnline) {
      isOnlineNotifier.value = nextOnline;
      debugPrint(
        '[ConnectivityService] Connectivity changed: ${nextOnline ? "ONLINE" : "OFFLINE"}',
      );
      if (!previous && nextOnline && !_reconnectedController.isClosed) {
        _reconnectedController.add(null);
      }
    }
  }

  /// Called by cloud services when a request fails with a transient transport error
  /// so offline mode engages immediately without waiting for OS radio events.
  void reportNetworkFailure() {
    _setOnlineState(false);
    _debouncedProbeTimer?.cancel();
    _debouncedProbeTimer = Timer(const Duration(seconds: 8), () {
      unawaited(checkNow());
    });
  }

  /// Identifies transient socket, timeout, DNS, and HTTP transport failures.
  static bool isNetworkError(Object error) {
    if (error is SocketException ||
        error is TimeoutException ||
        error is HandshakeException) {
      return true;
    }
    final msg = error.toString().toLowerCase();
    return msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('connection refused') ||
        msg.contains('connection reset') ||
        msg.contains('connection closed') ||
        msg.contains('network is unreachable') ||
        msg.contains('clientexception') ||
        msg.contains('timed out') ||
        msg.contains('timeoutexception') ||
        msg.contains('xmlhttprequest') ||
        msg.contains('software caused connection abort') ||
        msg.contains('broken pipe') ||
        msg.contains('handshakeexception');
  }

  Future<void> dispose() async {
    _debouncedProbeTimer?.cancel();
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    _initialized = false;
  }
}
