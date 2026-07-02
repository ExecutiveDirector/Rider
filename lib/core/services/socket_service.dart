// lib/core/services/socket_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../constants/api_constants.dart';
import '../constants/socket_constants.dart';

enum SocketStatus { disconnected, connecting, connected, reconnecting, reconnected, error }

class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  IO.Socket? _socket;
  String? _authToken;
  int? _driverId;

  SocketStatus _status = SocketStatus.disconnected;
  SocketStatus get status => _status;
  bool get isConnected => _status == SocketStatus.connected;

  // Stream controllers for events
  final _statusController = StreamController<SocketStatus>.broadcast();
  final _newOrderController = StreamController<Map<String, dynamic>>.broadcast();
  final _orderCancelledController = StreamController<String>.broadcast();
  final _orderUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _paymentReceivedController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<SocketStatus> get onStatusChange => _statusController.stream;
  Stream<Map<String, dynamic>> get onNewOrder => _newOrderController.stream;
  Stream<String> get onOrderCancelled => _orderCancelledController.stream;
  Stream<Map<String, dynamic>> get onOrderUpdated => _orderUpdatedController.stream;
  Stream<Map<String, dynamic>> get onPaymentReceived => _paymentReceivedController.stream;

  void init({required String token, required int driverId}) {
    _authToken = token;
    _driverId = driverId;
  }

  void connect() {
    if (_authToken == null) {
      debugPrint('[Socket] Cannot connect — no auth token');
      return;
    }
    if (_status == SocketStatus.connected || _status == SocketStatus.connecting) {
      return;
    }

    _setStatus(SocketStatus.connecting);

    _socket = IO.io(
      ApiConstants.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .setAuth({'token': _authToken})
          .setExtraHeaders({'Authorization': 'Bearer $_authToken'})
          .setReconnectionAttempts(5)
          .setReconnectionDelay(2000)
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('[Socket] Connected');
      _setStatus(SocketStatus.connected);
      if (_driverId != null) registerDriver(_driverId!);
    });

    _socket!.onDisconnect((_) {
      debugPrint('[Socket] Disconnected');
      _setStatus(SocketStatus.disconnected);
    });

    _socket!.onConnectError((err) {
      debugPrint('[Socket] Connection error: $err');
      _setStatus(SocketStatus.error);
    });

    _socket!.onReconnecting((_) {
      debugPrint('[Socket] Reconnecting…');
      _setStatus(SocketStatus.reconnecting);
    });
    _socket!.onReconnect((_) {
      debugPrint('[Socket] Reconnected');
      _setStatus(SocketStatus.reconnected);
      // Brief delay then normalize to connected so banners can distinguish
      Future.delayed(const Duration(seconds: 3), () {
        if (_status == SocketStatus.reconnected) {
          _setStatus(SocketStatus.connected);
        }
      });
      if (_driverId != null) registerDriver(_driverId!);
    });

    _registerListeners();
    _socket!.connect();
  }

  void disconnect() {
    _socket?.emit(SocketConstants.driverOffline, {'driverId': _driverId});
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _setStatus(SocketStatus.disconnected);
  }

  // --- Driver emits ---

  void registerDriver(int driverId) {
    _emit(SocketConstants.registerDriver, {'driverId': driverId});
    _emit(SocketConstants.driverOnline, {'driverId': driverId});
  }

  void sendLocation(double lat, double lng, {String? orderId}) {
    _emit(SocketConstants.locationUpdate, {
      'driverId': _driverId,
      'lat': lat,
      'lng': lng,
      'orderId': orderId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void acceptOrder(String orderId) {
    _emit(SocketConstants.acceptOrder, {
      'orderId': orderId,
      'driverId': _driverId,
    });
  }

  void rejectOrder(String orderId, {String? reason}) {
    _emit(SocketConstants.rejectOrder, {
      'orderId': orderId,
      'driverId': _driverId,
      'reason': reason ?? 'Rider unavailable',
    });
  }

  void completeOrder(String orderId) {
    _emit(SocketConstants.completeOrder, {
      'orderId': orderId,
      'driverId': _driverId,
      'completedAt': DateTime.now().toIso8601String(),
    });
  }

  // --- Private helpers ---

  void _registerListeners() {
    _socket!.on(SocketConstants.newOrder, (data) {
      debugPrint('[Socket] New order: $data');
      _newOrderController.add(_toMap(data));
    });

    _socket!.on(SocketConstants.orderCancelled, (data) {
      debugPrint('[Socket] Order cancelled: $data');
      final map = _toMap(data);
      _orderCancelledController.add(map['orderId']?.toString() ?? '');
    });

    _socket!.on(SocketConstants.orderUpdated, (data) {
      debugPrint('[Socket] Order updated: $data');
      _orderUpdatedController.add(_toMap(data));
    });

    _socket!.on(SocketConstants.paymentReceived, (data) {
      debugPrint('[Socket] Payment received: $data');
      _paymentReceivedController.add(_toMap(data));
    });
  }

  void _emit(String event, dynamic data) {
    if (isConnected) {
      _socket!.emit(event, data);
    } else {
      debugPrint('[Socket] Cannot emit $event — not connected');
    }
  }

  void _setStatus(SocketStatus status) {
    _status = status;
    _statusController.add(status);
  }

  Map<String, dynamic> _toMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  void dispose() {
    disconnect();
    _statusController.close();
    _newOrderController.close();
    _orderCancelledController.close();
    _orderUpdatedController.close();
    _paymentReceivedController.close();
  }
}
