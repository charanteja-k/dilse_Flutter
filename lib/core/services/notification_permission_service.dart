import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../extensions/context_extensions.dart';
import '../widgets/dilse_notification.dart';

/// Service managing Android 13+ (API 33+) POST_NOTIFICATIONS runtime permissions
/// required for lock screen media controls and notification drawer playback controls.
class NotificationPermissionService {
  /// Checks whether notification permission is granted on Android.
  static Future<bool> isPermissionGranted() async {
    if (kIsWeb) return true;
    if (!Platform.isAndroid) return true;
    return await Permission.notification.isGranted;
  }

  /// Explicitly requests notification permission and provides immediate user feedback.
  static Future<bool> requestNotificationPermission(BuildContext context) async {
    if (kIsWeb) return true;
    if (!Platform.isAndroid) return true;

    final status = await Permission.notification.status;
    if (status.isGranted) return true;

    final result = await Permission.notification.request();
    if (result.isGranted) {
      if (context.mounted) {
        DilSeNotification.show(
          context,
          message: 'Lock screen & notification controls enabled!',
          type: DilSeNotificationType.success,
          customIcon: Icons.check_circle_rounded,
        );
      }
      return true;
    }

    if (result.isPermanentlyDenied) {
      if (context.mounted) {
        _showOpenSettingsDialog(context);
      }
    }
    return false;
  }

  /// Automatically prompts for notification permission when the user starts playing music
  /// or when the app launches, if permission has not yet been granted.
  static Future<void> promptIfNeeded(BuildContext context) async {
    if (kIsWeb) return;
    if (!Platform.isAndroid) return;

    try {
      final status = await Permission.notification.status;
      if (status.isGranted) return;

      // Request system permission dialog directly
      final result = await Permission.notification.request();
      if (result.isPermanentlyDenied && context.mounted) {
        DilSeNotification.show(
          context,
          message: 'Enable notifications in Settings for lock screen media controls',
          type: DilSeNotificationType.warning,
          customIcon: Icons.notifications_active_rounded,
        );
      } else if (result.isGranted && context.mounted) {
        DilSeNotification.show(
          context,
          message: 'Lock screen controls enabled',
          type: DilSeNotificationType.success,
          customIcon: Icons.check_circle_rounded,
        );
      }
    } catch (e) {
      debugPrint('[NotificationPermission] Error checking permission: $e');
    }
  }

  static void _showOpenSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.cardDarkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.radius.card),
        ),
        title: Row(
          children: [
            Icon(Icons.notifications_active_rounded, color: context.colors.brandRuby),
            SizedBox(width: context.spacing.sm),
            Text(
              'Enable Controls',
              style: context.typography.titleLarge.copyWith(
                color: context.colors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'To show music playback controls and album artwork on your lock screen and notification drawer, please allow Notifications in App Settings.',
          style: context.typography.bodyMedium.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Not Now',
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.brandRuby,
              foregroundColor: context.colors.oledBackground,
              shape: RoundedRectangleBorder(
                borderRadius: context.radius.asBorderRadiusSm,
              ),
            ),
            child: Text(
              'Open Settings',
              style: context.typography.titleMedium.copyWith(
                color: context.colors.oledBackground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
