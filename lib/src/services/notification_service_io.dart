import 'package:permission_handler/permission_handler.dart';

class NotificationPermissionState {
  const NotificationPermissionState({
    required this.supported,
    required this.granted,
    required this.message,
  });

  final bool supported;
  final bool granted;
  final String message;
}

class AppNotificationService {
  const AppNotificationService();

  Future<NotificationPermissionState> requestPermission() async {
    try {
      final status = await Permission.notification.request();
      if (status.isGranted) {
        return const NotificationPermissionState(
          supported: true,
          granted: true,
          message: 'Notifications are enabled',
        );
      }

      return const NotificationPermissionState(
        supported: true,
        granted: false,
        message: 'Notifications were not enabled',
      );
    } catch (_) {
      return const NotificationPermissionState(
        supported: false,
        granted: false,
        message: 'Notifications are not available on this device',
      );
    }
  }

  Future<NotificationPermissionState> showTestNotification() async {
    try {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        return const NotificationPermissionState(
          supported: true,
          granted: false,
          message: 'Enable notifications first',
        );
      }

      return const NotificationPermissionState(
        supported: true,
        granted: true,
        message: 'Notifications are ready',
      );
    } catch (_) {
      return const NotificationPermissionState(
        supported: false,
        granted: false,
        message: 'Notifications are not available on this device',
      );
    }
  }
}
