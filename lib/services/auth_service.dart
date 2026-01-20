import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    try {
      // Check if phone number already exists
      final phoneQuery = await _firestore
          .collection('users')
          .where('phoneNumber', isEqualTo: phoneNumber)
          .get();

      if (phoneQuery.docs.isNotEmpty) {
        return {
          'success': false,
          'message': 'Phone number already registered',
        };
      }

      // Create user with email and password
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Send email verification
      await userCredential.user?.sendEmailVerification();

      // Create user document in Firestore
      final userData = {
        'name': name,
        'email': email,
        'phoneNumber': phoneNumber,
        'isEmailVerified': false,
        'biometricsEnabled': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .set(userData);

      return {
        'success': true,
        'message': 'Registration successful! Please verify your email.',
        'user': UserModel.fromJson({
          ...userData,
          'id': userCredential.user!.uid,
        }),
      };
    } on FirebaseAuthException catch (e) {
      String message = 'Registration failed';
      if (e.code == 'weak-password') {
        message = 'Password is too weak';
      } else if (e.code == 'email-already-in-use') {
        message = 'Email already registered';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address';
      }
      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  Future<bool> isEmailVerified(String email) async {
    try {
      final user = _auth.currentUser;
      await user?.reload();
      return user?.emailVerified ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> login({
    String? email,
    String? phoneNumber,
    required String password,
  }) async {
    try {
      String loginEmail = email ?? '';

      // If phone number provided, find the email associated with it
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        final phoneQuery = await _firestore
            .collection('users')
            .where('phoneNumber', isEqualTo: phoneNumber)
            .limit(1)
            .get();

        if (phoneQuery.docs.isEmpty) {
          return {
            'success': false,
            'message': 'Phone number not found',
          };
        }

        loginEmail = phoneQuery.docs.first.data()['email'];
      }

      // Sign in with email and password
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: loginEmail,
        password: password,
      );

      // Check if email is verified
      if (!userCredential.user!.emailVerified) {
        await _auth.signOut();
        return {
          'success': false,
          'message': 'Please verify your email before logging in',
          'emailVerificationRequired': true,
        };
      }

      // Get user data from Firestore
      final userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      final userData = userDoc.data()!;
      userData['id'] = userCredential.user!.uid;
      userData['isEmailVerified'] = userCredential.user!.emailVerified;

      // Update last login
      await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .update({
        'lastLogin': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'user': UserModel.fromJson(userData),
      };
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed';
      if (e.code == 'user-not-found') {
        message = 'No user found with this email';
      } else if (e.code == 'wrong-password') {
        message = 'Incorrect password';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address';
      }
      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      print('Login error: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> resendVerificationEmail() async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        return {
          'success': false,
          'message': 'No user is currently signed in',
        };
      }

      if (user.emailVerified) {
        return {
          'success': false,
          'message': 'Email is already verified',
        };
      }

      await user.sendEmailVerification();

      return {
        'success': true,
        'message': 'Verification email sent',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  Future<bool> enableBiometrics(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'biometricsEnabled': true,
      });

      // Store userId for biometric login
      await _storage.write(key: 'biometric_user_id', value: userId);

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> disableBiometrics(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'biometricsEnabled': false,
      });

      // Remove userId from biometric login storage
      await _storage.delete(key: 'biometric_user_id');

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String?> getBiometricUserId() async {
    return await _storage.read(key: 'biometric_user_id');
  }

  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = userId;
        return UserModel.fromJson(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> updateFCMToken(String userId, String token) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
      });
    } catch (e) {
      print('Error updating FCM token: $e');
    }
  }

  Future<bool> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Delete Firestore document
        await _firestore.collection('users').doc(user.uid).delete();
        // Delete user (requires recent login, otherwise needs re-auth)
        await user.delete();
        return true;
      }
      return false;
    } catch (e) {
      print("Delete Account Error: $e");
      return false;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;
}
