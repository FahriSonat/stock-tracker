import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:stok_pilot/domain.dart';
import 'package:stok_pilot/export.dart';
import 'package:stok_pilot/notifications.dart';
import 'package:stok_pilot/store.dart';

class FakeNotifications extends StockNotifications {
  int count = 0;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<bool> lowStock(Product p, double quantity) async {
    count++;
    return true;
  }
}

void main() {
  late Directory temp;
  late Box box;
  late AppStore store;
  late FakeNotifications notifications;
  Product product({double cost = 10}) => Product(
    id: 'p1',
    name: 'Kahve',
    sku: 'K-01',
    category: 'Gıda',
    unit: 'paket',
    cost: cost,
    threshold: 3,
    createdAt: DateTime(2026, 1, 1),
  );
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('stok_test_');
    Hive.init(temp.path);
    box = await Hive.openBox('test');
    notifications = FakeNotifications();
    store = AppStore(box, notifications)
      ..user = {
        'id': 'admin',
        'name': 'Yönetici',
        'role': 'admin',
        'email': 'admin@test.local',
      };
  });
  tearDown(() async {
    store.dispose();
    await Hive.close();
    await temp.delete(recursive: true);
  });

  test(
    'Ledger persists, repricing preserves historical inventory valuation',
    () async {
      final p = product();
      await store.saveProduct(p);
      await store.move(p, 10, false, 'Alım');
      await store.move(p, 4, true, 'Tüketim');
      expect(store.inventory.quantity(p.id), 6);
      await store.saveProduct(product(cost: 20));
      expect(store.events.last.valueDelta, 60);
      expect(store.inventory.totalValue, 120);
      expect(
        store.inventory.valueAt(DateTime.now().add(const Duration(days: 1))),
        120,
      );
      final reopened = AppStore(box, FakeNotifications());
      expect(reopened.inventory.quantity(p.id), 6);
      expect(reopened.events[1].actorName, 'Yönetici');
      reopened.dispose();
    },
  );
  test(
    'Insufficient, zero, negative and non-finite movements cannot mutate data',
    () async {
      final p = product();
      await store.saveProduct(p);
      await store.move(p, 5, false, '');
      for (final amount in [0.0, -1.0, double.nan, double.infinity, 6.0]) {
        await expectLater(store.move(p, amount, true, ''), throwsStateError);
        expect(store.inventory.quantity(p.id), 5);
        expect(store.events.length, 2);
      }
    },
  );
  test(
    'Staff can only issue stock, cannot receive or manage products/users',
    () async {
      final p = product();
      await store.saveProduct(p);
      await store.move(p, 10, false, 'Admin teslim aldı');
      await box.put('accounts', '[{"id":"a","role":"admin"}]');
      store.user = {'id': 'staff', 'name': 'Çalışan', 'role': 'staff'};
      await expectLater(store.move(p, 5, false, ''), throwsStateError);
      expect(store.inventory.quantity(p.id), 10);
      await store.move(p, 5, true, '');
      expect(store.events.last.actorId, 'staff');
      await expectLater(store.saveProduct(product(cost: 20)), throwsStateError);
      await expectLater(
        store.createAccount('X', 'x@test.local', 'password'),
        throwsStateError,
      );
    },
  );
  test(
    'Freeze blocks both roles and stale product references until admin unfreezes',
    () async {
      final original = product();
      await store.saveProduct(original);
      await store.move(original, 10, false, '');
      final frozen = Product.fromJson({
        ...store.products.first.toJson(),
        'isFrozen': true,
        'adminMessage': 'Bu ürünü kullanmayın.',
      });
      await store.saveProduct(frozen);
      final count = store.events.length;
      for (final role in ['admin', 'staff']) {
        store.user = {'id': role, 'name': role, 'role': role};
        for (final outgoing in [true, false]) {
          await expectLater(
            store.move(original, 1, outgoing, ''),
            throwsStateError,
          );
        }
        expect(store.inventory.quantity(original.id), 10);
        expect(store.events.length, count);
      }
      await expectLater(store.saveProduct(original), throwsStateError);
      final reopened = AppStore(box, FakeNotifications());
      expect(reopened.products.first.isFrozen, isTrue);
      expect(reopened.products.first.adminMessage, 'Bu ürünü kullanmayın.');
      reopened.dispose();
      store.user = {'id': 'admin', 'name': 'Admin', 'role': 'admin'};
      await store.saveProduct(
        Product.fromJson({...frozen.toJson(), 'isFrozen': false}),
      );
      store.user = {'id': 'staff', 'name': 'Staff', 'role': 'staff'};
      await store.move(original, 1, true, '');
      expect(store.inventory.quantity(original.id), 9);
      expect(store.products.first.adminMessage, 'Bu ürünü kullanmayın.');
    },
  );
  test(
    'Legacy records default to usable; threshold and supported units persist',
    () async {
      final legacy = product().toJson()
        ..remove('adminMessage')
        ..remove('isFrozen');
      expect(Product.fromJson(legacy).isFrozen, isFalse);
      expect(Product.fromJson(legacy).adminMessage, isEmpty);
      for (final unit in ['adet', 'kg', 'lt', 'gram']) {
        final p = Product.fromJson({...legacy, 'unit': unit, 'threshold': 2.5});
        await store.saveProduct(p);
        expect(store.products.first.unit, unit);
        expect(store.products.first.threshold, 2.5);
      }
      await store.move(store.products.first, 2.5, false, '');
      expect(store.inventory.lowStock.length, 1);
      await expectLater(
        store.saveProduct(Product.fromJson({...legacy, 'unit': 'kg'})),
        throwsStateError,
      );
    },
  );
  test(
    'Remote freeze/message reaches staff even when upload queue is blocked',
    () async {
      final p = product();
      await store.saveProduct(p);
      await store.move(p, 5, false, '');
      store.user = {'id': 'staff', 'name': 'Staff', 'role': 'staff'};
      final remote = Product.fromJson({
        ...p.toJson(),
        'isFrozen': true,
        'adminMessage': 'Kalite kontrol bekleniyor',
      });
      store.applyServerControls([remote]);
      expect(store.products.first.isFrozen, isTrue);
      expect(store.products.first.adminMessage, remote.adminMessage);
      expect(store.inventory.quantity(p.id), 5);
      await expectLater(store.move(p, 1, true, ''), throwsStateError);
    },
  );
  test(
    'Local accounts verify passwords and assign first admin then staff',
    () async {
      store.user = null;
      await store.createAccount('Admin', 'a@test.local', 'longpassword');
      await expectLater(
        store.login('a@test.local', 'incorrect'),
        throwsStateError,
      );
      await store.login('A@test.local', 'longpassword');
      expect(store.isAdmin, isTrue);
      await store.createAccount('Staff', 's@test.local', 'staffpass');
      await store.logout();
      await store.login('s@test.local', 'staffpass');
      expect(store.isAdmin, isFalse);
      expect(store.accounts.first['hash'], isNot('longpassword'));
    },
  );
  test(
    'Low stock alert fires once per threshold crossing, survives restart',
    () async {
      final p = product();
      await store.saveProduct(p);
      await store.move(p, 10, false, '');
      await store.enableNotifications();
      expect(notifications.count, 0);
      await store.move(p, 7, true, '');
      await store.move(p, 1, true, '');
      expect(notifications.count, 1);
      await store.move(p, 10, false, '');
      await store.move(p, 10, true, '');
      expect(notifications.count, 2);
    },
  );
  test('Month boundaries, stock forecast and absence of consumption', () {
    final p = product();
    StockEvent event(double delta, DateTime at) => StockEvent(
      id: ids.v4(),
      productId: p.id,
      productName: p.name,
      actorId: 'a',
      actorName: 'A',
      kind: delta > 0 ? 'in' : 'out',
      note: '',
      delta: delta,
      valueDelta: delta * 10,
      at: at,
    );
    final now = DateTime(2026, 2, 1);
    final inv = Inventory(
      [p],
      [
        event(100, DateTime(2026, 1, 1)),
        event(-30, DateTime(2026, 1, 20)),
        event(-5, now),
      ],
    );
    expect(inv.during(DateTime(2026, 1, 1), now).length, 2);
    expect(inv.valueAt(now), 700);
    expect(inv.averageDaily(p, now), closeTo(35 / 30, .001));
    expect(inv.depletion(p, now), now.add(const Duration(days: 56)));
    expect(Inventory([p], [event(10, now)]).depletion(p, now), isNull);
    expect(Inventory([p], []).depletion(p, now), now);
  });
  test('CSV safely quotes Turkish text, delimiters and formula prefixes', () {
    final csv = csvEncode([
      ['Ürün; "adı"', '=SUM(A1)', '\t@evil', -4.5],
    ]);
    expect(csv, startsWith('\uFEFF'));
    expect(csv, contains('"Ürün; ""adı"""'));
    expect(csv, contains("'=SUM(A1)"));
    expect(csv, contains("'\t@evil"));
    expect(csv, contains('"-4.5"'));
  });
  test(
    'Search history deduplicates, persists and remains user specific',
    () async {
      await store.rememberSearch('kahve');
      await store.rememberSearch('kupa');
      await store.rememberSearch('kahve');
      expect(store.searches, ['kahve', 'kupa']);
      store.user = {'id': 'other'};
      expect(store.searches, isEmpty);
    },
  );
}
