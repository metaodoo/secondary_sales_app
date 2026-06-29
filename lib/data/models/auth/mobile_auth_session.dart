import 'package:secondary_sales/core/util/parse.dart';
class MobileAuthSession {
  const MobileAuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.sessionId,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
    this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final String sessionId;
  final String tokenType;
  final int expiresIn;
  final MobileAuthUser user;
  final DateTime? expiresAt;

  factory MobileAuthSession.fromMap(Map<String, dynamic> map) {
    final expiresIn = asIntOrNull(map['expires_in']) ?? 0;
    final userValue = map['user'];
    return MobileAuthSession(
      accessToken: (map['access_token'] ?? '').toString(),
      refreshToken: (map['refresh_token'] ?? '').toString(),
      sessionId: (map['session_id'] ?? '').toString(),
      tokenType: (map['token_type'] ?? 'Bearer').toString(),
      expiresIn: expiresIn,
      user: MobileAuthUser.fromMap(
        userValue is Map
            ? userValue.cast<String, dynamic>()
            : <String, dynamic>{},
      ),
      expiresAt:
          asDateTime(map['expires_at']) ??
          DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }

  MobileAuthSession copyWith({
    String? accessToken,
    String? refreshToken,
    String? sessionId,
    String? tokenType,
    int? expiresIn,
    MobileAuthUser? user,
    DateTime? expiresAt,
  }) {
    return MobileAuthSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      sessionId: sessionId ?? this.sessionId,
      tokenType: tokenType ?? this.tokenType,
      expiresIn: expiresIn ?? this.expiresIn,
      user: user ?? this.user,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'session_id': sessionId,
      'token_type': tokenType,
      'expires_in': expiresIn,
      'expires_at': expiresAt?.toIso8601String(),
      'user': user.toMap(),
    };
  }
}

class MobileAuthTokens {
  const MobileAuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;

  factory MobileAuthTokens.fromMap(Map<String, dynamic> map) {
    return MobileAuthTokens(
      accessToken: (map['access_token'] ?? '').toString(),
      refreshToken: (map['refresh_token'] ?? '').toString(),
      tokenType: (map['token_type'] ?? 'Bearer').toString(),
      expiresIn: asIntOrNull(map['expires_in']) ?? 0,
    );
  }
}

class MobileAuthUser {
  const MobileAuthUser({
    required this.id,
    required this.name,
    this.role,
    this.group,
    this.employeeId,
    this.employeeName,
  });

  final int id;
  final String name;
  final String? role;
  final MobileAuthGroup? group;
  final int? employeeId;
  final String? employeeName;

  String? get groupCode => group?.code;

  factory MobileAuthUser.fromMap(Map<String, dynamic> map) {
    final groupValue = map['group'];
    return MobileAuthUser(
      id: asIntOrNull(map['id']) ?? 0,
      name: (map['name'] ?? '').toString(),
      role: asNullableString(map['role']),
      group: groupValue is Map
          ? MobileAuthGroup.fromMap(groupValue.cast<String, dynamic>())
          : null,
      employeeId: asIntOrNull(map['employee_id']),
      employeeName: asNullableString(map['employee_name']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'group': group?.toMap(),
      'employee_id': employeeId,
      'employee_name': employeeName,
    };
  }
}

class MobileAuthGroup {
  const MobileAuthGroup({
    required this.id,
    required this.code,
    required this.name,
  });

  final int id;
  final String code;
  final String name;

  factory MobileAuthGroup.fromMap(Map<String, dynamic> map) {
    return MobileAuthGroup(
      id: asIntOrNull(map['id']) ?? 0,
      code: (map['code'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'code': code, 'name': name};
  }
}

