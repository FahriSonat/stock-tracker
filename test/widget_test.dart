import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:stok_pilot/main.dart';
import 'package:stok_pilot/notifications.dart';
import 'package:stok_pilot/store.dart';
import 'package:stok_pilot/domain.dart';

void main() {
  late Directory temp;
  late AppStore store;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('stok_ui_');
    Hive.init(temp.path);
    final box = await Hive.openBox('ui');
    store = AppStore(box, StockNotifications());
  });
  tearDown(() async {
    store.dispose();
    await Hive.close();
    await temp.delete(recursive: true);
  });
  testWidgets('First run displays account creation form', (tester) async {
    await tester.pumpWidget(StockApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Çalışma alanını oluştur'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));
  });
  testWidgets(
    'Staff sees output only; open dialog reacts to remote freeze and message',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      store.user = {
        'id': 'a',
        'name': 'Admin',
        'role': 'admin',
        'email': 'a@test.local',
      };
      await tester.runAsync(store.seedExample);
      final p = store.products.first;
      store.user = {
        'id': 's',
        'name': 'Staff',
        'role': 'staff',
        'email': 's@test.local',
      };
      await tester.pumpWidget(StockApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ürünler').first);
      await tester.pumpAndSettle();
      expect(find.text('Yeni ürün'), findsNothing);
      await tester.tap(find.text(p.name).first);
      await tester.pumpAndSettle();
      expect(find.text('Düzenle'), findsNothing);
      await tester.tap(find.text('Stok çıkışı').last);
      await tester.pumpAndSettle();
      expect(find.text('Stok girişi'), findsNothing);
      expect(find.byType(SegmentedButton<bool>), findsNothing);
      store.applyServerControls([
        Product.fromJson({
          ...p.toJson(),
          'isFrozen': true,
          'adminMessage': 'Bu ürünü kullanmayın',
        }),
      ]);
      await tester.runAsync(() => store.toggleDark(true));
      await tester.pumpAndSettle();
      expect(find.text('⛔ STOK İŞLEMLERİ DONDURULDU'), findsWidgets);
      expect(
        find.text('Yönetici mesajı: Bu ürünü kullanmayın'),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'İşlemler donduruldu'),
      );
      expect(button.onPressed, isNull);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Admin product form exposes unit choices, critical limit, message and freeze',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      store.user = {
        'id': 'a',
        'name': 'Admin',
        'role': 'admin',
        'email': 'a@test.local',
      };
      await tester.pumpWidget(StockApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yeni ürün'));
      await tester.pumpAndSettle();
      expect(find.text('Kritik sınır (seçilen birimde)'), findsOneWidget);
      expect(
        find.text('Kullanıcılara yönetici mesajı (isteğe bağlı)'),
        findsOneWidget,
      );
      expect(find.text('Stok işlemlerini dondur'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      for (final unit in ['adet', 'kg', 'lt', 'gram']) {
        expect(find.text(unit), findsWidgets);
      }
      await tester.tap(find.text('kg').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [390.0, 1440.0]) {
    testWidgets('Dashboard and pages render at width $width in both themes', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      store.user = {
        'id': 'a',
        'name': 'Test Yönetici',
        'email': 'a@test.local',
        'role': 'admin',
      };
      await tester.runAsync(store.seedExample);
      await tester.pumpWidget(StockApp(store: store));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final label in [
        'Ürünler',
        'Hareketler',
        'Raporlar',
        'Ayarlar',
        'Genel bakış',
      ]) {
        await tester.tap(find.text(label).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: label);
      }
      await tester.runAsync(() => store.toggleDark(true));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
        Brightness.dark,
      );
    });
  }
}
