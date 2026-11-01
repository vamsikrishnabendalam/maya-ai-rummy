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

  Future<MultiplayerUser> signInAsGuest({String? name, bool forceNewSession = false}) async {
    return await _authService.signInAsGuest(name: name, forceNewSession: forceNewSession);
  }

  Future<void> updateGuestName(String newName) async {
    await _authService.updateGuestName(newName);
  }

  Future<MultiplayerUser> completeProfile({
    required String name,
    required String dateOfBirth,
    required String country,
    String? photoURL,
  }) async {
    final user = await _authService.createAccountWithProfile(
      name: name,
      dateOfBirth: dateOfBirth,
      country: country,
      photoURL: photoURL,
    );
    state = user;
    return user;
  }

  Future<void> updateAvatar(String newPhotoUrl) async {
    await _authService.updateAvatar(newPhotoUrl);
    state = _authService.currentUser;
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, MultiplayerUser?>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider));
});
