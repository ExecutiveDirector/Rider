// lib/data/models/delivery_proof.dart
import 'order_model.dart';

/// Everything the rider submits when completing a delivery.
class DeliveryProof {
  /// Code the customer reads out. Null when not entered.
  final String? otp;

  /// Local path of the compressed drop-off photo.
  final String? photoPath;

  /// Empty cylinders taken back from the customer (cylinder swap).
  final int emptyCylindersCollected;

  /// Cash handed over by the customer. Null for prepaid orders.
  final double? cashCollected;

  final String? note;
  final double? latitude;
  final double? longitude;

  /// How far the rider was from the drop-off pin when confirming.
  final double? distanceFromDropoffM;

  const DeliveryProof({
    this.otp,
    this.photoPath,
    this.emptyCylindersCollected = 0,
    this.cashCollected,
    this.note,
    this.latitude,
    this.longitude,
    this.distanceFromDropoffM,
  });

  bool get hasPhoto => photoPath != null && photoPath!.isNotEmpty;

  /// Text fields only (the photo is attached separately as multipart).
  /// Null values are omitted: FormData would otherwise send the string "null".
  Map<String, dynamic> toFields() => {
        if (otp != null && otp!.isNotEmpty) 'otp': otp,
        'empty_cylinders_collected': emptyCylindersCollected,
        if (cashCollected != null) 'cash_collected': cashCollected,
        if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (distanceFromDropoffM != null)
          'distance_from_dropoff_m': distanceFromDropoffM!.round(),
      };
}

/// Client-side rules for completing a delivery. The server must enforce the
/// same rules; these exist so the rider gets an immediate, specific message.
class ProofRules {
  ProofRules._();

  /// Beyond this distance from the drop-off pin the rider is asked to confirm.
  static const double geofenceMeters = 250;

  /// Returns a message for the first problem found, or null when OK.
  static String? validate({
    required OrderModel order,
    required String otp,
    required bool hasPhoto,
    String? cashText,
    String note = '',
    bool cashRequired = true,
  }) {
    final code = otp.trim();

    if (order.otpRequired && code.isEmpty) {
      return 'Ask the customer for their delivery code and enter it.';
    }
    if (code.isNotEmpty && !RegExp(r'^\d{4,6}$').hasMatch(code)) {
      return 'The delivery code is 4 to 6 digits.';
    }
    if (code.isEmpty && !hasPhoto) {
      return 'Take a photo of the delivery or enter the customer\'s code.';
    }

    if (order.isCod && cashRequired) {
      final cash = double.tryParse((cashText ?? '').replaceAll(',', '').trim());
      if (cash == null) {
        return 'Enter the cash you collected from the customer.';
      }
      if (cash < 0) return 'Cash collected cannot be negative.';
      if ((cash - order.amountDue).abs() > 0.5 && note.trim().isEmpty) {
        return 'The cash differs from the KES ${order.amountDue.toStringAsFixed(0)} '
            'due. Add a note explaining why.';
      }
    }
    return null;
  }
}
