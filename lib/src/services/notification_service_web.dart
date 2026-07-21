// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

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
    if (!_hasNotificationApi) {
      return const NotificationPermissionState(
        supported: false,
        granted: false,
        message: 'Notifications are not supported in this browser',
      );
    }

    final registration = await _registerPushWorker();
    final permission = await _requestBrowserPermission();
    if (permission == 'granted') {
      await _subscribeForPush(registration);
      return const NotificationPermissionState(
        supported: true,
        granted: true,
        message: 'Notifications are enabled',
      );
    }

    return NotificationPermissionState(
      supported: true,
      granted: false,
      message: permission == 'denied'
          ? 'Notifications are blocked in this browser'
          : 'Notifications were not enabled',
    );
  }

  Future<NotificationPermissionState> showTestNotification() async {
    final state = await requestPermission();
    if (!state.granted) {
      return state;
    }

    try {
      html.Notification(
        'SapScanner',
        body: 'Your document tools are ready.',
        icon: 'icons/Icon-192.png',
      );
      return const NotificationPermissionState(
        supported: true,
        granted: true,
        message: 'Test notification sent',
      );
    } catch (_) {
      return const NotificationPermissionState(
        supported: true,
        granted: true,
        message: 'Notifications are enabled',
      );
    }
  }

  bool get _hasNotificationApi {
    return html.Notification.supported;
  }

  Future<String> _requestBrowserPermission() async {
    final current = html.Notification.permission;
    if (current == 'granted' || current == 'denied') {
      return current!;
    }

    return html.Notification.requestPermission();
  }

  Future<html.ServiceWorkerRegistration?> _registerPushWorker() async {
    return html.window.navigator.serviceWorker?.register('push-sw.js', {
      'scope': 'push/',
    });
  }

  Future<void> _subscribeForPush(
    html.ServiceWorkerRegistration? registration,
  ) async {
    final publicKey = _vapidPublicKey;
    final manager = registration?.pushManager;
    if (manager == null || publicKey.isEmpty) {
      return;
    }

    html.PushSubscription? subscription;
    try {
      subscription = await manager.getSubscription();
    } catch (_) {
      subscription = null;
    }

    subscription ??= await manager.subscribe({
      'userVisibleOnly': true,
      'applicationServerKey': _urlBase64ToBytes(publicKey).buffer,
    });
    html.window.localStorage['sapscanner-push-subscription'] = jsonEncode(
      _subscriptionJson(subscription),
    );
  }

  String get _vapidPublicKey {
    final meta = html.document.querySelector(
      'meta[name="sapscanner-vapid-public-key"]',
    );
    return meta?.getAttribute('content')?.trim() ?? '';
  }

  Map<String, Object?> _subscriptionJson(html.PushSubscription subscription) {
    return {
      'endpoint': subscription.endpoint,
      'expirationTime': subscription.expirationTime,
      'keys': {
        'p256dh': _bufferToBase64(subscription.getKey('p256dh')),
        'auth': _bufferToBase64(subscription.getKey('auth')),
      },
    };
  }

  String _bufferToBase64(ByteBuffer? buffer) {
    if (buffer == null) {
      return '';
    }

    return base64UrlEncode(Uint8List.view(buffer));
  }

  Uint8List _urlBase64ToBytes(String value) {
    final normalized = value.replaceAll('-', '+').replaceAll('_', '/');
    final padding = '=' * ((4 - normalized.length % 4) % 4);
    return Uint8List.fromList(base64.decode('$normalized$padding'));
  }
}
