import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/card_provider.dart';
import 'providers/document_provider.dart';
import 'providers/tag_provider.dart';
import 'providers/entity_provider.dart';
import 'providers/event_provider.dart';
import 'providers/procedure_provider.dart';
import 'providers/search_provider.dart';
import 'providers/analytical_field_provider.dart';
import 'providers/user_profile_provider.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

class PLocketApp extends StatelessWidget {
  const PLocketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProfileProvider()),
        ChangeNotifierProvider(create: (_) => DocumentProvider()),
        ChangeNotifierProvider(create: (_) => TagProvider()),
        ChangeNotifierProvider(create: (_) => EntityProvider()),
        ChangeNotifierProvider(create: (_) => EventProvider()),
        ChangeNotifierProvider(create: (_) => ProcedureProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => CardProvider()),
        ChangeNotifierProxyProvider<CardProvider, AnalyticalFieldProvider>(
          create: (_) => AnalyticalFieldProvider(),
          update: (_, cardProvider, analyticalProvider) {
            analyticalProvider!.setCardProvider(cardProvider);
            return analyticalProvider;
          },
        ),
      ],
      child: MaterialApp(
        title: 'pLOCKet',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const SplashScreen(),
      ),
    );
  }
}
