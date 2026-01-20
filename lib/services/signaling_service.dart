import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class SignalingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userId;
  StreamSubscription? _callListener;
  StreamSubscription? _offerListener;
  StreamSubscription? _answerListener;
  StreamSubscription? _iceCandidateListener;
  StreamSubscription? _callEndedAsTargetListener;
  StreamSubscription? _callEndedAsCallerListener;

  final StreamController<Map<String, dynamic>> _offerController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _answerController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _iceCandidateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _incomingCallController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<bool> _callEndedController =
      StreamController<bool>.broadcast();

  Stream<Map<String, dynamic>> get offerStream => _offerController.stream;
  Stream<Map<String, dynamic>> get answerStream => _answerController.stream;
  Stream<Map<String, dynamic>> get iceCandidateStream =>
      _iceCandidateController.stream;
  Stream<Map<String, dynamic>> get incomingCallStream =>
      _incomingCallController.stream;
  Stream<bool> get callEndedStream => _callEndedController.stream;

  Future<void> connect(String userId) async {
    _userId = userId;

    // Listen for incoming calls by userId
    _callListener = _firestore
        .collection('calls')
        .where('targetUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'calling')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data()!;
          _incomingCallController.add({
            'callId': change.doc.id,
            'fromUserId': data['fromUserId'],
            'fromPhoneNumber': data['fromPhoneNumber'],
            'callerName': data['callerName'],
          });
        }
      }
    });

    // Listen for ended calls where current user is the callee
    _callEndedAsTargetListener = _firestore
        .collection('calls')
        .where('targetUserId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data == null) continue;

        if (data['status'] == 'ended' &&
            change.type == DocumentChangeType.modified) {
          _callEndedController.add(true);
        }
      }
    });

    // Listen for ended calls where current user is the caller
    _callEndedAsCallerListener = _firestore
        .collection('calls')
        .where('fromUserId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data == null) continue;

        if (data['status'] == 'ended' &&
            change.type == DocumentChangeType.modified) {
          _callEndedController.add(true);
        }
      }
    });

    // Listen for offers
    // FIXME: I think that the problem is here, the description is never set, and it should be set before adding ICE candidates
    _offerListener = _firestore
        .collection('signaling')
        .where('targetUserId', isEqualTo: userId)
        .where('type', isEqualTo: 'offer')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data()!;
          _offerController.add({
            'fromUserId': data['fromUserId'],
            'offer': data['offer'],
          });

          // Delete after reading
          change.doc.reference.delete();
        }
      }
    });

    // Listen for answers
    _answerListener = _firestore
        .collection('signaling')
        .where('targetUserId', isEqualTo: userId)
        .where('type', isEqualTo: 'answer')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data()!;
          _answerController.add({
            'fromUserId': data['fromUserId'],
            'answer': data['answer'],
          });

          // Delete after reading
          change.doc.reference.delete();
        }
      }
    });

    // Listen for ICE candidates
    _iceCandidateListener = _firestore
        .collection('signaling')
        .where('targetUserId', isEqualTo: userId)
        .where('type', isEqualTo: 'ice-candidate')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data()!;
          _iceCandidateController.add({
            'fromUserId': data['fromUserId'],
            'candidate': data['candidate'],
          });

          // Delete after reading
          change.doc.reference.delete();
        }
      }
    });
  }

  // Find user by phone number
  Future<String?> getUserIdByPhoneNumber(String phoneNumber) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('phoneNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.id;
      }
      return null;
    } catch (e) {
      print('Error finding user by phone: $e');
      return null;
    }
  }

  Future<void> sendOffer(
      String targetUserId, Map<String, dynamic> offer) async {
    await _firestore.collection('signaling').add({
      'type': 'offer',
      'fromUserId': _userId,
      'targetUserId': targetUserId,
      'offer': offer,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendAnswer(
      String targetUserId, Map<String, dynamic> answer) async {
    await _firestore.collection('signaling').add({
      'type': 'answer',
      'fromUserId': _userId,
      'targetUserId': targetUserId,
      'answer': answer,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendIceCandidate(
      String targetUserId, Map<String, dynamic> candidate) async {
    await _firestore.collection('signaling').add({
      'type': 'ice-candidate',
      'fromUserId': _userId,
      'targetUserId': targetUserId,
      'candidate': candidate,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>?> initiateCall(
      String targetPhoneNumber, String callerName) async {
    // Find target user by phone number
    final targetUserId = await getUserIdByPhoneNumber(targetPhoneNumber);

    if (targetUserId == null) {
      print('User not found with phone number: $targetPhoneNumber');
      return null;
    }

    // Get caller info
    final callerDoc = await _firestore.collection('users').doc(_userId).get();
    final callerPhone = callerDoc.data()?['phoneNumber'];

    final callDoc = await _firestore.collection('calls').add({
      'fromUserId': _userId,
      'fromPhoneNumber': callerPhone,
      'targetUserId': targetUserId,
      'targetPhoneNumber': targetPhoneNumber,
      'callerName': callerName,
      'status': 'calling',
      'timestamp': FieldValue.serverTimestamp(),
    });

    return {
      'callId': callDoc.id,
      'targetUserId': targetUserId,
    };
  }

  Future<void> acceptCall(String callId) async {
    await _firestore.collection('calls').doc(callId).update({
      'status': 'active',
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> endCall(String? callId, String? targetUserId) async {
    if (callId != null) {
      await _firestore.collection('calls').doc(callId).update({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
      });
    }

    _callEndedController.add(true);
  }

  void dispose() {
    _callListener?.cancel();
    _offerListener?.cancel();
    _answerListener?.cancel();
    _iceCandidateListener?.cancel();
    _callEndedAsTargetListener?.cancel();
    _callEndedAsCallerListener?.cancel();
    _offerController.close();
    _answerController.close();
    _iceCandidateController.close();
    _incomingCallController.close();
    _callEndedController.close();
  }
}
