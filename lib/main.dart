import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config/app_config.dart';
import 'core/services/push_navigation_controller.dart';
import 'core/services/push_notification_service.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/broadcast/providers/broadcast_provider.dart';
import 'features/committee/providers/committee_provider.dart';
import 'features/contact_us/providers/contact_us_provider.dart';
import 'features/history_scan/providers/history_scan_provider.dart';
import 'features/home/providers/home_provider.dart';
import 'features/izan/providers/izan_provider.dart';
import 'features/scan/providers/scan_provider.dart';
import 'features/shell/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Match FMB: never block first frame on Firebase/FCM.
  unawaited(PushNotificationService.instance.initialize());
  runApp(const TmkApp());
}

class TmkApp extends StatelessWidget {
  const TmkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()..bootstrap()),
        ChangeNotifierProvider(create: (_) => AuthProvider()..bootstrap()),
        ChangeNotifierProvider.value(value: PushNavigationController.instance),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => BroadcastProvider()),
        ChangeNotifierProvider(create: (_) => IzanProvider()),
        ChangeNotifierProvider(create: (_) => HistoryScanProvider()),
        ChangeNotifierProvider(create: (_) => CommitteeProvider()),
        ChangeNotifierProvider(create: (_) => ContactUsProvider()),
        ChangeNotifierProvider(create: (_) => ScanProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          return MaterialApp(
            title: AppConfig.appName,
            debugShowCheckedModeBanner: false,
            theme: theme.themeData,
            home: const _RootGate(),
          );
        },
      ),
    );
  }
}

class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  String? _syncedItsId;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isBootstrapping) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (auth.isAuthenticated) {
      final its = auth.itsId?.trim() ?? '';
      if (its.isNotEmpty && !auth.isDesignPreview && its != _syncedItsId) {
        _syncedItsId = its;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(PushNotificationService.instance.syncToken(itsId: its));
        });
      }
      return const AppShell();
    }

    _syncedItsId = null;
    return const LoginScreen();
  }
}
