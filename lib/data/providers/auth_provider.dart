// lib/data/providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/driver_model.dart';
import '../repositories/auth_repository.dart';
import '../../core/services/api_service.dart';

final authRepositoryProvider = Provider((_) => AuthRepository());

class AuthState {
  final DriverModel? driver;
  final bool isLoading;
  final String? error;

  const AuthState({this.driver, this.isLoading = false, this.error});

  bool get isAuthenticated => driver != null;

  AuthState copyWith({
    DriverModel? driver,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      driver: driver ?? this.driver,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;

  AuthNotifier(this._repo) : super(const AuthState());

  Future<void> login(String identifier, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final driver =
          await _repo.login(identifier: identifier, password: password);
      state = AuthState(driver: driver);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: dioErrorMessage(e));
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState();
  }

  /// Fetches the rider profile from the API and updates state.
  /// Called on home screen mount and pull-to-refresh.
  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true);
    try {
      final driver = await _repo.restoreSession();
      if (driver != null) {
        state = AuthState(
            driver: driver.copyWith(isOnline: state.driver?.isOnline ?? false));
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  void setDriver(DriverModel driver) {
    state = AuthState(driver: driver);
  }

  void toggleOnlineStatus() {
    if (state.driver == null) return;
    state = state.copyWith(
      driver: state.driver!.copyWith(isOnline: !state.driver!.isOnline),
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.read(authRepositoryProvider)),
);
