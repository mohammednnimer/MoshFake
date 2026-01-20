import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

enum TypeOfBiometric {
  none,
  fingerprint,
  face,
  both,
}

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  Future<TypeOfBiometric> getAvailableBiometrics() async {
    try {
      final List<BiometricType> availableBiometrics =
          await _auth.getAvailableBiometrics();
      
      print('Available Biometrics Raw: $availableBiometrics');

      bool hasFingerprint =
          availableBiometrics.contains(BiometricType.fingerprint) || 
          availableBiometrics.contains(BiometricType.strong);
          
      bool hasFace = availableBiometrics.contains(BiometricType.face) || 
                     availableBiometrics.contains(BiometricType.weak);

      if (hasFingerprint && hasFace) {
        return TypeOfBiometric.both;
      } else if (hasFingerprint) {
        return TypeOfBiometric.fingerprint;
      } else if (hasFace) {
        return TypeOfBiometric.face;
      }
      
      // Fallback: If list is not empty but we didn't match above (e.g. only iris?)
      if (availableBiometrics.isNotEmpty) {
        return TypeOfBiometric.fingerprint; // Default to fingerprint icon for generic
      }

      return TypeOfBiometric.none;
    } on PlatformException catch (e) {
      print('Error getting biometrics: $e');
      return TypeOfBiometric.none;
    }
  }

  Future<bool> authenticate(
      {String reason = 'Please authenticate to continue'}) async {
    try {
      bool canAuthenticate =
          await canCheckBiometrics() || await isDeviceSupported();

      if (!canAuthenticate) {
        return false;
      }

      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException catch (e) {
      print('Biometric authentication error: $e');
      return false;
    }
  }

  String getBiometricTypeLabel(TypeOfBiometric type) {
    switch (type) {
      case TypeOfBiometric.fingerprint:
        return 'Fingerprint';
      case TypeOfBiometric.face:
        return 'Face ID';
      case TypeOfBiometric.both:
        return 'Fingerprint & Face ID';
      case TypeOfBiometric.none:
        return 'Not Available';
    }
  }
}
