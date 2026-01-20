import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/call_model.dart';

class CallProvider with ChangeNotifier {
  List<CallModel> _recentCalls = [];

  List<CallModel> get recentCalls => _recentCalls;

  CallProvider() {
    loadCalls();
  }

  Future<void> loadCalls() async {
    final prefs = await SharedPreferences.getInstance();
    final String? callsJson = prefs.getString('recent_calls');

    if (callsJson != null) {
      final List<dynamic> decodedList = json.decode(callsJson);
      _recentCalls =
          decodedList.map((item) => CallModel.fromJson(item)).toList();
      notifyListeners();
    }
  }

  Future<void> addCall(CallModel call) async {
    _recentCalls.insert(0, call);
    await _saveCalls();
    notifyListeners();
  }

  Future<void> updateCallStatus(String id,
      {bool? isScam, bool? isAi, bool? isSafe, bool? isBlocked}) async {
    final index = _recentCalls.indexWhere((c) => c.id == id);
    if (index != -1) {
      // If we are blocking, we might want to block all calls from this number?
      // For now keeping block specific to the call per previous implementation unless requested otherwise,
      // but Scam/AI flags usually apply to the identity.
      
       _recentCalls[index] = _recentCalls[index].copyWith(
        isScamDetected: isScam,
        isAiDetected: isAi,
        isSafe: isSafe,
        isBlocked: isBlocked,
      );
      await _saveCalls();
      notifyListeners();
    }
  }

  Future<void> flagNumber(String number, {bool? isScam, bool? isAi, bool? isSafe}) async {
    bool changed = false;
    for (var i = 0; i < _recentCalls.length; i++) {
      if (_recentCalls[i].contactNumber.replaceAll(' ', '') == number.replaceAll(' ', '')) {
        _recentCalls[i] = _recentCalls[i].copyWith(
          isScamDetected: isScam,
          isAiDetected: isAi,
          isSafe: isSafe,
        );
        changed = true;
      }
    }
    if (changed) {
      await _saveCalls();
      notifyListeners();
    }
  }


  Future<void> clearCalls() async {
    _recentCalls.clear();
    await _saveCalls();
    notifyListeners();
  }

  Future<void> _saveCalls() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedList =
        json.encode(_recentCalls.map((c) => c.toJson()).toList());
    await prefs.setString('recent_calls', encodedList);
  }
}
