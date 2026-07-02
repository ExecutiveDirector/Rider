// lib/data/providers/order_provider.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/socket_service.dart';
import '../models/order_model.dart';
import '../repositories/order_repository.dart';

final orderRepositoryProvider = Provider((_) => OrderRepository());

class OrderState {
  final List<OrderModel> activeOrders;
  final List<OrderModel> completedOrders;
  final OrderModel? incomingOrder;
  final bool isLoading;
  final String? error;

  const OrderState({
    this.activeOrders = const [],
    this.completedOrders = const [],
    this.incomingOrder,
    this.isLoading = false,
    this.error,
  });

  OrderState copyWith({
    List<OrderModel>? activeOrders,
    List<OrderModel>? completedOrders,
    OrderModel? incomingOrder,
    bool clearIncoming = false,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return OrderState(
      activeOrders: activeOrders ?? this.activeOrders,
      completedOrders: completedOrders ?? this.completedOrders,
      incomingOrder:
          clearIncoming ? null : (incomingOrder ?? this.incomingOrder),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class OrderNotifier extends StateNotifier<OrderState> {
  final OrderRepository _repo;
  StreamSubscription? _newOrderSub;
  StreamSubscription? _cancelSub;
  StreamSubscription? _updateSub;

  OrderNotifier(this._repo) : super(const OrderState()) {
    _listenToSocket();
  }

  void _listenToSocket() {
    _newOrderSub = SocketService.instance.onNewOrder.listen((data) {
      state = state.copyWith(incomingOrder: OrderModel.fromJson(data));
    });

    _cancelSub = SocketService.instance.onOrderCancelled.listen((orderId) {
      state = state.copyWith(
        activeOrders: state.activeOrders.where((o) => o.id != orderId).toList(),
      );
    });

    _updateSub = SocketService.instance.onOrderUpdated.listen((data) {
      final updated = OrderModel.fromJson(data);
      state = state.copyWith(
        activeOrders: state.activeOrders
            .map((o) => o.id == updated.id ? updated : o)
            .toList(),
      );
    });
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  Future<void> fetchActiveOrders() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final orders = await _repo.getActiveOrders();
      state = state.copyWith(activeOrders: orders, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchCompletedOrders({int page = 1}) async {
    state = state.copyWith(isLoading: true);
    try {
      final orders = await _repo.getCompletedOrders(page: page);
      final merged = page == 1 ? orders : [...state.completedOrders, ...orders];
      state = state.copyWith(completedOrders: merged, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ── Mutations ─────────────────────────────────────────────────────────────

  /// Accept incoming order (from the bottom sheet).
  Future<bool> acceptOrder(String orderId) async {
    try {
      final order = await _repo.acceptOrder(orderId);
      SocketService.instance.acceptOrder(orderId);
      state = state.copyWith(
        activeOrders: [
          order,
          ...state.activeOrders.where((o) => o.id != orderId)
        ],
        clearIncoming: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Decline incoming order (from the bottom sheet).
  Future<void> rejectOrder(String orderId, {String? reason}) async {
    try {
      await _repo.rejectOrder(orderId, reason: reason);
      SocketService.instance.rejectOrder(orderId, reason: reason);
    } catch (_) {
      // swallow — local state still cleaned up below
    } finally {
      state = state.copyWith(
        activeOrders: state.activeOrders.where((o) => o.id != orderId).toList(),
        clearIncoming: true,
      );
    }
  }

  /// "Picked Up" button — rider collected the cylinder, now en route.
  /// Moves DB: confirmed/preparing/ready → dispatched.
  Future<bool> pickupOrder(String orderId) async {
    try {
      final updated = await _repo.pickupOrder(orderId);
      _replaceActive(updated);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// "Mark Delivered" button — rider dropped off the order.
  /// Moves DB: dispatched → delivered.
  Future<bool> deliverOrder(String orderId) async {
    try {
      final order = await _repo.deliverOrder(orderId);
      SocketService.instance.completeOrder(orderId);
      state = state.copyWith(
        activeOrders: state.activeOrders.where((o) => o.id != orderId).toList(),
        completedOrders: [order, ...state.completedOrders],
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Surfaces the accept/reject sheet from an FCM push (foreground data
  /// message, notification tap, or terminated-state open) — none of those
  /// paths go through the socket, so `incomingOrder` needs to be set here
  /// too, not just from `onNewOrder`.
  Future<void> showIncomingOrderById(String orderId) async {
    // Already showing (or already handled) — avoid clobbering/duplicate fetch.
    if (state.incomingOrder?.id == orderId) return;
    try {
      final order = await _repo.getOrderById(orderId);
      state = state.copyWith(incomingOrder: order);
    } catch (_) {
      // Fallback: single-order fetch failed — refetch the active list and
      // pull it from there instead of leaving the rider with no prompt.
      await fetchActiveOrders();
      final match = state.activeOrders.where((o) => o.id == orderId);
      if (match.isNotEmpty) {
        state = state.copyWith(incomingOrder: match.first);
      }
    }
  }

  void dismissIncomingOrder() => state = state.copyWith(clearIncoming: true);

  void _replaceActive(OrderModel updated) {
    state = state.copyWith(
      activeOrders: state.activeOrders
          .map((o) => o.id == updated.id ? updated : o)
          .toList(),
    );
  }

  @override
  void dispose() {
    _newOrderSub?.cancel();
    _cancelSub?.cancel();
    _updateSub?.cancel();
    super.dispose();
  }
}

final orderProvider = StateNotifierProvider<OrderNotifier, OrderState>(
  (ref) => OrderNotifier(ref.read(orderRepositoryProvider)),
);
