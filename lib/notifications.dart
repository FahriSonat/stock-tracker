import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'domain.dart';

class StockNotifications {
  final plugin = FlutterLocalNotificationsPlugin();
  bool ready = false;
  Future<void> init() async {
    if (kIsWeb) return;
    ready =
        await plugin.initialize(
          const InitializationSettings(
            android: AndroidInitializationSettings('ic_stat_stock'),
            iOS: DarwinInitializationSettings(
              requestAlertPermission: false,
              requestBadgePermission: false,
              requestSoundPermission: false,
            ),
            windows: WindowsInitializationSettings(
              appName: 'Stok Pilot',
              appUserModelId: 'com.stokpilot.app',
              guid: '117c5e70-6ca4-4b78-a315-e0a04a0d5309',
            ),
          ),
        ) ??
        false;
  }

  Future<bool> requestPermission() async {
    if (!ready) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return defaultTargetPlatform == TargetPlatform.windows;
  }

  Future<bool> lowStock(Product p, double quantity) async {
    if (!ready) return false;
    // Stable positive identifier, also after process restart.
    final id = p.id.codeUnits.fold(
      0,
      (int h, c) => ((h * 31) + c) & 0x7fffffff,
    );
    await plugin.show(
      id,
      'Düşük stok: ${p.name}',
      'Kalan: $quantity ${p.unit} • Kritik sınır: ${p.threshold} ${p.unit}',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'low_stock',
          'Düşük stok uyarıları',
          channelDescription: 'Belirlediğiniz eşiğe ulaşan ürünler',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        windows: WindowsNotificationDetails(),
      ),
    );
    return true;
  }
}
