import 'package:flutter_test/flutter_test.dart';
import 'package:aquagas_rider/data/models/driver_model.dart';

void main() {
  test('parses the profile endpoint (DECIMAL as string, tinyint as int)', () {
    final d = DriverModel.fromJson({
      'rider_id': 66,
      'first_name': 'Jane',
      'last_name': 'Doe',
      'phone': '0712345678',
      'rating': '4.50',
      'total_deliveries': '12',
      'is_verified': 1,
      'account': {'email': 'a@b.co', 'phone_number': '+254712345678'},
    });
    expect(d.id, 66);
    expect(d.name, 'Jane Doe');
    expect(d.rating, 4.5);
    expect(d.totalDeliveries, 12);
    expect(d.isVerified, true);
  });
}
