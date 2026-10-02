import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'domain.dart';

String safeCell(Object? value) {
  final s = value?.toString() ?? '';
  return RegExp(r'^[\s]*[=+@\-]').hasMatch(s) ? "'$s" : s;
}

String csvEncode(List<List<Object?>> rows) =>
    '\uFEFF${rows.map((row) => row.map((v) {
      final s = v is num ? v.toString() : safeCell(v);
      return '"${s.replaceAll('"', '""')}"';
    }).join(';')).join('\r\n')}';

Map<String, List<List<Object?>>> reportTables(
  Inventory inventory,
  DateTime month,
) {
  final start = DateTime(month.year, month.month);
  final end = DateTime(month.year, month.month + 1);
  final movements = inventory.during(start, end);
  final incoming = movements
      .where((e) => e.kind == 'in')
      .fold(0.0, (v, e) => v + e.valueDelta);
  final outgoing = movements
      .where((e) => e.kind == 'out')
      .fold(0.0, (v, e) => v - e.valueDelta);
  return {
    'Aylık Özet': [
      ['Dönem', '${month.year}-${month.month.toString().padLeft(2, '0')}'],
      ['Açılış stok değeri (TL)', inventory.valueAt(start)],
      ['Giriş maliyeti (TL)', incoming],
      ['Çıkış maliyeti (TL)', outgoing],
      [
        'Maliyet düzeltmesi (TL)',
        movements
            .where((e) => e.kind == 'edit')
            .fold<double>(0.0, (v, e) => v + e.valueDelta),
      ],
      ['Dönem sonu / bugüne kadar stok değeri (TL)', inventory.valueAt(end)],
      ['Hareket sayısı', movements.where((e) => e.delta != 0).length],
      ['Not', 'Değerler alış maliyetidir; satış geliri veya kâr değildir.'],
    ],
    'Ürünler (Güncel)': [
      [
        'Stok Kodu',
        'Ürün',
        'Kategori',
        'Birim',
        'Mevcut Stok',
        'Kritik Sınır',
        'Birim Maliyet (TL)',
        'Stok Değeri (TL)',
        'İşlem Durumu',
        'Yönetici Mesajı',
      ],
      ...inventory.products.map(
        (p) => [
          p.sku,
          p.name,
          p.category,
          p.unit,
          inventory.quantity(p.id),
          p.threshold,
          p.cost,
          inventory.quantity(p.id) * p.cost,
          p.isFrozen ? 'Donduruldu' : 'Açık',
          p.adminMessage,
        ],
      ),
    ],
    'Dönem Hareketleri': [
      [
        'Kayıt ID',
        'Tarih',
        'Ürün',
        'Kullanıcı',
        'İşlem',
        'Miktar Değişimi',
        'Değer Değişimi (TL)',
        'Açıklama',
      ],
      ...movements.map(
        (e) => [
          e.id,
          e.at.toLocal().toIso8601String(),
          e.productName,
          e.actorName,
          e.kind,
          e.delta,
          e.valueDelta,
          e.note,
        ],
      ),
    ],
    'Dönem Tüketimi': [
      ['Ürün', 'Birim', 'Tüketilen Miktar'],
      ...inventory.products.map(
        (p) => [p.name, p.unit, inventory.consumption(p.id, start, end)],
      ),
    ],
  };
}

Future<String> exportReport(
  Inventory inventory,
  DateTime month, {
  required bool xlsx,
}) async {
  final tables = reportTables(inventory, month);
  final name =
      'stok_raporu_${month.year}_${month.month.toString().padLeft(2, '0')}';
  late List<int> bytes;
  if (xlsx) {
    final book = Excel.createExcel();
    for (final table in tables.entries) {
      final sheet = book[table.key];
      for (final row in table.value) {
        sheet.appendRow(
          row
              .map<CellValue?>(
                (v) => v is num
                    ? DoubleCellValue(v.toDouble())
                    : TextCellValue(v?.toString() ?? ''),
              )
              .toList(),
        );
      }
      for (var col = 0; col < table.value.first.length; col++) {
        sheet.setColumnWidth(col, 24);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
            .cellStyle = CellStyle(
          bold: true,
        );
      }
    }
    book.delete('Sheet1');
    book.setDefaultSheet(tables.keys.first);
    bytes = book.encode()!;
  } else {
    bytes = utf8.encode(
      csvEncode([
        for (final t in tables.entries) ...[
          <Object?>[t.key],
          ...t.value,
          <Object?>[],
        ],
      ]),
    );
  }
  return FileSaver.instance
      .saveAs(
        name: name,
        bytes: Uint8List.fromList(bytes),
        fileExtension: xlsx ? 'xlsx' : 'csv',
        mimeType: xlsx ? MimeType.microsoftExcel : MimeType.csv,
      )
      .then((value) => value ?? 'İşlem iptal edildi');
}
