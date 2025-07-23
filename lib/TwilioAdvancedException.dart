/// Exception thrown by Twilio Video operations.
///
/// This exception is thrown when Twilio Video operations fail, providing
/// both an error code and a descriptive message to help identify the issue.
///
/// Common error codes include:
/// - `CONNECT_FAILED`: Failed to connect to the video room
/// - `PUBLISH_FAILED`: Failed to publish audio or video track
/// - `PERMISSIONS_DENIED`: Required permissions were not granted
/// - `CAMERA_PERMISSION_DENIED`: Camera permission specifically denied
/// - `MICROPHONE_PERMISSION_DENIED`: Microphone permission specifically denied
/// - `TORCH_UNAVAILABLE`: Flash/torch not available on current camera
/// - `SWITCH_FAILED`: Failed to switch cameras
///
/// ```dart
/// try {
///   await _twilio.connectToRoom(
///     roomName: 'my-room',
///     accessToken: 'invalid-token',
///   );
/// } catch (e) {
///   if (e is TwilioException) {
///     print('Twilio error: ${e.code} - ${e.message}');
///   }
/// }
/// ```
class TwilioException implements Exception {
  /// The error code identifying the type of error.
  ///
  /// This provides a programmatic way to handle different types of errors.
  final String code;

  /// A human-readable description of the error.
  ///
  /// This message provides more details about what went wrong and may
  /// include suggestions for resolving the issue.
  final String message;

  /// Creates a Twilio exception with the given [code] and [message].
  TwilioException(this.code, this.message);

  @override
  String toString() => 'TwilioException($code): $message';
}
