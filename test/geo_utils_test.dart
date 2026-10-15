import 'package:flutter_test/flutter_test.dart';
import 'package:aquagas_rider/core/utils/geo_utils.dart';

void main() {
  test('haversine ~111 km per degree of latitude', () {
    expect((haversineMeters(0, 0, 1, 0) / 1000).round(), 111);
  });
  test('formatDistance switches to km at 1000 m', () {
    expect(formatDistance(850), '850 m');
    expect(formatDistance(2400), '2.4 km');
  });
  test('roughMinutes is at least 1', () {
    expect(roughMinutes(10), 1);
    expect(roughMinutes(6000), greaterThan(10));
  });
}
