class TwilioException implements Exception {
  final String code;
  final String message;

  TwilioException(this.code, this.message);

  @override
  String toString() => 'TwilioException($code): $message';
}
