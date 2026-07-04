// lib/data/repositories/order_repository.dart
import '../../core/constants/api_constants.dart';
import '../../core/services/api_service.dart';
import '../models/order_model.dart';

class OrderRepository {
  final _api = ApiService.instance;

  // ── Queries ───────────────────────────────────────────────────────────────

  Future<List<OrderModel>> getActiveOrders() async {
    final res = await _api.get(ApiConstants.activeOrders);
    final List data = res.data['orders'] ?? res.data ?? [];
    return data.map((e) => OrderModel.fromJson(e)).toList();
  }

  Future<List<OrderModel>> getCompletedOrders({int page = 1}) async {
    final res = await _api.get(
      ApiConstants.completedOrders,
      params: {'page': page, 'limit': 20},
    );
    final List data = res.data['orders'] ?? res.data ?? [];
    return data.map((e) => OrderModel.fromJson(e)).toList();
  }

  Future<OrderModel> getOrderById(String orderId) async {
    final res = await _api.get('${ApiConstants.ordersBase}/$orderId');
    return OrderModel.fromJson(res.data['order'] ?? res.data);
  }

  // ── Mutations ──────────────────────────────────────────────────────────────
  // FIX: acceptOrder/rejectOrder were calling PATCH .../accept and
  // PATCH .../reject — but routes/riders.js only registers
  // POST /riders/orders/:orderId/accept and POST .../decline (not "reject").
  // Every accept/decline tap was silently 404ing: the incoming-order sheet
  // still closed locally (see IncomingOrderSheet._accept, which pops the
  // sheet unconditionally) so it LOOKED like something happened, but the
  // backend never moved order_status off 'pending' and never cleared
  // rider_id. The rider then had no way to actually accept or decline —
  // the order was assigned (rider_id set by sp_auto_assign_rider) but
  // invisible in Active Orders (getRiderActiveOrders only returns
  // confirmed/preparing/ready/dispatched, not pending) and the accept
  // button never worked. This is almost certainly the "order comes in
  // already accepted with no notification" symptom — the tap silently
  // failed and there was nothing left on-screen to retry with.

  /// Incoming order sheet: accept a dispatched order assignment.
  /// Matches POST /riders/orders/:orderId/accept (riderController.acceptOrder).
  Future<OrderModel> acceptOrder(String orderId) async {
    final res = await _api.post('${ApiConstants.ordersBase}/$orderId/accept');
    return OrderModel.fromJson(res.data['data'] ?? res.data['order'] ?? res.data);
  }

  /// Incoming order sheet: decline an order.
  /// Matches POST /riders/orders/:orderId/decline (riderController.declineOrder).
  Future<void> rejectOrder(String orderId, {String? reason}) async {
    await _api.post(
      '${ApiConstants.ordersBase}/$orderId/decline',
      data: {'reason': reason ?? 'Rider unavailable'},
    );
  }

  /// "Confirm Pickup" button — rider collected cylinder from vendor.
  /// Moves DB: dispatched → ready.
  Future<OrderModel> pickupOrder(String orderId) async {
    final res = await _api.post('${ApiConstants.ordersBase}/$orderId/pickup');
    return OrderModel.fromJson(res.data['order'] ?? res.data);
  }

  /// "Mark Delivered" button — rider dropped off at customer.
  /// Moves DB: ready → delivered.
  Future<OrderModel> deliverOrder(String orderId) async {
    final res = await _api.patch('${ApiConstants.ordersBase}/$orderId/deliver');
    return OrderModel.fromJson(res.data['order'] ?? res.data);
  }
}
