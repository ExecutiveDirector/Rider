// lib/data/providers/order_provider.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/api_service.dart';
import '../../core/services/socket_service.dart';
import '../models/delivery_proof.dart';
import '../models/order_model.dart';
import '../repositories/order_repository.dart';

final orderRepositoryProvider = Provider((_) => OrderRepository());

class OrderState {
  final List<OrderModel> activeOrders;
  final List<OrderModel> completedOrders;

  /// The offer currently on screen in the accept/decline sheet.
  final OrderModel? incomingOrder;

  /// Offers that arrived while another offer was on screen. They are shown
  /// one after another instead of silently replacing (and losing) each other.
  final List<OrderModel> offerQueue;

  final bool isLoading;
  final String? error;

  const OrderState({
    this.activeOrders = const [],
    this.completedOrders = const [],
    this.incomingOrder,
    this.offerQueue = const [],
    this.isLoading = false,
    this.error,
  });

  OrderState copyWith({
    List<OrderModel>? activeOrders,
    List<OrderModel>? completedOrders,
    OrderModel? incomingOrder,
    bool clearIncoming = false,
    List<OrderModel>? offerQueue,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return OrderState(
      activeOrders: activeOrders ?? this.activeOrders,
      completedOrders: completedOrders ?? this.completedOrders,
      incomingOrder:
          clearIncoming ? null : (incomingOrder ?? this.incomingOrder),
      offerQueue: offerQueue ?? this.offerQueue,
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
      final raw = data['order'] is Map
          ? Map<String, dynamic>.from(data['order'] as Map)
          : data;
      _offer(OrderModel.fromJson(raw));
    });

    _cancelSub = SocketService.instance.onOrderCancelled.listen((orderId) {
      if (orderId.isEmpty) return;
      final wasShowing = state.incomingOrder?.id == orderId;
      state = state.copyWith(
        activeOrders: state.activeOrders.where((o) => o.id != orderId).toList(),
        offerQueue: state.offerQueue.where((o) => o.id != orderId).toList(),
        clearIncoming: wasShowing,
      );
      // The sheet listens for incomingOrder going null and closes itself.
      if (wasShowing) _advanceQueueSoon();
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

  // ── Offers ────────────────────────────────────────────────────────────────

  /// Puts an offer on screen, or queues it behind the one already showing.
  void _offer(OrderModel offer) {
    if (offer.id.isEmpty) return;
    if (state.incomingOrder?.id == offer.id) return;
    if (state.offerQueue.any((o) => o.id == offer.id)) return;
    // Already accepted and in progress — nothing to offer.
    if (state.activeOrders
        .any((o) => o.id == offer.id && o.status != OrderStatus.pending)) {
      return;
    }

    if (state.incomingOrder == null) {
      state = state.copyWith(incomingOrder: offer);
    } else {
      state = state.copyWith(offerQueue: [...state.offerQueue, offer]);
    }
  }

  /// The offer for [orderId] has been answered (or lapsed). Clears it from
  /// the sheet and the queue — but only if it is the one actually showing, so
  /// answering a card on Home never tears down a different offer's sheet.
  void _resolveOffer(OrderState base, String orderId,
      {List<OrderModel>? activeOrders}) {
    final showing = base.incomingOrder?.id == orderId;
    state = base.copyWith(
      activeOrders: activeOrders,
      offerQueue: base.offerQueue.where((o) => o.id != orderId).toList(),
      clearIncoming: showing,
    );
    if (showing) _advanceQueueSoon();
  }

  /// Shows the next queued offer shortly after the previous sheet closed, so
  /// the two sheets don't fight over the same navigator frame.
  void _advanceQueueSoon() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (state.incomingOrder != null || state.offerQueue.isEmpty) return;
      final next = state.offerQueue.first;
      state = state.copyWith(
        incomingOrder: next,
        offerQueue: state.offerQueue.sublist(1),
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
      state = state.copyWith(isLoading: false, error: dioErrorMessage(e));
    }
  }

  Future<void> fetchCompletedOrders({int page = 1}) async {
    state = state.copyWith(isLoading: true);
    try {
      final orders = await _repo.getCompletedOrders(page: page);
      final merged = page == 1 ? orders : [...state.completedOrders, ...orders];
      state = state.copyWith(completedOrders: merged, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: dioErrorMessage(e));
    }
  }

  // ── Mutations ─────────────────────────────────────────────────────────────

  /// Accept an offer (bottom sheet or the card on Home). On failure the offer
  /// is dropped — it has almost certainly been taken or cancelled — and
  /// [OrderState.error] carries the reason for the caller to show.
  Future<bool> acceptOrder(String orderId) async {
    try {
      final order = await _repo.acceptOrder(orderId);
      SocketService.instance.acceptOrder(orderId);
      _resolveOffer(
        state,
        orderId,
        activeOrders: [
          order,
          ...state.activeOrders.where((o) => o.id != orderId)
        ],
      );
      return true;
    } catch (e) {
      _resolveOffer(
        state.copyWith(error: dioErrorMessage(e)),
        orderId,
        activeOrders:
            state.activeOrders.where((o) => o.id != orderId).toList(),
      );
      return false;
    }
  }

  /// Decline an offer.
  Future<void> rejectOrder(String orderId, {String? reason}) async {
    try {
      await _repo.rejectOrder(orderId, reason: reason);
      SocketService.instance.rejectOrder(orderId, reason: reason);
    } catch (_) {
      // swallow — local state still cleaned up below
    } finally {
      _resolveOffer(
        state,
        orderId,
        activeOrders:
            state.activeOrders.where((o) => o.id != orderId).toList(),
      );
    }
  }

  /// Hand an accepted order back (before pickup). Returns an error message or null.
  Future<String?> releaseOrder(String orderId, String reason) async {
    try {
      await _repo.releaseOrder(orderId, reason);
      state = state.copyWith(
          activeOrders: state.activeOrders.where((o) => o.id != orderId).toList());
      return null;
    } catch (e) {
      return dioErrorMessage(e);
    }
  }

  /// Report that a collected order couldn't be delivered. Returns an error message or null.
  Future<String?> failDelivery(String orderId,
      {required String reasonCode, String? note, double? lat, double? lng}) async {
    try {
      await _repo.failDelivery(orderId,
          reasonCode: reasonCode, note: note, lat: lat, lng: lng);
      state = state.copyWith(
          activeOrders: state.activeOrders.where((o) => o.id != orderId).toList());
      return null;
    } catch (e) {
      return dioErrorMessage(e);
    }
  }

  /// Reports a journey step (on my way / arrived) so admin and customer can follow along.
  Future<bool> sendProgress(String orderId, String step) async {
    try {
      final updated = await _repo.sendProgress(orderId, step);
      _replaceActive(updated);
      return true;
    } catch (e) {
      state = state.copyWith(error: dioErrorMessage(e));
      return false;
    }
  }

  /// "Confirm Pickup" — rider collected the cylinder, now en route.
  Future<bool> pickupOrder(String orderId) async {
    try {
      final updated = await _repo.pickupOrder(orderId);
      _replaceActive(updated);
      return true;
    } catch (e) {
      state = state.copyWith(error: dioErrorMessage(e));
      return false;
    }
  }

  /// Quick completion without proof. Kept for callers that predate the
  /// proof-of-delivery screen; the UI now routes through
  /// [deliverWithProof] instead.
  Future<bool> deliverOrder(String orderId) async {
    try {
      final order = await _repo.deliverOrder(orderId);
      _finishDelivery(orderId, order);
      return true;
    } catch (e) {
      state = state.copyWith(error: dioErrorMessage(e));
      return false;
    }
  }

  /// Completes a delivery with OTP / photo / cylinder / cash details.
  /// Returns null on success, or a message to show the rider.
  Future<String?> deliverWithProof(String orderId, DeliveryProof proof) async {
    try {
      final order = await _repo.deliverWithProof(orderId, proof);
      _finishDelivery(orderId, order);
      return null;
    } catch (e) {
      return dioErrorMessage(e);
    }
  }

  void _finishDelivery(String orderId, OrderModel order) {
    SocketService.instance.completeOrder(orderId);
    state = state.copyWith(
      activeOrders: state.activeOrders.where((o) => o.id != orderId).toList(),
      completedOrders: [order, ...state.completedOrders],
    );
  }

  /// Surfaces the accept/reject sheet from an FCM push (foreground data
  /// message, notification tap, or terminated-state open) — none of those
  /// paths go through the socket, so the offer needs to be raised here too.
  Future<void> showIncomingOrderById(String orderId) async {
    // Already showing or queued — avoid clobbering/duplicate fetch.
    if (state.incomingOrder?.id == orderId) return;
    if (state.offerQueue.any((o) => o.id == orderId)) return;
    try {
      final order = await _repo.getOrderById(orderId);
      _offer(order);
    } catch (_) {
      // Fallback: single-order fetch failed — refetch the active list and
      // pull it from there instead of leaving the rider with no prompt.
      await fetchActiveOrders();
      final match = state.activeOrders.where((o) => o.id == orderId);
      if (match.isNotEmpty) _offer(match.first);
    }
  }

  void dismissIncomingOrder() {
    state = state.copyWith(clearIncoming: true);
    _advanceQueueSoon();
  }

  /// Called on logout — without this, a rider's active/completed orders
  /// stayed in memory after logout (authProvider was the only state reset),
  /// so if another rider logged in on the same device, the previous
  /// rider's order details could still flash on screen until the next
  /// fetch completed.
  void reset() => state = const OrderState();

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
