import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';

class UserProvider extends ChangeNotifier {
  UserProvider({required NotificationService notificationService})
    : _notificationService = notificationService;

  final NotificationService _notificationService;

  AuthService? _authService;
  FirestoreService? _firestoreService;

  AppUser? _user;
  bool _isLoading = false;
  String? _errorMessage;
  String? _activeUid;
  StreamSubscription<AppUser>? _userSubscription;

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  String? get activeGroupId => _user?.activeGroupId;

  void updateDependencies({
    required AuthService authService,
    required FirestoreService firestoreService,
  }) {
    _authService = authService;
    _firestoreService = firestoreService;
  }

  Future<void> setFirebaseUser(User firebaseUser) async {
    if (_authService == null || _firestoreService == null) {
      return;
    }
    if (_activeUid == firebaseUser.uid && _user != null) {
      return;
    }

    _activeUid = firebaseUser.uid;
    await _ensureUserDocument(firebaseUser);
    _listenToUser(firebaseUser.uid);
    await _syncDeviceToken();
  }

  Future<void> refreshUser() async {
    final current = _authService?.currentUser;
    if (current != null) {
      await _authService?.reloadCurrentUser();
      await _ensureUserDocument(current, forceRefresh: true);
    }
  }

  Future<void> updateDisplayName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _authService == null || _firestoreService == null) {
      return;
    }

    _setLoading(true);
    try {
      await _authService!.currentUser?.updateDisplayName(trimmed);
      await _firestoreService!.updateUserProfile(
        uid: _authService!.currentUser!.uid,
        updates: {'name': trimmed},
      );
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateProfile({
    required String displayName,
    String? username,
    String? country,
    String? city,
    String? bio,
  }) async {
    if (_authService == null || _firestoreService == null) {
      _errorMessage = 'Services not initialized';
      notifyListeners();
      return;
    }

    final trimmedName = displayName.trim();
    if (trimmedName.isEmpty) {
      _errorMessage = 'Display name cannot be empty';
      notifyListeners();
      return;
    }

    _setLoading(true);
    _errorMessage = null;
    try {
      // Update Firebase Auth display name
      await _authService!.currentUser?.updateDisplayName(trimmedName);
      
      // Prepare updates for Firestore
      final updates = <String, dynamic>{
        'name': trimmedName,
      };
      
      // Only include non-empty optional fields
      if (username != null) {
        final trimmedUsername = username.trim();
        updates['username'] = trimmedUsername.isEmpty ? null : trimmedUsername;
      }
      
      if (country != null) {
        final trimmedCountry = country.trim();
        updates['country'] = trimmedCountry.isEmpty ? null : trimmedCountry;
      }
      
      if (city != null) {
        final trimmedCity = city.trim();
        updates['city'] = trimmedCity.isEmpty ? null : trimmedCity;
      }
      
      if (bio != null) {
        final trimmedBio = bio.trim();
        updates['bio'] = trimmedBio.isEmpty ? null : trimmedBio;
      }

      // Update Firestore profile
      await _firestoreService!.updateUserProfile(
        uid: _authService!.currentUser!.uid,
        updates: updates,
      );
      
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _authService?.logout();
    await _notificationService.unsubscribeFromAllTopics();
    await _userSubscription?.cancel();
    _userSubscription = null;
    _user = null;
    _activeUid = null;
    notifyListeners();
  }

  Future<void> setActiveGroup(String? groupId) async {
    if (_firestoreService == null || _user == null) {
      return;
    }

    try {
      await _firestoreService!.updateUserProfile(
        uid: _user!.uid,
        updates: {'activeGroupId': groupId},
      );
    } catch (error) {
      _errorMessage = error.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  Future<void> _ensureUserDocument(
    User firebaseUser, {
    bool forceRefresh = false,
  }) async {
    if (_firestoreService == null) {
      return;
    }
    if (!forceRefresh && _user != null && _user!.uid == firebaseUser.uid) {
      return;
    }

    _setLoading(true);
    try {
      var existing = await _firestoreService!.fetchUser(firebaseUser.uid);
      if (existing == null) {
        existing = AppUser(
          uid: firebaseUser.uid,
          name: firebaseUser.displayName ?? '',
          email: firebaseUser.email ?? '',
          groups: const [],
        );
        await _firestoreService!.createUserRecord(existing);
      }
      _user = existing;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  void _listenToUser(String uid) {
    _userSubscription?.cancel();
    _userSubscription = _firestoreService?.watchUser(uid).listen(
      (event) {
        _user = event;
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = error.toString();
        notifyListeners();
      },
    );
  }

  Future<void> _syncDeviceToken() async {
    if (_firestoreService == null) {
      return;
    }
    final token = await _notificationService.getDeviceToken();
    if (token != null && _activeUid != null) {
      await _firestoreService!.saveDeviceToken(_activeUid!, token);
    }
  }

  void _setLoading(bool value) {
    if (_isLoading == value) {
      return;
    }
    _isLoading = value;
    notifyListeners();
  }
}
