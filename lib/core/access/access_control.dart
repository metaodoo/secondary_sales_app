/// Backend-driven access state for the logged-in user's mobile group.
///
/// Two flat sets come from the server (login `access` block / the
/// `/access/permissions` endpoint):
///  - [enforced]: resource keys that are currently gated (global switch).
///  - [granted]:  resource keys granted **directly** to the caller's own
///    `res.mobile.user.group` (UI grants are NOT inherited through implied groups).
///
/// The hybrid rule: a resource that is not yet enforced is visible to everyone,
/// so an empty [AccessControl] (the default before the backend ships grants)
/// allows everything and preserves today's behavior exactly.
class AccessControl {
  const AccessControl({
    this.enforced = const <String>{},
    this.granted = const <String>{},
  });

  final Set<String> enforced;
  final Set<String> granted;

  /// Whether the given screen/action [key] should be shown/enabled.
  bool allows(String key) => !enforced.contains(key) || granted.contains(key);

  factory AccessControl.fromMap(Map<String, dynamic> map) {
    Set<String> toSet(dynamic value) => value is List
        ? value.map((e) => e.toString()).toSet()
        : <String>{};
    return AccessControl(
      enforced: toSet(map['enforced']),
      granted: toSet(map['granted']),
    );
  }

  Map<String, dynamic> toMap() => {
    'enforced': enforced.toList(),
    'granted': granted.toList(),
  };
}
