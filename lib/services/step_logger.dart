import 'dart:developer' as developer;

class StepLogger {
  static void log(String stepLabel, bool success, int elapsedMs, {String? error}) {
    final icon = success ? '✓' : '✗';
    final status = success ? 'SUCCÈS' : 'ÉCHEC';
    final errorMsg = error != null ? ' | $error' : '';
    developer.log('[$icon] $stepLabel : $status [${elapsedMs}ms]$errorMsg');
  }
}
