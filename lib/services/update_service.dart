import 'package:flutter/foundation.dart';
import 'dart:js_interop';

@JS('checkForUpdate')
external bool _checkForUpdate();

@JS('applyUpdate')
external void _applyUpdate();

class UpdateService extends ChangeNotifier {
  bool _updateAvailable = false;
  bool get updateAvailable => _updateAvailable;

  UpdateService() {
    if (kIsWeb) {
      _initUpdateListener();
    }
  }

  void _initUpdateListener() {
    // Check immediately
    _checkUpdate();

    // Listen for custom event from service worker
    _listenForUpdateEvent();

    // Check periodically
    Future.delayed(const Duration(seconds: 5), _checkUpdate);
  }

  void _checkUpdate() {
    try {
      final available = _checkForUpdate();
      if (available && !_updateAvailable) {
        _updateAvailable = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[UpdateService] Error checking update: $e');
    }
  }

  void _listenForUpdateEvent() {
    // This would require dart:html which is deprecated
    // We'll rely on periodic checks instead
  }

  void applyUpdate() {
    try {
      _applyUpdate();
    } catch (e) {
      debugPrint('[UpdateService] Error applying update: $e');
      // Fallback: force reload
      if (kIsWeb) {
        // Use JavaScript to reload
        _reloadPage();
      }
    }
  }

  void _reloadPage() {
    // This will be called via JS interop
  }

  void dismiss() {
    _updateAvailable = false;
    notifyListeners();
  }
}
