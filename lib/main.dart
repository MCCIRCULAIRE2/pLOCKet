import 'package:flutter/material.dart';
import 'app.dart';
import 'services/supabase_service.dart';
import 'platform/device_info_stub.dart'
    if (dart.library.js_util) 'platform/device_info_web.dart';

const bool _useCloud = bool.fromEnvironment('USE_CLOUD', defaultValue: false);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initDeviceInfoForWebImpl();
  if (_useCloud) {
    await SupabaseService.initialize();
  }
  runApp(const PLocketApp());
}
