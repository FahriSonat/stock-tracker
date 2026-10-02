import 'dart:async';
import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'domain.dart';
import 'notifications.dart';

const cloudUrl = String.fromEnvironment('SUPABASE_URL');
const cloudKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const cloudEnabled = cloudUrl != '' && cloudKey != '';
const ids = Uuid();

class AppStore extends ChangeNotifier {
  final Box box;
  final StockNotifications notifications;
  AppStore(this.box, this.notifications) {
    _read();
  }
  Json? user;
  List<Product> products = [];
  List<StockEvent> events = [];
  List<Json> pending = [];
  bool busy = false;
  String syncMessage = cloudEnabled
      ? 'Bağlantı bekleniyor'
      : 'Yerel çalışma alanı';
  Timer? _timer;
  bool get isAdmin => user?['role'] == 'admin';
  bool get dark => box.get('dark', defaultValue: false);
  bool get firstRun => !cloudEnabled && accounts.isEmpty;
  List<Json> get accounts =>
      (jsonDecode(box.get('accounts', defaultValue: '[]')) as List)
          .cast<Json>();
  Inventory get inventory => Inventory(products, events);
  String get _stateKey =>
      cloudEnabled ? 'cloud_${user?['workspace']}' : 'inventory';
  List<String> get searches => List<String>.from(
    box.get('search_${user?['id']}', defaultValue: <String>[]),
  );

  void _read() {
    final j = jsonDecode(box.get(_stateKey, defaultValue: '{}')) as Json;
    products = (j['products'] as List? ?? [])
        .map((x) => Product.fromJson(x))
        .toList();
    events = (j['events'] as List? ?? [])
        .map((x) => StockEvent.fromJson(x))
        .toList();
    pending = (j['pending'] as List? ?? []).cast<Json>();
  }

  Future<void> _save() => box.put(
    _stateKey,
    jsonEncode({
      'products': products.map((p) => p.toJson()).toList(),
      'events': events.map((e) => e.toJson()).toList(),
      'pending': pending,
    }),
  );
  Future<void> toggleDark(bool value) async {
    await box.put('dark', value);
    notifyListeners();
  }

