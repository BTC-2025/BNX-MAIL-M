/// Model representing a blocked contact / unsubscribed sender from the backend API.
class BlockedContact {
  final String email;
  final DateTime? blockedAt;

  const BlockedContact({
    required this.email,
    this.blockedAt,
  });

  factory BlockedContact.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    final rawDate = json['blockedAt']?.toString();
    if (rawDate != null && rawDate.isNotEmpty) {
      parsedDate = DateTime.tryParse(rawDate);
    }
    return BlockedContact(
      email: (json['email']?.toString() ?? '').trim(),
      blockedAt: parsedDate,
    );
  }

  Map<String, dynamic> toJson() => {
    'email': email,
    'blockedAt': blockedAt?.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlockedContact &&
          runtimeType == other.runtimeType &&
          email.toLowerCase() == other.email.toLowerCase();

  @override
  int get hashCode => email.toLowerCase().hashCode;
}
