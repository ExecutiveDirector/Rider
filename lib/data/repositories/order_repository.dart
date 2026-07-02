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

  // ── Mutations — all PATCH /riders/orders/:id/<verb> ───────────────────────

  /// Incoming order sheet: accept a dispatched order assignment.
  Future<OrderModel> acceptOrder(String orderId) async {
    final res = await _api.patch('${ApiConstants.ordersBase}/$orderId/accept');
    return OrderModel.fromJson(res.data['order'] ?? res.data);
  }

  /// Incoming order sheet: decline an order.
  Future<void> rejectOrder(String orderId, {String? reason}) async {
    await _api.patch(
      '${ApiConstants.ordersBase}/$orderId/reject',
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
