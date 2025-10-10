
class TwainUser {
  final String id;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final String? pairId;
  final String? fcmToken;
  final String? deviceId;
  final String? status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? preferences;
  final Map<String, dynamic>? metaData;

  TwainUser(
      {required this.id,
      required this.email,
      required this.displayName,
      this.avatarUrl,
      this.pairId,
      this.fcmToken,
      this.deviceId,
      this.status,
      required this.createdAt,
      required this.updatedAt,
      this.preferences,
      this.metaData}
      );


}