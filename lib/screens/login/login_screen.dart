import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../database/database_helper.dart';
import '../../services/notification_service.dart';
import '../../services/update_service.dart';
import '../../widgets/update_dialog.dart';
import '../dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const ownerEmail = 't.ru.mp.e.ra.pe.rsc.m8.37@gmail.com';
  static const hausmasterEmail = 'po.pu.l.o.usv.mbx.m.k@gmail.com';

  bool busy = false;
  String _version = '';
  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();

    if (!mounted) return;

    setState(() {
      _version = 'Version ${info.version} (Build ${info.buildNumber})';
    });
  }

  Future<void> login(bool owner) async {
    final password = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(owner ? 'Hotelbesitzer anmelden' : 'Вход хаусмастера'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              owner ? ownerEmail : hausmasterEmail,
              style: Theme.of(c).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: password,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                labelText: owner ? 'Passwort' : 'Пароль',
              ),
              onSubmitted: (_) => Navigator.pop(c, true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(owner ? 'Abbrechen' : 'Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(owner ? 'Anmelden' : 'Войти'),
          ),
        ],
      ),
    );

    if (ok != true || password.text.isEmpty) {
      password.dispose();
      return;
    }

    setState(() => busy = true);

    try {
      await FirebaseAuth.instance.signOut();

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: owner ? ownerEmail : hausmasterEmail,
        password: password.text,
      );

      await DatabaseHelper.instance.initializeRooms();

      await NotificationService.instance.registerCurrentUser(isOwner: owner);

      if (!mounted) return;

      // Check for an available APK update after successful authentication.
      // The dashboard remains usable if the check fails.
      final update = await UpdateService.instance.checkForUpdate();

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DashboardScreen(isOwner: owner)),
      );

      if (update != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          showDialog(
            context: context,
            barrierDismissible: !update.forceUpdate,
            builder: (_) => UpdateDialog(info: update, isOwner: owner),
          );
        });
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      final msg = e.code == 'invalid-credential' || e.code == 'wrong-password'
          ? (owner ? 'Falsches Passwort.' : 'Неверный пароль.')
          : (owner
                ? 'Anmeldung fehlgeschlagen: ${e.code}'
                : 'Ошибка входа: ${e.code}');

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              owner ? 'Firebase-Fehler: $e' : 'Ошибка Firebase: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
      password.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  Icon(
                    Icons.hotel_rounded,
                    size: 84,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Hotel Assistant',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Text(
                    _version,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 38),
                  _card(
                    true,
                    Icons.admin_panel_settings,
                    'Hotelbesitzer',
                    'Deutsch',
                  ),
                  const SizedBox(height: 14),
                  _card(false, Icons.engineering, 'Hausmeister', 'Русский'),
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(bool owner, IconData icon, String title, String sub) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(icon, size: 46, color: owner ? Colors.blue : Colors.green),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(sub),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy ? null : () => login(owner),
                child: Text(owner ? 'Anmelden' : 'Войти'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
