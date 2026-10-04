import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/multiplayer_user.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

class AuthNotifier extends StateNotifier<MultiplayerUser?> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(_authService.currentUser) {
    _authService.addListener((user) {
      state = user;
    });
  }

  bool get isAuthenticated => state != null;

  Future<MultiplayerUser?> signInWithGoogle() async {
    return await _authService.signInWithGoogle();
  }

  Future<MultiplayerUser> signInAsGuest({String? name}) async {
    return await _authService.signInAsGuest(name: name);
  }

  Future<MultiplayerUser> completeProfile({
    required String name,
    required String dateOfBirth,
    required String country,
  }) async {
    final user = await _authService.createAccountWithProfile(
      name: name,
      dateOfBirth: dateOfBirth,
      country: country,
    );
    state = user;
    return user;
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, MultiplayerUser?>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider));
});
