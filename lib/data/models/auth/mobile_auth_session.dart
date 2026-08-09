import 'package:secondary_sales/core/util/parse.dart';
import 'package:secondary_sales/core/access/access_control.dart';

class MobileAuthSession {
  const MobileAuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.sessionId,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
    this.expiresAt,
    this.access = const AccessControl(),
  });

  final String accessToken;
  final String refreshToken;
  final String sessionId;
  final String tokenType;
  final int expiresIn;
  final MobileAuthUser user;
  final DateTime? expiresAt;

  /// Backend-driven screen/action access for this user's group. Empty (allow
  /// all) until the backend ships the `access` block in the login response.
  final AccessControl access;

  factory MobileAuthSession.fromMap(Map<String, dynamic> map) {
    final expiresIn = asIntOrNull(map['expires_in']) ?? 0;
    final userValue = map['user'];
    final accessValue = map['access'];
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
      access: accessValue is Map
          ? AccessControl.fromMap(accessValue.cast<String, dynamic>())
          : const AccessControl(),
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
    AccessControl? access,
  }) {
    return MobileAuthSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      sessionId: sessionId ?? this.sessionId,
      tokenType: tokenType ?? this.tokenType,
      expiresIn: expiresIn ?? this.expiresIn,
      user: user ?? this.user,
      expiresAt: expiresAt ?? this.expiresAt,
      access: access ?? this.access,
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
      'access': access.toMap(),
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
    this.permissions,
    this.employeeId,
    this.employeeName,
  });

  final int id;
  final String name;
  final String? role;
  final MobileAuthGroup? group;
  final MobileAuthPermissions? permissions;
  final int? employeeId;
  final String? employeeName;

  String? get groupCode => group?.code;

  factory MobileAuthUser.fromMap(Map<String, dynamic> map) {
    final groupValue = map['group'];
    final permsValue = map['permissions'];
    return MobileAuthUser(
      id: asIntOrNull(map['id']) ?? 0,
      name: (map['name'] ?? '').toString(),
      role: asNullableString(map['role']),
      group: groupValue is Map
          ? MobileAuthGroup.fromMap(groupValue.cast<String, dynamic>())
          : null,
      permissions: permsValue is Map
          ? MobileAuthPermissions.fromMap(permsValue.cast<String, dynamic>())
          : null,
      employeeId: asIntOrNull(map['employee_id']) ??
          (map['employee'] is Map ? asIntOrNull(map['employee']['id']) : null) ??
          asIntOrNull(map['employeeId']),
      employeeName: asNullableString(map['employee_name']) ??
          (map['employee'] is Map ? asNullableString(map['employee']['name']) : null) ??
          asNullableString(map['employeeName']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'group': group?.toMap(),
      'permissions': permissions?.toMap(),
      'employee_id': employeeId,
      'employee_name': employeeName,
    };
  }
}

class MobileAuthPermissions {
  const MobileAuthPermissions({
    this.canViewAllReturns = false,
    this.canEditSoQty = false,
    this.canEditWarehouseQty = false,
    this.canEditEffectiveQty = false,
    this.skipAttendanceGeolocation = false,
    this.canCreateOrderWithoutCheckin = false,
  });

  final bool canViewAllReturns;
  final bool canEditSoQty;
  final bool canEditWarehouseQty;
  final bool canEditEffectiveQty;
  final bool skipAttendanceGeolocation;
  final bool canCreateOrderWithoutCheckin;

  factory MobileAuthPermissions.fromMap(Map<String, dynamic> map) {
    return MobileAuthPermissions(
      canViewAllReturns: map['can_view_all_returns'] == true,
      canEditSoQty: map['can_edit_so_qty'] == true,
      canEditWarehouseQty: map['can_edit_warehouse_qty'] == true,
      canEditEffectiveQty: map['can_edit_effective_qty'] == true,
      skipAttendanceGeolocation: map['skip_attendance_geolocation'] == true,
      canCreateOrderWithoutCheckin: map['can_create_order_without_checkin'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'can_view_all_returns': canViewAllReturns,
      'can_edit_so_qty': canEditSoQty,
      'can_edit_warehouse_qty': canEditWarehouseQty,
      'can_edit_effective_qty': canEditEffectiveQty,
      'skip_attendance_geolocation': skipAttendanceGeolocation,
      'can_create_order_without_checkin': canCreateOrderWithoutCheckin,
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

