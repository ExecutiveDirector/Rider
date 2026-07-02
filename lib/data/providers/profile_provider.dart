import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/rider_profile.dart';
import '../repositories/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(),
);

final profileProvider = FutureProvider<RiderProfile>((ref) async {
  return ref.read(profileRepositoryProvider).getProfile();
});
