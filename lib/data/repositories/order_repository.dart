// lib/data/repositories/order_repository.dart
import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/api_service.dart';
import '../models/delivery_proof.dart';
import '../models/mpesa_request.dart';
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

  /// Accepted but can't make it (before pickup): POST .../release.
  Future<void> releaseOrder(String orderId, String reason) async {
    await _api.post('${ApiConstants.ordersBase}/$orderId/release',
        data: {'reason': reason});
  }

  /// Collected but couldn't hand over: POST .../fail-delivery.
  Future<void> failDelivery(String orderId,
      {required String reasonCode,
      String? note,
      double? lat,
      double? lng}) async {
    await _api.post('${ApiConstants.ordersBase}/$orderId/fail-delivery', data: {
      'reason_code': reasonCode,
      if (note != null && note.isNotEmpty) 'note': note,
      if (lat != null) 'latitude': lat,
      if (lng != null) 'longitude': lng,
    });
  }

  /// Journey step: en_route_pickup | arrived_pickup | en_route_delivery | arrived_customer.
  Future<OrderModel> sendProgress(String orderId, String step) async {
    final res = await _api.post('${ApiConstants.ordersBase}/$orderId/progress', data: {'step': step});
    return OrderModel.fromJson(res.data['order'] ?? res.data);
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

  /// Completes the delivery with proof. Sent as multipart when a photo is
  /// attached, plain JSON otherwise (so a route without an upload middleware
  /// still receives the fields).
  Future<OrderModel> deliverWithProof(
      String orderId, DeliveryProof proof) async {
    final path = '${ApiConstants.ordersBase}/$orderId/deliver';
    final fields = proof.toFields();

    dynamic body = fields;
    if (proof.hasPhoto) {
      body = FormData.fromMap({
        ...fields,
        'proof_photo': await MultipartFile.fromFile(
          proof.photoPath!,
          filename: 'delivery_proof_$orderId.jpg',
        ),
      });
    }

    final res = await _api.patch(path, data: body);
    final data = res.data;
    if (data is Map) {
      final order = data['order'] ?? data['data'] ?? data;
      return OrderModel.fromJson(Map<String, dynamic>.from(order as Map));
    }
    throw StateError('Unexpected response from the delivery endpoint');
  }

  // ── Cashless (M-Pesa) completion of cash-on-delivery orders ───────────────

  static MpesaRequestState _mpesaFrom(dynamic data) {
    if (data is Map && data['mpesa'] is Map) {
      return MpesaRequestState.fromJson(
          Map<String, dynamic>.from(data['mpesa'] as Map));
    }
    return MpesaRequestState.none;
  }

  /// Asks the customer to pay the cash amount by M-Pesa (STK push sent by the
  /// server). [phone] is only set when the customer authorises another number.
  Future<MpesaRequestState> requestMpesa(String orderId, {String? phone}) async {
    final res = await _api.post(
      '${ApiConstants.ordersBase}/$orderId/mpesa/request',
      data: {if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim()},
    );
    return _mpesaFrom(res.data);
  }

  /// Current state of the request; the rider polls this while waiting.
  Future<MpesaRequestState> mpesaStatus(String orderId) async {
    final res = await _api.get('${ApiConstants.ordersBase}/$orderId/mpesa/status');
    return _mpesaFrom(res.data);
  }
}
