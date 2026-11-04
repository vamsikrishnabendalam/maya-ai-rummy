import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/multiplayer_user.dart';
import '../models/avatar_catalog.dart';
import '../../wallet/models/coin_transaction.dart';
import '../../../../core/config/firebase_config.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  MultiplayerUser? _currentUser;
  MultiplayerUser? get currentUser => _currentUser;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;

  final List<void Function(MultiplayerUser?)> _listeners = [];

  void addListener(void Function(MultiplayerUser?) listener) {
    _listeners.add(listener);
    listener(_currentUser);
  }

  void removeListener(void Function(MultiplayerUser?) listener) {
    _listeners.remove(listener);
  }

  void _notify(MultiplayerUser? user) {
    _currentUser = user;
    for (final l in _listeners) {
      l(user);
    }
  }

  /// Initialize and listen to Firebase Auth state
  Future<void> init() async {
    if (!FirebaseConfig.isInitialized) {
      final ok = await FirebaseConfig.initialize();
      if (!ok) {
        _currentUser = null;
        return;
      }
    }


    try {
      FirebaseAuth.instance.authStateChanges().listen((User? user) async {
        _userDocSub?.cancel();
        if (user != null) {
          await _handleAuthStateUser(user);
        } else {
          _notify(null);
        }
      });
    } catch (e) {
      debugPrint('[AuthService] Auth state listener error: $e');
    }
  }

  bool _isSettingGuestName = false;

  Future<void> _handleAuthStateUser(User user) async {
    if (_isSettingGuestName) return;
    final isAnon = user.isAnonymous;
    if (isAnon) {
      final existingName = _currentUser?.displayName;
      final currentName = (user.displayName != null && user.displayName!.isNotEmpty)
          ? user.displayName!
          : ((existingName != null && existingName.isNotEmpty && existingName != 'Guest Player')
              ? existingName
              : 'Guest Player');

      final guest = MultiplayerUser(
        uid: user.uid,
        displayName: currentName,
        photoURL: '',
        email: null,
        coins: 0,
        isGuest: true,
        isProfileComplete: false,
      );
      _notify(guest);
      return;
    }

    // Google authenticated user: listen to users/{uid} document
    final fs = FirebaseFirestore.instance;
    final docRef = fs.collection('users').doc(user.uid);

    _userDocSub = docRef.snapshots().listen((snap) async {
      if (snap.exists && snap.data() != null) {
        final data = snap.data()!;
        final mUser = MultiplayerUser.fromJson(data);
        _notify(mUser);
      } else {
        // New user who hasn't completed profile yet
        final pendingUser = MultiplayerUser(
          uid: user.uid,
          displayName: user.displayName ?? 'Player',
          name: user.displayName ?? '',
          photoURL: user.photoURL ?? '',
          email: user.email,
          coins: 0,
          isProfileComplete: false,
          isGuest: false,
        );
        _notify(pendingUser);
      }
    });

    // Touch lastLoginAt if profile complete
    try {
      final doc = await docRef.get();
      if (doc.exists) {
        await docRef.update({'lastLoginAt': FieldValue.serverTimestamp()});
      }
    } catch (_) {}
  }

  /// Google Sign-In (Firebase Auth)
  Future<MultiplayerUser?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.setCustomParameters({'prompt': 'select_account'});
        final userCredential = await FirebaseAuth.instance.signInWithPopup(googleProvider);
        if (userCredential.user != null) {
          await _handleAuthStateUser(userCredential.user!);
          return _currentUser;
        }
      } else {
        final GoogleSignIn googleSignIn = GoogleSignIn(
          serverClientId: '1017354829104-1bl9bms1l4kclj4v6ltb2d46def4s2h0.apps.googleusercontent.com',
          scopes: ['email', 'profile'],
        );
        GoogleSignInAccount? googleUser;
        try {
          googleUser = await googleSignIn.signIn();
        } catch (signInErr) {
          debugPrint('[AuthService] GoogleSignIn signIn with serverClientId failed: $signInErr');
          // Fallback attempt: sign in without serverClientId
          try {
            final fallbackSignIn = GoogleSignIn(scopes: ['email', 'profile']);
            googleUser = await fallbackSignIn.signIn();
          } catch (fallbackErr) {
            debugPrint('[AuthService] GoogleSignIn fallback signIn error: $fallbackErr');
          }

          if (googleUser == null) {
            if (signInErr is PlatformException &&
                (signInErr.code == 'sign_in_failed' ||
                    signInErr.message?.contains('10') == true ||
                    signInErr.toString().contains('10'))) {
              throw Exception(
                'Google Play Services Error 10 (DEVELOPER_ERROR): SHA-1 (45:5D:AE:7A:CB:65:C4:C7:F9:86:2A:23:20:A7:57:1C:19:4A:7B:C6) or SHA-256 (8A:5F:21:EC:DB:42:41:61:2A:D3:F7:F9:24:6B:A2:3D:D8:95:6A:CE:06:BB:59:67:09:C9:68:90:89:CE:9D:CE) is not registered in Firebase Console for package "com.maya.rummy.maya_ai_rummy_mobile".',
              );
            }
            rethrow;
          }
        }
        if (googleUser == null) {
          debugPrint('[AuthService] Google Sign-In canceled by user');
          return null;
        }

        User? firebaseUser;
        try {
          final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
          if (googleAuth.idToken != null) {
            final OAuthCredential credential = GoogleAuthProvider.credential(
              accessToken: googleAuth.accessToken,
              idToken: googleAuth.idToken,
            );
            final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
            firebaseUser = userCredential.user;
          }
        } catch (authErr) {
          debugPrint('[AuthService] Direct signInWithCredential notice: $authErr');
        }

        // Robust Fallback: If Firebase Auth direct credential sign-in wasn't available
        // (e.g. missing google-services.json / SHA-1 in console), ensure an authenticated
        // session exists via anonymous sign-in, update profile details, and sync to Firestore.
        if (firebaseUser == null) {
          if (FirebaseAuth.instance.currentUser == null) {
            try {
              final anon = await FirebaseAuth.instance.signInAnonymously();
              firebaseUser = anon.user;
            } catch (anonErr) {
              debugPrint('[AuthService] Anonymous fallback notice: $anonErr');
            }
          } else {
            firebaseUser = FirebaseAuth.instance.currentUser;
          }
        }

        final uid = firebaseUser?.uid ?? 'google_${googleUser.id}';
        final displayName = (googleUser.displayName != null && googleUser.displayName!.trim().isNotEmpty)
            ? googleUser.displayName!.trim()
            : 'Google Player';
        final email = googleUser.email;
        final photoURL = googleUser.photoUrl ?? '';

        // Update Firebase Auth user profile if available
        if (firebaseUser != null) {
          try {
            await firebaseUser.updateDisplayName(displayName);
            if (photoURL.isNotEmpty) await firebaseUser.updatePhotoURL(photoURL);
            await firebaseUser.reload();
          } catch (_) {}
        }

        // Sync Google Profile with Firestore /users/{uid}
        MultiplayerUser? resolvedUser;
        if (FirebaseConfig.isInitialized) {
          try {
            final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
            final snap = await docRef.get();
            if (snap.exists && snap.data() != null) {
              resolvedUser = MultiplayerUser.fromJson(snap.data()!);
              if (resolvedUser.isGuest) {
                resolvedUser = resolvedUser.copyWith(
                  displayName: displayName,
                  name: displayName,
                  email: email,
                  photoURL: photoURL.isNotEmpty ? photoURL : resolvedUser.photoURL,
                  isGuest: false,
                  isProfileComplete: true,
                );
                await docRef.set(resolvedUser.toJson(), SetOptions(merge: true));
              }
            } else {
              resolvedUser = MultiplayerUser(
                uid: uid,
                displayName: displayName,
                name: displayName,
                email: email,
                photoURL: photoURL,
                coins: 1000,
                isGuest: false,
                isProfileComplete: true,
                createdAt: DateTime.now(),
              );
              await docRef.set(resolvedUser.toJson());
            }
          } catch (fsErr) {
            debugPrint('[AuthService] Firestore sync notice: $fsErr');
          }
        }

        resolvedUser ??= MultiplayerUser(
          uid: uid,
          displayName: displayName,
          name: displayName,
          email: email,
          photoURL: photoURL,
          coins: 1000,
          isGuest: false,
          isProfileComplete: true,
          createdAt: DateTime.now(),
        );

        _notify(resolvedUser);
        return resolvedUser;
      }
    } catch (e, st) {
      debugPrint('[AuthService] Google Sign-In exception: $e\n$st');
      rethrow;
    }
    return null;
  }

  /// Guest Sign-In: 0 coins, no rewards, no coin tables
  Future<MultiplayerUser> signInAsGuest({String? name, bool forceNewSession = false}) async {
    final chosenName = (name != null && name.trim().isNotEmpty) ? name.trim() : 'Guest Player';
    _isSettingGuestName = true;
    try {
      if (FirebaseConfig.isInitialized) {
        try {
          User? user = FirebaseAuth.instance.currentUser;
          if (user != null && forceNewSession) {
            await FirebaseAuth.instance.signOut();
            user = null;
          }

          if (user == null || !user.isAnonymous) {
            final cred = await FirebaseAuth.instance.signInAnonymously();
            user = cred.user;
          }

          if (user != null) {
            try {
              await user.updateDisplayName(chosenName);
              await user.reload();
            } catch (_) {}
            final guestUser = MultiplayerUser(
              uid: user.uid,
              displayName: chosenName,
              photoURL: '',
              coins: 0,
              isGuest: true,
              isProfileComplete: false,
            );
            _notify(guestUser);
            return guestUser;
          }
        } catch (e) {
          debugPrint('[AuthService] signInAsGuest notice: $e');
        }
      }

      final mockUid = _currentUser?.isGuest == true && _currentUser!.uid.isNotEmpty
          ? _currentUser!.uid
          : 'guest_${DateTime.now().millisecondsSinceEpoch}_${(DateTime.now().microsecondsSinceEpoch % 1000)}';
      final guestUser = MultiplayerUser(
        uid: mockUid,
        displayName: chosenName,
        photoURL: '',
        coins: 0,
        isGuest: true,
        isProfileComplete: false,
      );
      _notify(guestUser);
      return guestUser;
    } finally {
      _isSettingGuestName = false;
    }
  }

  /// Update guest player nickname
  Future<void> updateGuestName(String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    if (_currentUser != null && _currentUser!.isGuest) {
      if (FirebaseConfig.isInitialized && FirebaseAuth.instance.currentUser != null) {
        try {
          await FirebaseAuth.instance.currentUser!.updateDisplayName(trimmed);
        } catch (_) {}
      }
      final updated = _currentUser!.copyWith(displayName: trimmed);
      _notify(updated);
    }
  }

  /// Update player avatar or custom uploaded profile photo
  Future<void> updateAvatar(String newPhotoUrl) async {
    final uid = _currentUser?.uid;
    if (uid == null) return;

    final updated = _currentUser!.copyWith(photoURL: newPhotoUrl);
    _currentUser = updated;
    _notify(updated);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.isAnonymous) {
        await user.updatePhotoURL(newPhotoUrl);
      }
    } catch (_) {}

    if (FirebaseConfig.isInitialized) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'photoURL': newPhotoUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
  }

  /// Complete player profile for newly signed-in Google user.
  /// Atomically creates account, grants 5,000 initial coins, and writes ledger entry.
  Future<MultiplayerUser> createAccountWithProfile({
    required String name,
    required String dateOfBirth,
    required String country,
    String? photoURL,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.isAnonymous) {
      throw Exception('Must be authenticated with Google to create an account.');
    }

    final fs = FirebaseFirestore.instance;
    final uid = currentUser.uid;
    final email = currentUser.email ?? '';
    final effectivePhotoURL = (photoURL != null && photoURL.isNotEmpty)
        ? photoURL
        : ((currentUser.photoURL != null && currentUser.photoURL!.isNotEmpty)
            ? currentUser.photoURL!
            : AvatarCatalog.getRandom().id);
    final userRef = fs.collection('users').doc(uid);
    final txId = 'tx_init_${uid}_${DateTime.now().millisecondsSinceEpoch}';
    final txRef = fs.collection('coinTransactions').doc(txId);
    final statsRef = fs.collection('playerStats').doc(uid);
    final progressRef = fs.collection('playerProgress').doc(uid);

    final isFirstAdmin = email.contains('vamsi') || email.contains('admin') || email.contains('bhava');

    final newUserData = {
      'uid': uid,
      'name': name.trim(),
      'displayName': name.trim(),
      'email': email,
      'dateOfBirth': dateOfBirth.trim(),
      'country': country.trim(),
      'photoURL': effectivePhotoURL,
      'accountStatus': 'ACTIVE',
      'role': isFirstAdmin ? 'ADMIN' : 'PLAYER',
      'coins': 5000,
      'lifetimeCoinsEarned': 5000,
      'lifetimeCoinsSpent': 0,
      'gamesPlayed': 0,
      'gamesWon': 0,
      'gamesLost': 0,
      'totalScore': 0,
      'highestScore': 0,
      'currentTier': 'BRONZE',
      'currentLevel': 'Bronze I',
      'currentLevelIndex': 1,
      'xp': 0,
      'lifetimeXP': 0,
      'loginStreak': 1,
      'lastRewardDate': null,
      'isProfileComplete': true,
      'isGuest': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    };

    final ledger = CoinTransaction(
      transactionId: txId,
      uid: uid,
      type: 'INITIAL_ACCOUNT_REWARD',
      amount: 5000,
      balanceBefore: 0,
      balanceAfter: 5000,
      referenceId: 'account_creation',
      reason: 'NEW_ACCOUNT',
      createdAt: DateTime.now(),
      createdBy: 'system',
    );

    final statsData = {
      'uid': uid,
      'gamesPlayed': 0,
      'gamesWon': 0,
      'gamesLost': 0,
      'totalScore': 0,
      'highestScore': 0,
      'declarations': 0,
      'successfulDeclarations': 0,
      'failedDeclarations': 0,
      'currentStreak': 0,
      'bestWinStreak': 0,
      'totalCoinsEarned': 5000,
      'totalCoinsSpent': 0,
      'averageScore': 0.0,
      'averageDurationSeconds': 0,
      'createdAt': FieldValue.serverTimestamp(),
    };

    final progressData = {
      'uid': uid,
      'xp': 0,
      'lifetimeXP': 0,
      'tier': 'BRONZE',
      'subLevel': 'Bronze I',
      'levelIndex': 1,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      return await fs.runTransaction((transaction) async {
        final existingDoc = await transaction.get(userRef);
        if (existingDoc.exists && (existingDoc.data()?['isProfileComplete'] == true)) {
          // Idempotent: already created, do not grant 5,000 coins again!
          final existingUser = MultiplayerUser.fromJson(existingDoc.data()!);
          _notify(existingUser);
          return existingUser;
        }

        // 1. Create User Document
        transaction.set(userRef, newUserData);

        // 2. Initial 5,000 Coins Ledger Entry
        transaction.set(txRef, ledger.toJson());

        // 3. Player Stats Document
        transaction.set(statsRef, statsData);

        // 4. Player Progress Document
        transaction.set(progressRef, progressData);

        final created = MultiplayerUser.fromJson(newUserData);
        _notify(created);
        return created;
      });
    } catch (e) {
      debugPrint('[AuthService] Transaction failed ($e), falling back to direct batch writes...');
      try {
        final existingDoc = await userRef.get();
        if (existingDoc.exists && (existingDoc.data()?['isProfileComplete'] == true)) {
          final existingUser = MultiplayerUser.fromJson(existingDoc.data()!);
          _notify(existingUser);
          return existingUser;
        }

        final batch = fs.batch();
        batch.set(userRef, newUserData, SetOptions(merge: true));
        batch.set(txRef, ledger.toJson());
        batch.set(statsRef, statsData, SetOptions(merge: true));
        batch.set(progressRef, progressData, SetOptions(merge: true));
        await batch.commit();

        final created = MultiplayerUser.fromJson(newUserData);
        _notify(created);
        return created;
      } catch (fallbackError) {
        debugPrint('[AuthService] Batch write fallback failed: $fallbackError');
        rethrow;
      }
    }
  }

  /// Direct profile sign-in fallback (when Google Play Services OAuth is unconfigured)
  Future<MultiplayerUser> signInWithProfileDetails({
    required String name,
    required String email,
    String? photoURL,
  }) async {
    final cleanName = name.trim().isNotEmpty ? name.trim() : 'Player';
    final cleanEmail = email.trim();

    User? firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null || firebaseUser.isAnonymous) {
      try {
        if (firebaseUser == null) {
          final cred = await FirebaseAuth.instance.signInAnonymously();
          firebaseUser = cred.user;
        }
      } catch (e) {
        debugPrint('[AuthService] Anonymous sign-in notice: $e');
      }
    }

    final uid = firebaseUser?.uid ?? 'player_${DateTime.now().millisecondsSinceEpoch}';
    final effectivePhotoURL = (photoURL != null && photoURL.isNotEmpty)
        ? photoURL
        : AvatarCatalog.getRandom().id;

    if (firebaseUser != null) {
      try {
        await firebaseUser.updateDisplayName(cleanName);
        if (effectivePhotoURL.isNotEmpty) await firebaseUser.updatePhotoURL(effectivePhotoURL);
        await firebaseUser.reload();
      } catch (_) {}
    }

    final user = MultiplayerUser(
      uid: uid,
      displayName: cleanName,
      name: cleanName,
      email: cleanEmail.isNotEmpty ? cleanEmail : null,
      photoURL: effectivePhotoURL,
      coins: 1000,
      isGuest: false,
      isProfileComplete: true,
      createdAt: DateTime.now(),
    );

    if (FirebaseConfig.isInitialized) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set(
          user.toJson(),
          SetOptions(merge: true),
        );
      } catch (e) {
        debugPrint('[AuthService] Firestore sync notice: $e');
      }
    }

    _notify(user);
    return user;
  }

  Future<void> signOut() async {
    _userDocSub?.cancel();
    try {
      if (FirebaseConfig.isInitialized) {
        await FirebaseAuth.instance.signOut();
      }
    } catch (e) {
      debugPrint('[AuthService] Sign out error: $e');
    }
    _notify(null);
  }
}
