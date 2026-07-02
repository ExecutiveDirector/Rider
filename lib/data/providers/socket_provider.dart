// lib/data/providers/socket_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/socket_service.dart';

final socketStatusProvider = StreamProvider<String>((ref) {
  return SocketService.instance.onStatusChange.map((s) => s.name);
});
