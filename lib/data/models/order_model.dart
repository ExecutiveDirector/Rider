// lib/data/models/order_model.dart
import '../../core/utils/json_utils.dart';

enum OrderStatus {
  pending,
  accepted,
  inTransit,
  delivered,
  cancelled;

  // Maps every value the backend's orders table can emit.
  // DB column is order_status; the normalised 'status' field
  // from normalizeOrder() in orderController is also handled.
  static OrderStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'draft':
      case 'pending':
        return OrderStatus.pending;
      case 'confirmed':
      case 'preparing':
      case 'accepted':
        return OrderStatus.accepted;
      case 'dispatched': // assigned to rider, awaiting physical pickup from vendor
        return OrderStatus.accepted;
      case 'ready': // rider collected from vendor, en route to customer
      case 'in_transit':
      case 'intransit':
      case 'on_delivery':
        return OrderStatus.inTransit;
      case 'delivered':
        return OrderStatus.delivered;
      case 'canceled': // DB uses single-L
      case 'cancelled':
      case 'refunded':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }

  String get label {
    switch (this) {
      case pending:
        return 'Pending';
      case accepted:
        return 'Confirm Pickup';
      case inTransit:
        return 'En Route';
      case delivered:
        return 'Delivered';
      case cancelled:
        return 'Cancelled';
    }
  }
}

class OrderModel {
  final String id;
  final String orderNumber;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final double deliveryLat;
  final double deliveryLng;
  final String gasType; // first item's product_name
  final double quantity; // first item's quantity
  final double totalAmount;
  final OrderStatus status;
  final DateTime createdAt;
  final String? notes;
  final double? distanceKm;

  // ── Pickup (vendor outlet) ────────────────────────────────────────────────
  final String? vendorName;
  final String? pickupAddress;
  final double? pickupLat;
  final double? pickupLng;

  // ── Payment / earnings ────────────────────────────────────────────────────
  /// Lower-cased payment method as sent by the backend ('cod', 'mpesa', ...).
  final String paymentMethod;

  /// True when the customer pays the rider in cash at the door and the order
  /// has not already been paid online.
  final bool isCod;

  /// Cash the rider must collect. 0 when the order is prepaid.
  final double amountDue;

  /// What the rider earns for this job, when the backend sends it. Null means
  /// "unknown" — the UI must not present the order total as the rider's pay.
  final double? riderEarning;

  // ── Delivery proof ────────────────────────────────────────────────────────
  /// Backend generated a code for the customer that the rider must enter.
  final bool otpRequired;

  /// When the offer lapses server-side (dispatch offers only).
  final DateTime? offerExpiresAt;

  const OrderModel({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.deliveryLat,
    required this.deliveryLng,
    required this.gasType,
    required this.quantity,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    this.notes,
    this.distanceKm,
    this.vendorName,
    this.pickupAddress,
    this.pickupLat,
    this.pickupLng,
    this.paymentMethod = '',
    this.isCod = false,
    this.amountDue = 0,
    this.riderEarning,
    this.otpRequired = false,
    this.offerExpiresAt,
  });

  bool get hasDeliveryLocation => deliveryLat != 0 || deliveryLng != 0;

  bool get hasPickupLocation =>
      pickupLat != null &&
      pickupLng != null &&
      (pickupLat != 0 || pickupLng != 0);

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    // ID: backend returns order_id (bigint) or id (string)
    final id = (json['id'] ?? json['order_id'] ?? '').toString();

    final orderNumber = json['order_number']?.toString() ?? id;

    // Customer: flat fields from getRiderActiveOrders,
    // or nested customer object from getOrderById
    final customer = asMap(json['customer']);
    final customerName = customer?['full_name'] as String? ??
        json['customer_name'] as String? ??
        json['customerName'] as String? ??
        'Customer';
    final customerPhone = customer?['phone'] as String? ??
        json['customer_phone'] as String? ??
        json['customerPhone'] as String? ??
        json['delivery_contact'] as String? ??
        '';

    // Delivery
    final deliveryAddress = json['delivery_address'] as String? ??
        json['deliveryAddress'] as String? ??
        '';

    final deliveryLat =
        asDoubleOr(json['delivery_latitude'] ?? json['deliveryLat']);
    final deliveryLng =
        asDoubleOr(json['delivery_longitude'] ?? json['deliveryLng']);

    // Pickup: flat pickup_* fields, or a nested outlet / vendor object.
    final outlet = asMap(json['outlet']) ??
        asMap(json['vendor_outlet']) ??
        asMap(json['pickup']);
    final vendor = asMap(json['vendor']);
    final pickupLat = asDouble(json['pickup_latitude'] ??
        json['pickupLat'] ??
        outlet?['latitude'] ??
        outlet?['lat']);
    final pickupLng = asDouble(json['pickup_longitude'] ??
        json['pickupLng'] ??
        outlet?['longitude'] ??
        outlet?['lng']);
    final pickupAddress = (json['pickup_address'] ??
            json['pickupAddress'] ??
            outlet?['address'] ??
            outlet?['address_line'])
        ?.toString();
    final vendorName = (json['vendor_name'] ??
            json['vendorName'] ??
            json['outlet_name'] ??
            outlet?['name'] ??
            vendor?['business_name'] ??
            vendor?['name'])
        ?.toString();

