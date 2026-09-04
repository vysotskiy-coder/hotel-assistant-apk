import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../screens/login/login_screen.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  @override
  void initState() {
    super.initState();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    UpdateInfo? update;

    try {
      update = await UpdateService.instance.checkForUpdate();
    } catch (_) {
      update = null;
    }

    if (!mounted) return;

    if (update != null) {
      await showDialog(
        context: context,
        barrierDismissible: !update.forceUpdate,
        builder: (_) => UpdateDialog(
          info: update!,
          isOwner: false,
        ),
      );
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
