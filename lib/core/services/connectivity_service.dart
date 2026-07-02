// lib/core/services/connectivity_service.dart
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final _connectivity = Connectivity();

  /// connectivity_plus 6.x reports a List<ConnectivityResult> because a
  /// device can have wifi + mobile simultaneously — we only care whether
  /// *any* usable interface is up.
  Stream<bool> get onStatusChange =>
      _connectivity.onConnectivityChanged.map(_hasConnection);

  Future<bool> checkNow() async {
    final results = await _connectivity.checkConnectivity();
    return _hasConnection(results);
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }
}
