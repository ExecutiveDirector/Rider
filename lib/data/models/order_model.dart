// lib/data/models/order_model.dart

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
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    // ID: backend returns order_id (bigint) or id (string)
    final id = (json['id'] ?? json['order_id'] ?? '').toString();

    final orderNumber = json['order_number'] as String? ?? id;

    // Customer: flat fields from getRiderActiveOrders,
    // or nested customer object from getOrderById
    final customer = json['customer'] as Map?;
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
        ((json['delivery_latitude'] ?? json['deliveryLat'] ?? 0) as num)
            .toDouble();
    final deliveryLng =
        ((json['delivery_longitude'] ?? json['deliveryLng'] ?? 0) as num)
            .toDouble();

    // Items: pull gas type + quantity from first order_item
    final rawItems =
        json['items'] as List? ?? json['order_items'] as List? ?? [];
    final firstItem = rawItems.isNotEmpty
        ? Map<String, dynamic>.from(rawItems.first as Map)
        : <String, dynamic>{};

    final gasType = firstItem['product_name'] as String? ??
        json['gasType'] as String? ??
        json['gas_type'] as String? ??
        'LPG Gas';

    final quantity =
        ((firstItem['quantity'] ?? json['quantity'] ?? 1) as num).toDouble();

    // Totals: grand_total = total_amount + delivery_fee (computed server-side)
    final totalAmount = ((json['grand_total'] ??
            json['total_amount'] ??
            json['totalAmount'] ??
            0) as num)
        .toDouble();

    // Status: backend sends order_status (raw DB) or status (normalised)
    final rawStatus = json['order_status'] as String? ??
        json['status'] as String? ??
        'pending';

    final createdAt = DateTime.tryParse(
          json['created_at'] as String? ?? json['createdAt'] as String? ?? '',
        ) ??
        DateTime.now();

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
      distanceKm: json['distanceKm'] != null
          ? (json['distanceKm'] as num).toDouble()
          : null,
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
      );
}
