import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final BiometricService _biometricService = BiometricService();

  UserModel? _user;
  bool _isAuthenticated = false;
  TypeOfBiometric _availableBiometrics = TypeOfBiometric.none;

  UserModel? get user => _user;
  bool get isAuthenticated => _isAuthenticated;
  String get userName => _user?.name ?? '';
  String get userEmail => _user?.email ?? '';
  String get userId => _user?.id ?? '';
  TypeOfBiometric get availableBiometrics => _availableBiometrics;

  Future<void> checkAuthState() async {
    final currentUser = _authService.currentUser;
    if (currentUser != null && currentUser.emailVerified) {
      final userData = await _authService.getUserById(currentUser.uid);
      if (userData != null) {
        _user = userData;
        _isAuthenticated = true;
        await checkBiometricAvailability();
        notifyListeners();
      }
    }
  }

  Future<void> checkBiometricAvailability() async {
    _availableBiometrics = await _biometricService.getAvailableBiometrics();
    notifyListeners();
  }

  Future<bool> checkEmailVerified() async {
    if (_user == null) return false;

    final isVerified = await _authService.isEmailVerified(_user!.email);
    if (isVerified) {
      _user = UserModel(
        id: _user!.id,
        name: _user!.name,
        email: _user!.email,
        phoneNumber: _user!.phoneNumber,
        isEmailVerified: true,
        biometricsEnabled: _user!.biometricsEnabled,
        profilePicture: _user!.profilePicture,
        fcmToken: _user!.fcmToken,
      );
      _isAuthenticated = true;
      notifyListeners();
    }

    return isVerified;
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    final result = await _authService.register(
      name: name,
      email: email,
      phoneNumber: phoneNumber,
      password: password,
    );

    if (result['success']) {
      _user = result['user'];
      // Don't set authenticated yet - wait for email verification
    }

    return result;
  }

  Future<Map<String, dynamic>> login({
    String? email,
    String? phoneNumber,
    required String password,
  }) async {
    final result = await _authService.login(
      email: email,
      phoneNumber: phoneNumber,
      password: password,
    );

    if (result['success']) {
      _user = result['user'];
      _isAuthenticated = true;
      await checkBiometricAvailability();
      notifyListeners();
    }

    return result;
  }

  Future<bool> loginWithBiometrics() async {
    final userId = await _authService.getBiometricUserId();
    if (userId == null) return false;

    final authenticated = await _biometricService.authenticate(
      reason: 'Authenticate to login',
    );

    if (authenticated) {
      final userData = await _authService.getUserById(userId);
      if (userData != null) {
        _user = userData;
        _isAuthenticated = true;
        notifyListeners();
        return true;
      }
    }

    return false;
  }

  Future<Map<String, dynamic>> resendVerificationEmail() async {
    if (_user == null) {
      return {
        'success': false,
        'message': 'No user logged in',
      };
    }

    return await _authService.resendVerificationEmail();
  }

  Future<bool> enableBiometrics() async {
    if (_user == null) return false;

    final canAuthenticate = await _biometricService.canCheckBiometrics();
    if (!canAuthenticate) return false;

    final authenticated = await _biometricService.authenticate(
      reason: 'Authenticate to enable biometric login',
    );

    if (authenticated) {
      final success = await _authService.enableBiometrics(_user!.id);

      if (success) {
        _user = _user!.copyWith(biometricsEnabled: true);
        notifyListeners();
        return true;
      }
    }

    return false;
  }

  Future<bool> disableBiometrics() async {
    if (_user == null) return false;

    // No need to authenticate to disable, or maybe yes for security?
    // Usually disabling is less critical than enabling, but let's just do it directly for UX
    final success = await _authService.disableBiometrics(_user!.id);

    if (success) {
      _user = _user!.copyWith(biometricsEnabled: false);
      notifyListeners();
      return true;
    }

    return false;
  }

  Future<void> logout() async {
    await _authService.logout();
    _isAuthenticated = false;
    _user = null;
    notifyListeners();
  }

  Future<bool> deleteAccount() async {
    final success = await _authService.deleteAccount();
    if (success) {
      _isAuthenticated = false;
      _user = null;
      notifyListeners();
    }
    return success;
  }
}
