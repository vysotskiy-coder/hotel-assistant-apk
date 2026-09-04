import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateService {
  UpdateService._();

  static final instance = UpdateService._();

  static const MethodChannel _installer =
      MethodChannel('hotel_assistant/apk_installer');

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<UpdateInfo?> checkForUpdate() async {
    if (kIsWeb || !Platform.isAndroid) return null;

    try {
      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;
      final doc = await _db.collection('system').doc('app_version').get();

      if (!doc.exists || doc.data() == null) return null;

      final data = doc.data()!;
      final remoteBuild = _readBuild(data['build']);
      final remoteVersion = data['version']?.toString().trim() ?? '';
      final apkUrl = data['apkUrl']?.toString().trim() ?? '';
      final releaseNotes = data['releaseNotes']?.toString().trim() ?? '';
      final forceUpdate = data['forceUpdate'] == true;

      if (remoteBuild == null || remoteBuild <= currentBuild || apkUrl.isEmpty) {
        return null;
      }

      return UpdateInfo(
        currentVersion: info.version,
        currentBuild: currentBuild,
        newVersion: remoteVersion.isEmpty ? 'Neue Version' : remoteVersion,
        newBuild: remoteBuild,
        apkUrl: apkUrl,
        releaseNotes: releaseNotes,
        forceUpdate: forceUpdate,
      );
    } catch (e, stackTrace) {
      debugPrint('UPDATE CHECK ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<void> openInstallPermissionSettings() async {
    if (!Platform.isAndroid) return;
    if (await _canInstallPackages()) return;
    await _installer.invokeMethod('openInstallPermissionSettings');
  }

  Future<bool> _canInstallPackages() async {
    try {
      return await _installer.invokeMethod<bool>('canRequestPackageInstalls') ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> downloadAndInstall(
    String apkUrl, {
    void Function(int received, int total)? onProgress,
  }) async {
    if (!Platform.isAndroid) {
      throw StateError('APK installation is supported on Android only.');
    }

    final uri = Uri.tryParse(apkUrl);
    if (uri == null || !uri.hasScheme ||
        !(uri.scheme == 'https' || uri.scheme == 'http')) {
      throw const FormatException('Invalid APK URL.');
    }

    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      request.followRedirects = true;
      request.maxRedirects = 5;
      final response = await request.close();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('APK download failed: HTTP ${response.statusCode}');
      }

      final dir = Directory.systemTemp;
      final file = File('${dir.path}/hotel_assistant_update.apk');
      if (await file.exists()) await file.delete();

      final sink = file.openWrite();
      var received = 0;
      final total = response.contentLength;
      await for (final chunk in response) {
        received += chunk.length;
        sink.add(chunk);
        onProgress?.call(received, total);
      }
      await sink.close();

      if (!await file.exists() || await file.length() == 0) {
        throw const FileSystemException('Downloaded APK is empty.');
      }

      final canInstall = await _canInstallPackages();
      if (!canInstall) {
        await _installer.invokeMethod('openInstallPermissionSettings');
        throw StateError('Allow installation from this source, then tap Update again.');
      }

      await _installer.invokeMethod('installApk', {'path': file.path});
    } finally {
      client.close(force: true);
    }
  }

  int? _readBuild(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

class UpdateInfo {
  final String currentVersion;
  final int currentBuild;
  final String newVersion;
  final int newBuild;
  final String apkUrl;
  final String releaseNotes;
  final bool forceUpdate;

  const UpdateInfo({
    required this.currentVersion,
    required this.currentBuild,
    required this.newVersion,
    required this.newBuild,
    required this.apkUrl,
    this.releaseNotes = '',
    this.forceUpdate = false,
  });
}