  Future<void> rememberSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    await box.put(
      'search_${user?['id']}',
      [q, ...searches.where((s) => s != q)].take(8).toList(),
    );
    notifyListeners();
  }

  Future<void> clearSearches() async {
    await box.delete('search_${user?['id']}');
    notifyListeners();
  }

  static Future<String> passwordHash(String password, String salt) async {
    final key =
        await Pbkdf2(
          macAlgorithm: Hmac.sha256(),
          iterations: 210000,
          bits: 256,
        ).deriveKey(
          secretKey: SecretKey(utf8.encode(password)),
          nonce: base64Decode(salt),
        );
    return base64Encode(await key.extractBytes());
  }

  Future<void> createAccount(
    String name,
    String email,
    String password, {
    bool admin = false,
  }) async {
    if (cloudEnabled) {
      throw StateError(
        'Bulut kullanıcılarını Supabase yönetim panelinden ekleyin.',
      );
    }
    if (!firstRun && !isAdmin) throw StateError('Yönetici yetkisi gerekiyor.');
    if (name.trim().isEmpty || !email.contains('@') || password.length < 8) {
      throw StateError(
        'Ad, geçerli e-posta ve en az 8 karakterli parola girin.',
      );
    }
    final all = accounts;
    email = email.trim().toLowerCase();
    if (all.any((a) => a['email'] == email)) {
      throw StateError('Bu e-posta zaten kayıtlı.');
    }
    final salt = base64Encode(SecretKeyData.random(length: 16).bytes);
    final account = {
      'id': ids.v4(),
      'name': name.trim(),
      'email': email,
      'role': firstRun || admin ? 'admin' : 'staff',
      'salt': salt,
      'hash': await passwordHash(password, salt),
    };
    all.add(account);
    await box.put('accounts', jsonEncode(all));
    notifyListeners();
  }

  Future<void> login(
    String email,
    String password, {
    bool offline = false,
  }) async {
    email = email.trim().toLowerCase();
    if (cloudEnabled && !offline) {
      final client = Supabase.instance.client;
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final profile = await client
          .from('profiles')
          .select()
          .eq('id', response.user!.id)
          .single();
      if (profile['active'] != true) throw StateError('Hesap devre dışı.');
      final salt = base64Encode(SecretKeyData.random(length: 16).bytes);
      user = {
        'id': response.user!.id,
        'name': profile['name'],
        'role': profile['role'],
        'workspace': profile['workspace_id'],
        'email': email,
        'salt': salt,
        'hash': await passwordHash(password, salt),
        'verifiedAt': DateTime.now().toUtc().toIso8601String(),
      };
      await box.put('cached_$email', jsonEncode(user));
    } else {
      final matches = cloudEnabled
          ? [
              if (box.containsKey('cached_$email'))
                jsonDecode(box.get('cached_$email')) as Json,
            ]
          : accounts.where((a) => a['email'] == email).toList();
      if (matches.isEmpty ||
          await passwordHash(password, matches.first['salt']) !=
              matches.first['hash']) {
        throw StateError('E-posta veya parola hatalı.');
      }
      if (cloudEnabled &&
          DateTime.now()
                  .difference(DateTime.parse(matches.first['verifiedAt']))
                  .inDays >=
              7) {
        throw StateError(
          'Çevrimdışı giriş süresi doldu. İnternete bağlanarak giriş yapın.',
        );
      }
      user = matches.first;
    }
    _read();
    _timer?.cancel();
    if (cloudEnabled) {
      _timer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => unawaited(sync()),
      );
      unawaited(sync());
    }
    notifyListeners();
  }

  Future<void> logout() async {
    if (busy) throw StateError('Devam eden işlemin bitmesini bekleyin.');
    _timer?.cancel();
    if (cloudEnabled) {
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    }
    user = null;
    products = [];
    events = [];
    pending = [];
    notifyListeners();
  }

  Future<void> _mutate(Future<void> Function() operation) async {
    if (user == null) throw StateError('Önce giriş yapın.');
    if (busy) throw StateError('Devam eden işlemin bitmesini bekleyin.');
    busy = true;
    notifyListeners();
    try {
      await operation();
      await _save();
    } catch (_) {
      _read();
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
    await checkAlerts();
    if (cloudEnabled) unawaited(sync());
  }

  Future<void> saveProduct(Product p) => _mutate(() async {
    if (!isAdmin) {
      throw StateError('Ürün düzenlemek için yönetici yetkisi gerekiyor.');
    }
    validateProduct(p);
    if (products.any(
      (x) => x.id != p.id && x.sku.toLowerCase() == p.sku.toLowerCase(),
    )) {
      throw StateError('Stok kodu başka bir üründe kullanılıyor.');
    }
    final index = products.indexWhere((x) => x.id == p.id);
    final old = index < 0 ? null : products[index];
    if (old != null && old.unit != p.unit && inventory.quantity(p.id) != 0) {
      throw StateError(
        'Stok varken birim değiştirilemez. Önce mevcut stoğu sıfırlayın veya yeni bir ürün açın.',
      );
    }
    final event = StockEvent(
      id: ids.v4(),
      productId: p.id,
      productName: p.name,
      actorId: user!['id'],
      actorName: user!['name'],
      kind: old == null ? 'create' : 'edit',
      note: old == null
          ? 'Ürün oluşturuldu'
          : [
              'Ürün bilgileri güncellendi',
              if (old.threshold != p.threshold || old.unit != p.unit)
                'Kritik sınır: ${old.threshold} ${old.unit} → ${p.threshold} ${p.unit}',
              if (old.isFrozen != p.isFrozen)
                p.isFrozen
                    ? 'Stok işlemleri donduruldu'
                    : 'Stok işlemleri açıldı',
              if (old.adminMessage != p.adminMessage)
                'Yönetici mesajı: ${p.adminMessage.isEmpty ? "Kaldırıldı" : p.adminMessage}',
            ].join(' • '),
      delta: 0,
      valueDelta: inventory.quantity(p.id) * (p.cost - (old?.cost ?? 0)),
      at: DateTime.now(),
    );
    final revised = Product.fromJson({...p.toJson(), 'revision': event.id});
    if (index < 0) {
      products.add(revised);
    } else {
      products[index] = revised;
    }
    events.add(event);
    if (cloudEnabled) {
      pending.add({
        'id': event.id,
        'actorId': user!['id'],
        'type': 'product',
        'product': revised.toJson(),
        'expectedRevision': old?.revision,
        'event': event.toJson(),
      });
    }
  });
  Future<void> move(Product p, double amount, bool outgoing, String note) =>
      _mutate(() async {
        final current = products.firstWhere((x) => x.id == p.id);
        if (current.isFrozen) {
          throw StateError(
            'Bu ürünün stok işlemleri admin tarafından donduruldu.',
          );
        }
        if (!outgoing && !isAdmin) {
          throw StateError('Stok girişini yalnızca admin yapabilir.');
        }
        validateMovement(amount, inventory.quantity(p.id), outgoing);
        final delta = outgoing ? -amount : amount;
        final event = StockEvent(
          id: ids.v4(),
          productId: p.id,
          productName: current.name,
          actorId: user!['id'],
          actorName: user!['name'],
          kind: outgoing ? 'out' : 'in',
          note: note.trim(),
          delta: delta,
          valueDelta: delta * current.cost,
          at: DateTime.now(),
        );
        events.add(event);
        if (cloudEnabled) {
          pending.add({
            'id': event.id,
            'actorId': user!['id'],
            'type': 'movement',
            'event': event.toJson(),
          });
        }
      });
  Future<void> sync() async {
    if (!cloudEnabled || user == null || busy) return;
    busy = true;
    syncMessage = 'Senkronize ediliyor…';
    notifyListeners();
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser?.id != user!['id']) {
        throw StateError('Senkronizasyon için çevrimiçi giriş yapın.');
      }
      final profile = await client
          .from('profiles')
          .select()
          .eq('id', user!['id'])
          .single();
      if (profile['active'] != true ||
          profile['workspace_id'] != user!['workspace']) {
        throw StateError('Çalışma alanı erişimi kaldırılmış.');
      }
      user!['role'] = profile['role'];
      // Pull restrictions before uploads: a rejected offline movement must not
      // prevent the user from seeing the latest freeze and administrator message.
      final controls =
          await client
                  .rpc('inventory_snapshot')
                  .timeout(const Duration(seconds: 20))
              as Json;
      applyServerControls(
        (controls['products'] as List).map((p) => Product.fromJson(p)).toList(),
      );
      await _save();
      notifyListeners();
      for (final operation in List<Json>.from(pending)) {
        // Another user's unconfirmed edits must never be attributed to this session.
        if (operation['actorId'] != user!['id']) {
          throw StateError(
            'Bekleyen işlemleri göndermek için işlemi yapan kullanıcı giriş yapmalı.',
          );
        }
        await client
            .rpc('apply_operation', params: {'operation': operation})
            .timeout(const Duration(seconds: 20));
        pending.removeWhere((x) => x['id'] == operation['id']);
        await _save();
      }
      // One RPC provides a consistent snapshot, without the default 1000-row REST limit.
      final snapshot =
          await client
                  .rpc('inventory_snapshot')
                  .timeout(const Duration(seconds: 20))
              as Json;
      products = (snapshot['products'] as List)
          .map((p) => Product.fromJson(p))
          .toList();
      events = (snapshot['events'] as List)
          .map((e) => StockEvent.fromJson(e))
          .toList();
      await _save();
      final now = DateTime.now();
      syncMessage =
          'Güncel · ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      syncMessage =
          'Senkronizasyon bekliyor: ${e.toString().replaceFirst('Bad state: ', '')}';
    } finally {
      busy = false;
      notifyListeners();
    }
    await checkAlerts();
  }

  Future<void> checkAlerts() async {
    if (user == null) return;
    for (final p in products) {
      final low = inventory.quantity(p.id) <= p.threshold;
      final key = 'alert_${_stateKey}_${p.id}';
      if (low &&
          box.get('notifications', defaultValue: false) &&
          !box.get(key, defaultValue: false)) {
        try {
          final sent = await notifications.lowStock(
            p,
            inventory.quantity(p.id),
          );
          if (sent) await box.put(key, true);
        } catch (_) {
          /* Stock persistence must not depend on notification delivery. */
        }
      } else if (!low) {
        await box.put(key, false);
      }
    }
  }

  void applyServerControls(List<Product> remoteProducts) {
    final remote = {for (final p in remoteProducts) p.id: p};
    final edited = pending
        .where((op) => op['type'] == 'product')
        .map((op) => op['product']['id'])
        .toSet();
    products = products.map((p) {
      final server = remote[p.id];
      if (server == null || (isAdmin && edited.contains(p.id))) return p;
      return Product.fromJson({
        ...p.toJson(),
        'isFrozen': server.isFrozen,
        'adminMessage': server.adminMessage,
      });
    }).toList();
  }

  Future<void> useServerSnapshot() async {
    if (!cloudEnabled || user == null || busy) {
      throw StateError('İşlem şu anda kullanılamıyor.');
    }
    if (pending.any((p) => p['actorId'] != user!['id'])) {
      throw StateError(
        'Başka kullanıcının bekleyen işlemleri var. İşlem sahibi giriş yapmalı.',
      );
    }
    busy = true;
    notifyListeners();
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser?.id != user!['id']) {
        throw StateError('Önce çevrimiçi giriş yapın.');
      }
      final snapshot =
          await client
                  .rpc('inventory_snapshot')
                  .timeout(const Duration(seconds: 20))
              as Json;
      // Preserve discarded proposals for support/audit before replacing the local view.
      await box.put(
        'rejected_${_stateKey}_${DateTime.now().microsecondsSinceEpoch}',
        jsonEncode(pending),
      );
      products = (snapshot['products'] as List)
          .map((p) => Product.fromJson(p))
          .toList();
      events = (snapshot['events'] as List)
          .map((e) => StockEvent.fromJson(e))
          .toList();
      pending = [];
      await _save();
      syncMessage =
          'Sunucu verisi alındı. İptal edilen öneriler cihaz arşivinde saklandı.';
    } catch (_) {
      _read();
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> enableNotifications() async {
    final allowed = await notifications.requestPermission();
    await box.put('notifications', allowed);
    notifyListeners();
    if (!allowed) {
      throw StateError(
        'Bildirim izni verilmedi veya bu platform desteklenmiyor.',
      );
    }
    await checkAlerts();
  }

  Future<void> disableNotifications() async {
    await box.put('notifications', false);
    notifyListeners();
  }

  Future<void> seedExample() => _mutate(() async {
    if (!isAdmin || products.isNotEmpty || cloudEnabled) {
      throw StateError(
        'Örnek veri yalnızca boş yerel çalışma alanına eklenebilir.',
      );
    }
    final now = DateTime.now();
    final samples = [
      ('Filtre Kahve', 'KH-001', 'İçecek', 'paket', 285.0, 15.0, 76.0),
      ('Seramik Kupa', 'EV-002', 'Ev & Yaşam', 'adet', 145.0, 10.0, 54.0),
      ('Kraft Çanta', 'PK-003', 'Ambalaj', 'adet', 12.5, 50.0, 210.0),
      ('Bitki Çayı', 'CY-004', 'İçecek', 'kutu', 95.0, 12.0, 64.0),
      ('Cam Matara', 'EV-005', 'Ev & Yaşam', 'adet', 220.0, 8.0, 45.0),
    ];
    for (var i = 0; i < samples.length; i++) {
      final s = samples[i];
      final p = Product(
        id: ids.v4(),
        name: s.$1,
        sku: s.$2,
        category: s.$3,
        unit: s.$4,
        cost: s.$5,
        threshold: s.$6,
        createdAt: now.subtract(const Duration(days: 30)),
      );
      products.add(p);
      void add(double d, int day) => events.add(
        StockEvent(
          id: ids.v4(),
          productId: p.id,
          productName: p.name,
          actorId: user!['id'],
          actorName: user!['name'],
          kind: d > 0 ? 'in' : 'out',
          note: 'Örnek veri',
          delta: d,
          valueDelta: d * p.cost,
          at: now.subtract(Duration(days: day)),
        ),
      );
      add(s.$7, 30);
      for (var day = 27; day >= 0; day -= 3) {
        add(
          -(i == 2
              ? 18.0
              : i == 0
              ? 7.0
              : 3.0),
          day,
        );
      }
    }
  });
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
