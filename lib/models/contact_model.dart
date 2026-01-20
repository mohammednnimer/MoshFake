class ContactModel {
  final String id;
  final String name;
  final String phoneNumber;
  final String? avatarUrl;
  final String? imagePath;
  final int avatarColor;
  final bool isScam;
  final bool isAi;

  ContactModel({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.avatarUrl,
    this.imagePath,
    required this.avatarColor,
    this.isScam = false,
    this.isAi = false,
  });

  String get initials {
    if (name.isEmpty) return '?';
    final names = name.split(' ');
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    }
    return name.substring(0, 1).toUpperCase();
  }

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['id'],
      name: json['name'],
      phoneNumber: json['phoneNumber'],
      avatarUrl: json['avatarUrl'],
      imagePath: json['imagePath'],
      avatarColor: json['avatarColor'] ?? 0xFF2196F3,
      isScam: json['isScam'] ?? false,
      isAi: json['isAi'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'avatarUrl': avatarUrl,
      'imagePath': imagePath,
      'avatarColor': avatarColor,
      'isScam': isScam,
      'isAi': isAi,
    };
  }

  ContactModel copyWith({
    String? name,
    String? phoneNumber,
    String? imagePath,
    bool? isScam,
    bool? isAi,
  }) {
    return ContactModel(
      id: id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      avatarUrl: avatarUrl,
      imagePath: imagePath ?? this.imagePath,
      avatarColor: avatarColor,
      isScam: isScam ?? this.isScam,
      isAi: isAi ?? this.isAi,
    );
  }
}
