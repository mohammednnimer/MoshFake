class UserModel {
  final String id;
  final String name;
  final String email;
  final String phoneNumber;
  final bool isEmailVerified;
  final bool biometricsEnabled;
  final String? profilePicture;
  final String? fcmToken;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phoneNumber,
    this.isEmailVerified = false,
    this.biometricsEnabled = false,
    this.profilePicture,
    this.fcmToken,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? json['uid'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      isEmailVerified: json['isEmailVerified'] ?? false,
      biometricsEnabled: json['biometricsEnabled'] ?? false,
      profilePicture: json['profilePicture'],
      fcmToken: json['fcmToken'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'isEmailVerified': isEmailVerified,
      'biometricsEnabled': biometricsEnabled,
      'profilePicture': profilePicture,
      'fcmToken': fcmToken,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phoneNumber,
    bool? isEmailVerified,
    bool? biometricsEnabled,
    String? profilePicture,
    String? fcmToken,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
      profilePicture: profilePicture ?? this.profilePicture,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }
}
