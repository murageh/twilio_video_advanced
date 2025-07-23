import 'package:permission_handler/permission_handler.dart';

/// A utility class for managing camera and microphone permissions required for video calling.
///
/// This helper provides convenient methods for requesting, checking, and managing
/// permissions needed by the Twilio Video Advanced plugin. It handles both
/// individual permission checks and bulk operations for video calling.
///
/// ```dart
/// // Check if all permissions are granted
/// final hasAll = await PermissionHelper.hasAllPermissions();
///
/// // Request all required permissions
/// final result = await PermissionHelper.requestVideoCallPermissions();
/// if (result.allGranted) {
///   // Safe to use video calling features
/// }
/// ```
class PermissionHelper {
  /// Requests all required permissions for video calling.
  ///
  /// This method requests both camera and microphone permissions simultaneously
  /// and returns a [PermissionResult] containing the status of each permission.
  ///
  /// **Returns:** A [PermissionResult] with the status of camera and microphone permissions.
  ///
  /// ```dart
  /// final result = await PermissionHelper.requestVideoCallPermissions();
  /// if (result.allGranted) {
  ///   print('All permissions granted');
  /// } else {
  ///   print('Denied permissions: ${result.deniedPermissions}');
  /// }
  /// ```
  static Future<PermissionResult> requestVideoCallPermissions() async {
    final permissions = [Permission.camera, Permission.microphone];

    final statuses = await permissions.request();

    return PermissionResult(
      camera: statuses[Permission.camera] ?? PermissionStatus.denied,
      microphone: statuses[Permission.microphone] ?? PermissionStatus.denied,
    );
  }

  /// Checks the current status of required permissions without requesting them.
  ///
  /// Use this method to determine the current state of permissions before
  /// deciding whether to request them or show rationale to the user.
  ///
  /// **Returns:** A [PermissionResult] with the current status of each permission.
  ///
  /// ```dart
  /// final result = await PermissionHelper.checkPermissions();
  /// if (!result.cameraGranted) {
  ///   // Show camera permission rationale
  /// }
  /// ```
  static Future<PermissionResult> checkPermissions() async {
    return PermissionResult(
      camera: await Permission.camera.status,
      microphone: await Permission.microphone.status,
    );
  }

  /// Checks if all required permissions are currently granted.
  ///
  /// This is a convenience method that returns `true` only if both
  /// camera and microphone permissions are granted.
  ///
  /// **Returns:** `true` if all permissions are granted, `false` otherwise.
  ///
  /// ```dart
  /// if (await PermissionHelper.hasAllPermissions()) {
  ///   // Safe to start video calling
  ///   await twilio.connectToRoom(roomName: 'room', accessToken: 'token');
  /// }
  /// ```
  static Future<bool> hasAllPermissions() async {
    final result = await checkPermissions();
    return result.camera.isGranted && result.microphone.isGranted;
  }

  /// Requests a specific permission.
  ///
  /// This method allows requesting individual permissions when you need
  /// fine-grained control over the permission flow.
  ///
  /// **Parameters:**
  /// - [permission]: The specific permission to request
  ///
  /// **Returns:** The [PermissionStatus] after the request.
  ///
  /// ```dart
  /// final status = await PermissionHelper.requestPermission(Permission.camera);
  /// if (status.isGranted) {
  ///   // Camera permission granted
  /// }
  /// ```
  static Future<PermissionStatus> requestPermission(
    Permission permission,
  ) async {
    return await permission.request();
  }

  /// Opens the app settings page where users can manually grant permissions.
  ///
  /// This is useful when permissions have been permanently denied and
  /// can only be granted through the system settings.
  ///
  /// **Returns:** `true` if settings were opened successfully, `false` otherwise.
  ///
  /// ```dart
  /// if (result.anyPermanentlyDenied) {
  ///   final opened = await PermissionHelper.openAppSettings();
  ///   if (opened) {
  ///     // Settings opened, user can grant permissions there
  ///   }
  /// }
  /// ```
  static Future<bool> openAppSettings() async {
    return await openAppSettings();
  }

  /// Gets a user-friendly explanation for why a specific permission is needed.
  ///
  /// This method returns appropriate rationale text that can be shown to users
  /// to help them understand why the permission is required.
  ///
  /// **Parameters:**
  /// - [permission]: The permission to get rationale for
  ///
  /// **Returns:** A user-friendly explanation string.
  ///
  /// ```dart
  /// final rationale = PermissionHelper.getPermissionRationale(Permission.camera);
  /// showDialog(
  ///   context: context,
  ///   builder: (context) => AlertDialog(
  ///     title: Text('Permission Required'),
  ///     content: Text(rationale),
  ///   ),
  /// );
  /// ```
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

/// Contains the result of permission requests for video calling.
///
/// This class provides convenient access to the status of camera and microphone
/// permissions, along with helper methods to check common permission states.
///
/// ```dart
/// final result = await PermissionHelper.requestVideoCallPermissions();
/// print('Camera granted: ${result.cameraGranted}');
/// print('All granted: ${result.allGranted}');
/// ```
class PermissionResult {
  /// The status of the camera permission.
  final PermissionStatus camera;

  /// The status of the microphone permission.
  final PermissionStatus microphone;

  /// Creates a permission result.
  const PermissionResult({
    required this.camera,
    required this.microphone,
  });

  /// Whether the camera permission is granted.
  bool get cameraGranted => camera.isGranted;

  /// Whether the microphone permission is granted.
  bool get microphoneGranted => microphone.isGranted;

  /// Whether all required permissions are granted.
  bool get allGranted => cameraGranted && microphoneGranted;

  /// Whether any permissions are permanently denied.
  ///
  /// When `true`, permissions can only be granted through system settings.
  bool get anyPermanentlyDenied =>
      camera.isPermanentlyDenied || microphone.isPermanentlyDenied;

  /// List of permissions that were denied.
  ///
  /// This includes both temporarily and permanently denied permissions.
  List<Permission> get deniedPermissions {
    final denied = <Permission>[];
    if (!cameraGranted) denied.add(Permission.camera);
    if (!microphoneGranted) denied.add(Permission.microphone);
    return denied;
  }

  /// List of permissions that were permanently denied.
  ///
  /// These permissions require the user to manually grant them in system settings.
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
