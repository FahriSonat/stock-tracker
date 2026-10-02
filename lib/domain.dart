import 'dart:math';

typedef Json = Map<String, dynamic>;

class Product {
  final String id, name, sku, category, unit;
  final double cost, threshold;
  final DateTime createdAt;
  final String? revision;
  final String adminMessage;
  final bool isFrozen;
  const Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.category,
    required this.unit,
    required this.cost,
    required this.threshold,
    required this.createdAt,
    this.revision,
    this.adminMessage = '',
    this.isFrozen = false,
  });
  factory Product.fromJson(Json j) => Product(
    id: j['id'],
    name: j['name'],
    sku: j['sku'],
    category: j['category'],
    unit: j['unit'],
    cost: (j['cost'] as num).toDouble(),
    threshold: (j['threshold'] as num).toDouble(),
    createdAt: DateTime.parse(j['createdAt']),
    revision: j['revision'],
    adminMessage: j['adminMessage'] ?? '',
    isFrozen: j['isFrozen'] ?? false,
  );
  Json toJson() => {
    'id': id,
    'name': name,
    'sku': sku,
    'category': category,
    'unit': unit,
    'cost': cost,
    'threshold': threshold,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'revision': revision,
    'adminMessage': adminMessage,
    'isFrozen': isFrozen,
  };
}

class StockEvent {
  final String id, productId, productName, actorId, actorName, kind, note;
  final double delta, valueDelta;
  final DateTime at;
  const StockEvent({
    required this.id,
    required this.productId,
    required this.productName,
    required this.actorId,
    required this.actorName,
    required this.kind,
    required this.note,
    required this.delta,
    required this.valueDelta,
    required this.at,
  });
  factory StockEvent.fromJson(Json j) => StockEvent(
    id: j['id'],
    productId: j['productId'],
    productName: j['productName'],
    actorId: j['actorId'],
    actorName: j['actorName'],
    kind: j['kind'],
    note: j['note'] ?? '',
    delta: (j['delta'] as num).toDouble(),
    valueDelta: (j['valueDelta'] as num).toDouble(),
    at: DateTime.parse(j['at']),
  );
  Json toJson() => {
    'id': id,
    'productId': productId,
    'productName': productName,
    'actorId': actorId,
    'actorName': actorName,
    'kind': kind,
    'note': note,
    'delta': delta,
    'valueDelta': valueDelta,
    'at': at.toUtc().toIso8601String(),
  };
}

class Inventory {
  final List<Product> products;
  final List<StockEvent> events;
  const Inventory(this.products, this.events);
  double quantity(String id) =>
      events.where((e) => e.productId == id).fold(0.0, (v, e) => v + e.delta);
  double get totalValue =>
      products.fold(0.0, (v, p) => v + quantity(p.id) * p.cost);
  List<Product> get lowStock =>
      products.where((p) => quantity(p.id) <= p.threshold).toList();
  List<StockEvent> during(DateTime start, DateTime end) =>
      events.where((e) => !e.at.isBefore(start) && e.at.isBefore(end)).toList();
  double consumption(String id, DateTime start, DateTime end) =>
      during(start, end)
          .where((e) => e.productId == id && e.kind == 'out')
          .fold(0.0, (v, e) => v - e.delta);
  double averageDaily(Product p, DateTime now) {
    final start = now.subtract(const Duration(days: 30));
    final observed = p.createdAt.isAfter(start) ? p.createdAt : start;
    final days = max(1.0, now.difference(observed).inSeconds / 86400);
    return consumption(
          p.id,
          observed,
          now.add(const Duration(microseconds: 1)),
        ) /
        days;
  }

  DateTime? depletion(Product p, DateTime now) {
    if (quantity(p.id) <= 0) return now;
    final avg = averageDaily(p, now);
    final days = quantity(p.id) / avg;
    if (avg <= 0 || !days.isFinite || days > 36500) return null;
    return now.add(Duration(days: days.ceil()));
  }

  double valueAt(DateTime end) => events
      .where((e) => e.at.isBefore(end))
      .fold(0.0, (v, e) => v + e.valueDelta);
}

void validateProduct(Product p) {
  if (p.name.trim().isEmpty || p.sku.trim().isEmpty || p.unit.trim().isEmpty) {
    throw StateError('Ürün adı, stok kodu ve birim zorunludur.');
  }
  if (!p.cost.isFinite ||
      p.cost < 0 ||
      !p.threshold.isFinite ||
      p.threshold < 0) {
    throw StateError('Birim maliyet ve eşik sıfır veya pozitif olmalıdır.');
  }
}

void validateMovement(double amount, double available, bool outgoing) {
  if (!amount.isFinite || amount <= 0) {
    throw StateError('Miktar sıfırdan büyük olmalıdır.');
  }
  if (outgoing && amount > available) {
    throw StateError('Yetersiz stok. Mevcut miktar: $available');
  }
}
