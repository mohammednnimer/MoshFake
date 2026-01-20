enum CallType { incoming, outgoing, missed }

class CallModel {
  final String id;
  final String contactName;
  final String contactNumber;
  final CallType callType;
  final Duration duration;
  final DateTime timestamp;
  final bool isScamDetected;
  final bool isAiDetected;
  final bool isBlocked;
  final bool isSafe;

  CallModel({
    required this.id,
    required this.contactName,
    required this.contactNumber,
    required this.callType,
    required this.duration,
    required this.timestamp,
    this.isScamDetected = false,
    this.isAiDetected = false,
    this.isBlocked = false,
    this.isSafe = false,
  });

  String get formattedDuration {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  factory CallModel.fromJson(Map<String, dynamic> json) {
    return CallModel(
      id: json['id'],
      contactName: json['contactName'],
      contactNumber: json['contactNumber'],
      callType: CallType.values[json['callType']],
      duration: Duration(seconds: json['durationSeconds']),
      timestamp: DateTime.parse(json['timestamp']),
      isScamDetected: json['isScamDetected'] ?? false,
      isAiDetected: json['isAiDetected'] ?? false,
      isBlocked: json['isBlocked'] ?? false,
      isSafe: json['isSafe'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contactName': contactName,
      'contactNumber': contactNumber,
      'callType': callType.index,
      'durationSeconds': duration.inSeconds,
      'timestamp': timestamp.toIso8601String(),
      'isScamDetected': isScamDetected,
      'isAiDetected': isAiDetected,
      'isBlocked': isBlocked,
      'isSafe': isSafe,
    };
  }

  CallModel copyWith({
    bool? isScamDetected,
    bool? isAiDetected,
    bool? isBlocked,
    bool? isSafe,
  }) {
    return CallModel(
      id: id,
      contactName: contactName,
      contactNumber: contactNumber,
      callType: callType,
      duration: duration,
      timestamp: timestamp,
      isScamDetected: isScamDetected ?? this.isScamDetected,
      isAiDetected: isAiDetected ?? this.isAiDetected,
      isBlocked: isBlocked ?? this.isBlocked,
      isSafe: isSafe ?? this.isSafe,
    );
  }
}
