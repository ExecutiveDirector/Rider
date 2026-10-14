import 'package:flutter_test/flutter_test.dart';
import 'package:aquagas_rider/data/models/delivery_proof.dart';
import 'package:aquagas_rider/data/models/order_model.dart';

OrderModel _order(Map<String, dynamic> extra) => OrderModel.fromJson({
      'id': 7,
      'order_number': 'AG-7',
      'order_status': 'ready',
      'grand_total': '1250.50', // MySQL DECIMAL arrives as a string
      ...extra,
    });

void main() {
  group('OrderModel.fromJson', () {
    test('reads DECIMAL strings without throwing', () {
      final o = _order({'delivery_latitude': '-1.2921', 'delivery_longitude': '36.8219'});
      expect(o.totalAmount, 1250.5);
      expect(o.deliveryLat, closeTo(-1.2921, 1e-9));
      expect(o.hasDeliveryLocation, isTrue);
    });

    test('unpaid cash order is COD and owes the grand total', () {
      final o = _order({'payment_method': 'COD', 'payment_status': 'pending'});
      expect(o.isCod, isTrue);
      expect(o.amountDue, 1250.5);
    });

    test('paid or mobile-money order is not COD', () {
      expect(_order({'payment_method': 'cash', 'payment_status': 'paid'}).isCod, isFalse);
      expect(_order({'payment_method': 'mpesa', 'payment_status': 'pending'}).isCod, isFalse);
    });

    test('pickup comes from a nested outlet', () {
      final o = _order({
        'outlet': {'name': 'Gas Hub', 'latitude': '-1.30', 'longitude': 36.8, 'address': 'Ngong Rd'},
      });
      expect(o.hasPickupLocation, isTrue);
      expect(o.vendorName, 'Gas Hub');
      expect(o.pickupAddress, 'Ngong Rd');
    });

    test('rider earning stays null when the backend does not send it', () {
      expect(_order({}).riderEarning, isNull);
      expect(_order({'rider_earning': '150'}).riderEarning, 150);
    });
  });

  group('ProofRules.validate', () {
    test('needs a code or a photo', () {
      expect(ProofRules.validate(order: _order({}), otp: '', hasPhoto: false), isNotNull);
      expect(ProofRules.validate(order: _order({}), otp: '', hasPhoto: true), isNull);
      expect(ProofRules.validate(order: _order({}), otp: '4821', hasPhoto: false), isNull);
    });

    test('requires the code when the backend issued one', () {
      final o = _order({'delivery_otp_required': true});
      expect(ProofRules.validate(order: o, otp: '', hasPhoto: true), isNotNull);
      expect(ProofRules.validate(order: o, otp: '482', hasPhoto: true), isNotNull);
      expect(ProofRules.validate(order: o, otp: '4821', hasPhoto: false), isNull);
    });

    test('COD needs cash; a mismatch needs a note', () {
      final o = _order({'payment_method': 'cod', 'payment_status': 'pending'});
      expect(ProofRules.validate(order: o, otp: '4821', hasPhoto: false), isNotNull);
      expect(ProofRules.validate(order: o, otp: '4821', hasPhoto: false, cashText: '1,250.50'), isNull);
      expect(ProofRules.validate(order: o, otp: '4821', hasPhoto: false, cashText: '1000'), isNotNull);
      expect(ProofRules.validate(order: o, otp: '4821', hasPhoto: false, cashText: '1000', note: 'Customer short'), isNull);
    });
  });

  test('DeliveryProof omits null fields so FormData never sends "null"', () {
    const p = DeliveryProof(emptyCylindersCollected: 1);
    expect(p.toFields(), {'empty_cylinders_collected': 1});
  });
}
