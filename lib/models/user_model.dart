class UserModel {
  final String name;
  final String email;
  final String? avatarUrl;
  final String? firstName;
  final String? lastName;
  final String? username;
  final String? jobTitle;
  final String? location;
  final String? phone;
  final String? recoveryEmail;
  final String? backupPhone;

  const UserModel({
    required this.name,
    required this.email,
    this.avatarUrl,
    this.firstName,
    this.lastName,
    this.username,
    this.jobTitle,
    this.location,
    this.phone,
    this.recoveryEmail,
    this.backupPhone,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final firstName = json['firstName']?.toString() ?? '';
    final lastName = json['lastName']?.toString() ?? '';
    final fullName =
        json['name']?.toString() ??
        json['fullName']?.toString() ??
        [firstName, lastName].where((s) => s.isNotEmpty).join(' ');

    final email =
        json['email']?.toString() ?? json['emailAddress']?.toString() ?? '';

    return UserModel(
      name: fullName.isNotEmpty
          ? fullName
          : (json['username']?.toString() ?? email),
      email: email,
      avatarUrl: (json['avatarUrl']?.toString() ?? json['avatar']?.toString()) ??
          (email.isNotEmpty ? '/api/users/profile-picture/$email' : null),
      firstName: firstName.isNotEmpty ? firstName : null,
      lastName: lastName.isNotEmpty ? lastName : null,
      username: json['username']?.toString(),
      jobTitle: json['jobTitle']?.toString() ?? json['designation']?.toString() ?? json['title']?.toString(),
      location: json['location']?.toString() ?? json['city']?.toString(),
      phone: json['phone']?.toString() ?? json['phoneNumber']?.toString() ?? json['contact']?.toString(),
      recoveryEmail: json['recoveryEmail']?.toString() ?? json['backupEmail']?.toString(),
      backupPhone: json['backupPhone']?.toString() ?? json['recoveryPhone']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
    if (firstName != null) 'firstName': firstName,
    if (lastName != null) 'lastName': lastName,
    if (username != null) 'username': username,
    if (jobTitle != null) 'jobTitle': jobTitle,
    if (location != null) 'location': location,
    if (phone != null) 'phone': phone,
    if (recoveryEmail != null) 'recoveryEmail': recoveryEmail,
    if (backupPhone != null) 'backupPhone': backupPhone,
  };

  UserModel copyWith({
    String? name,
    String? email,
    String? avatarUrl,
    String? firstName,
    String? lastName,
    String? username,
    String? jobTitle,
    String? location,
    String? phone,
    String? recoveryEmail,
    String? backupPhone,
  }) {
    return UserModel(
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      username: username ?? this.username,
      jobTitle: jobTitle ?? this.jobTitle,
      location: location ?? this.location,
      phone: phone ?? this.phone,
      recoveryEmail: recoveryEmail ?? this.recoveryEmail,
      backupPhone: backupPhone ?? this.backupPhone,
    );
  }
}
