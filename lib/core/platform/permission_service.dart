import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Cross-platform view of a permission request result.
enum AppPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  limited;

  bool get isGranted => this == AppPermissionStatus.granted;
}

/// Thin wrapper around `permission_handler`.
///
/// SMS is the only OS runtime permission the app needs. Notification-listener
/// access is a special Android setting, not a runtime permission, and is
/// handled by `NativeBridge` in the data layer.
///
/// `permission_handler` 11 removed the individual `readSms`/`receiveSms`
/// constants. Its Android implementation expands `Permission.sms` to only the
/// SMS permissions that are actually declared in the manifest, so requesting
/// the group is safe as long as `SEND_SMS` is *not* declared. The manifest in
/// this project deliberately declares `READ_SMS` + `RECEIVE_SMS` only.
class PermissionService {
  const PermissionService();

  /// Requests the SMS runtime permission group on Android.
  ///
  /// Returns [AppPermissionStatus.denied] on iOS, where SMS scraping is not
  /// possible and the permission is never surfaced to the user.
  Future<AppPermissionStatus> requestSms() async {
    if (!Platform.isAndroid) return AppPermissionStatus.denied;

    final current = await smsStatus();
    if (current.isGranted) return current;

    final status = await Permission.sms.request();
    return _fromStatus(status);
  }

  Future<AppPermissionStatus> smsStatus() async {
    if (!Platform.isAndroid) return AppPermissionStatus.denied;
    return _fromStatus(await Permission.sms.status);
  }

  /// Opens this app's OS settings page (used after a permanent denial).
  Future<bool> openSystemSettings() => openAppSettings();

  AppPermissionStatus _fromStatus(PermissionStatus status) {
    if (status.isGranted || status.isLimited) {
      return status.isLimited
          ? AppPermissionStatus.limited
          : AppPermissionStatus.granted;
    }
    if (status.isPermanentlyDenied) return AppPermissionStatus.permanentlyDenied;
    if (status.isRestricted) return AppPermissionStatus.restricted;
    return AppPermissionStatus.denied;
  }
}
