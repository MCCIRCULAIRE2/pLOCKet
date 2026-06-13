import 'package:flutter/material.dart';
import 'app.dart';
import 'services/supabase_service.dart';
import 'platform/device_info_stub.dart'
    if (dart.library.js_util) 'platform/device_info_web.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initDeviceInfoForWebImpl();
  await SupabaseService.initialize();
  runApp(const PLocketApp());
}
