import 'dart:async';
import 'dart:io';

/// Turns an arbitrary error into a short, user-facing message — never a raw
/// `toString()` with an `Exception:`/`StateError:` prefix. Validation errors that
/// carry their own message are surfaced as-is; technical failures collapse to a
/// friendly generic line so we don't leak internals to the user.
String friendlyError(Object error) {
  if (error is TimeoutException) {
    return 'This took too long. Check your connection and try again.';
  }
  if (error is SocketException || error is HttpException) {
    return 'Network problem. Check your connection and try again.';
  }
  if (error is FormatException) {
    return error.message.isEmpty ? 'That value isn\'t valid.' : error.message;
  }

  final raw = error.toString();
  // Strip the leading "Exception: " / "StateError: " etc. that Dart prepends.
  final stripped =
      raw.replaceFirst(RegExp(r'^[A-Za-z_]*(Exception|Error):\s*'), '');
  if (stripped.isEmpty || stripped == raw && raw.contains('instance of')) {
    return 'Something went wrong. Please try again.';
  }
  return stripped;
}