    // Items: pull gas type + quantity from first order_item
    final rawItems =
        json['items'] as List? ?? json['order_items'] as List? ?? [];
    final firstItem = rawItems.isNotEmpty && rawItems.first is Map
        ? Map<String, dynamic>.from(rawItems.first as Map)
        : <String, dynamic>{};

    final gasType = firstItem['product_name'] as String? ??
        json['gasType'] as String? ??
        json['gas_type'] as String? ??
        'LPG Gas';

    final quantity =
        asDoubleOr(firstItem['quantity'] ?? json['quantity'], 1);

    // Totals: grand_total = total_amount + delivery_fee (computed server-side)
    final totalAmount = asDoubleOr(json['grand_total'] ??
        json['total_amount'] ??
        json['totalAmount']);

    // Payment
    final paymentMethod =
        (json['payment_method'] ?? json['paymentMethod'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
    final paymentStatus =
        (json['payment_status'] ?? json['paymentStatus'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
    final alreadyPaid = paymentStatus == 'paid' ||
        paymentStatus == 'completed' ||
        paymentStatus == 'success';
    final isCod = !alreadyPaid &&
        (paymentMethod == 'cod' ||
            paymentMethod == 'cash' ||
            paymentMethod == 'cash_on_delivery' ||
            paymentMethod == 'cash on delivery');
    final amountDue = asDouble(json['amount_due'] ?? json['cod_amount']) ??
        (isCod ? totalAmount : 0.0);

    // Status: backend sends order_status (raw DB) or status (normalised)
    final rawStatus = json['order_status'] as String? ??
        json['status'] as String? ??
        'pending';

    final createdAt = DateTime.tryParse(
          (json['created_at'] ?? json['createdAt'] ?? '').toString(),
        ) ??
        DateTime.now();

    final expiresRaw =
        (json['offer_expires_at'] ?? json['offerExpiresAt'] ?? '').toString();

    return OrderModel(
      id: id,
      orderNumber: orderNumber,
      customerName: customerName,
      customerPhone: customerPhone,
      deliveryAddress: deliveryAddress,
      deliveryLat: deliveryLat,
      deliveryLng: deliveryLng,
      gasType: gasType,
      quantity: quantity,
      totalAmount: totalAmount,
      status: OrderStatus.fromString(rawStatus),
      createdAt: createdAt,
      notes: json['notes'] as String? ?? json['customer_note'] as String?,
      distanceKm: asDouble(json['distanceKm'] ?? json['distance_km']),
      vendorName: vendorName,
      pickupAddress: pickupAddress,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      paymentMethod: paymentMethod,
      isCod: isCod,
      amountDue: amountDue,
      riderEarning: asDouble(
          json['rider_earning'] ?? json['rider_fee'] ?? json['riderEarning']),
      otpRequired: asBool(json['delivery_otp_required'] ??
          json['requires_delivery_otp'] ??
          json['otp_required']),
      offerExpiresAt: DateTime.tryParse(expiresRaw),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'order_number': orderNumber,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'deliveryAddress': deliveryAddress,
        'deliveryLat': deliveryLat,
        'deliveryLng': deliveryLng,
        'gasType': gasType,
        'quantity': quantity,
        'totalAmount': totalAmount,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'notes': notes,
        'distanceKm': distanceKm,
        'vendorName': vendorName,
        'pickupAddress': pickupAddress,
        'pickupLat': pickupLat,
        'pickupLng': pickupLng,
        'paymentMethod': paymentMethod,
        'amount_due': amountDue,
        'riderEarning': riderEarning,
        'otp_required': otpRequired,
        'offerExpiresAt': offerExpiresAt?.toIso8601String(),
      };

  OrderModel copyWith({OrderStatus? status}) => OrderModel(
        id: id,
        orderNumber: orderNumber,
        customerName: customerName,
        customerPhone: customerPhone,
        deliveryAddress: deliveryAddress,
        deliveryLat: deliveryLat,
        deliveryLng: deliveryLng,
        gasType: gasType,
        quantity: quantity,
        totalAmount: totalAmount,
        status: status ?? this.status,
        createdAt: createdAt,
        notes: notes,
        distanceKm: distanceKm,
        vendorName: vendorName,
        pickupAddress: pickupAddress,
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        paymentMethod: paymentMethod,
        isCod: isCod,
        amountDue: amountDue,
        riderEarning: riderEarning,
        otpRequired: otpRequired,
        offerExpiresAt: offerExpiresAt,
      );
}
