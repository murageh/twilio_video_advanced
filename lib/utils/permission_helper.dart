import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  /// Request all required permissions for video calling
  static Future<PermissionResult> requestVideoCallPermissions() async {
    final permissions = [Permission.camera, Permission.microphone];

    final statuses = await permissions.request();

    return PermissionResult(
      camera: statuses[Permission.camera] ?? PermissionStatus.denied,
      microphone: statuses[Permission.microphone] ?? PermissionStatus.denied,
    );
  }

  /// Check current permission status
  static Future<PermissionResult> checkPermissions() async {
    return PermissionResult(
      camera: await Permission.camera.status,
      microphone: await Permission.microphone.status,
    );
  }

  /// Check if all required permissions are granted
  static Future<bool> hasAllPermissions() async {
    final result = await checkPermissions();
    return result.camera.isGranted && result.microphone.isGranted;
  }

  /// Request specific permission
  static Future<PermissionStatus> requestPermission(
    Permission permission,
  ) async {
    return await permission.request();
  }

  /// Open app settings if permissions are permanently denied
  static Future<bool> openAppSettings() async {
    return await openAppSettings();
  }

  /// Show permission rationale
  static String getPermissionRationale(Permission permission) {
    switch (permission) {
      case Permission.camera:
        return 'Camera access is required to share video during calls';
      case Permission.microphone:
        return 'Microphone access is required to share audio during calls';
      default:
        return 'This permission is required for the app to function properly';
    }
  }
}

class PermissionResult {
  final PermissionStatus camera;
  final PermissionStatus microphone;

  PermissionResult({required this.camera, required this.microphone});

  bool get allGranted => camera.isGranted && microphone.isGranted;

  bool get cameraGranted => camera.isGranted;

  bool get microphoneGranted => microphone.isGranted;

  bool get hasAnyDenied => camera.isDenied || microphone.isDenied;

  bool get hasAnyPermanentlyDenied =>
      camera.isPermanentlyDenied || microphone.isPermanentlyDenied;

  List<Permission> get deniedPermissions {
    final denied = <Permission>[];
    if (camera.isDenied) denied.add(Permission.camera);
    if (microphone.isDenied) denied.add(Permission.microphone);
    return denied;
  }

  List<Permission> get permanentlyDeniedPermissions {
    final denied = <Permission>[];
    if (camera.isPermanentlyDenied) denied.add(Permission.camera);
    if (microphone.isPermanentlyDenied) denied.add(Permission.microphone);
    return denied;
  }

  @override
  String toString() {
    return 'PermissionResult(camera: $camera, microphone: $microphone)';
  }
}
