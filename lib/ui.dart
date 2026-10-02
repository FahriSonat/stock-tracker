import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'domain.dart';
import 'export.dart';
import 'store.dart';

final money = NumberFormat.currency(
  locale: 'tr_TR',
  symbol: '₺',
  decimalDigits: 2,
);
final number = NumberFormat.decimalPattern('tr_TR');
String date(DateTime d) =>
    DateFormat('dd MMM yyyy', 'tr_TR').format(d.toLocal());
String kindName(String kind) =>
    const {
      'in': 'Stok girişi',
      'out': 'Stok çıkışı',
      'create': 'Ürün eklendi',
      'edit': 'Ürün düzenlendi',
    }[kind] ??
    kind;
double parseNumber(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.')) ?? double.nan;

Future<T?> managedDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) async {
  final route = DialogRoute<T>(
    context: context,
    builder: builder,
    barrierDismissible: barrierDismissible,
  );
  final result = await Navigator.of(context, rootNavigator: true).push(route);
  await route.completed;
  return result;
}

Future<void> runAction(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (context.mounted && success != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }
}

class LoginPage extends StatefulWidget {
  final AppStore store;
  const LoginPage({super.key, required this.store});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController();
  bool waiting = false, offline = false;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() => waiting = true);
    await runAction(context, () async {
      if (widget.store.firstRun) {
        await widget.store.createAccount(name.text, email.text, password.text);
      }
      await widget.store.login(email.text, password.text, offline: offline);
    });
    if (mounted) setState(() => waiting = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Brand(),
              const SizedBox(height: 44),
              Text(
                widget.store.firstRun
                    ? 'Her şey kontrolünüzde.'
                    : 'Tekrar hoş geldiniz.',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 12),
              Text(
                widget.store.firstRun
                    ? 'Stoklarınızı, hareketlerinizi ve ekibinizi tek yerden yönetin. İlk yönetici hesabınızı oluşturun.'
                    : 'Çalışma alanınıza giriş yaparak kaldığınız yerden devam edin.',
              ),
              const SizedBox(height: 28),
              if (widget.store.firstRun) ...[
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Ad soyad'),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.username],
                decoration: const InputDecoration(
                  labelText: 'E-posta',
                  prefixIcon: Icon(Icons.alternate_email),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: password,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) {
                  if (!waiting) submit();
                },
                decoration: const InputDecoration(
                  labelText: 'Parola',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              if (cloudEnabled)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: offline,
                  onChanged: (v) => setState(() => offline = v!),
                  title: const Text('Çevrimdışı giriş'),
                  subtitle: const Text(
                    'Bu cihazda son 7 gün içinde giriş yapılmış olmalı.',
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: waiting ? null : submit,
                  child: Text(
                    waiting
                        ? 'Lütfen bekleyin…'
                        : widget.store.firstRun
                        ? 'Çalışma alanını oluştur'
                        : 'Giriş yap',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  cloudEnabled
                      ? 'Bulut bağlantılı çalışma alanı'
                      : 'Çevrimdışı hazır • Veriler bu cihazda saklanır',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class Brand extends StatelessWidget {
  const Brand({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 180,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.layers_rounded,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'stok',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          Text(
            'pilot',
            style: TextStyle(
              fontSize: 24,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    ),
  );
}

class StockHome extends StatefulWidget {
  final AppStore store;
  const StockHome({super.key, required this.store});
  @override
  State<StockHome> createState() => _StockHomeState();
}

class _StockHomeState extends State<StockHome> with WidgetsBindingObserver {
  int page = 0;
  String query = '', filter = 'Tümü';
  final search = TextEditingController();
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  static const titles = [
    'Genel bakış',
    'Ürünler',
    'Hareketler',
    'Raporlar',
    'Ayarlar',
  ];
  static const icons = [
    Icons.grid_view_rounded,
    Icons.inventory_2_outlined,
    Icons.swap_horiz_rounded,
    Icons.bar_chart_rounded,
    Icons.settings_outlined,
  ];
  AppStore get s => widget.store;
  Inventory get inv => s.inventory;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    search.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) s.sync();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    return Scaffold(
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: page,
              onDestinationSelected: (v) => setState(() => page = v),
              destinations: [
                for (var i = 0; i < titles.length; i++)
                  NavigationDestination(icon: Icon(icons[i]), label: titles[i]),
              ],
            ),
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              Container(
                width: 236,
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Brand(),
                    const SizedBox(height: 44),
                    Text(
                      'ÇALIŞMA ALANI',
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 16),
                    for (var i = 0; i < titles.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          selected: page == i,
                          selectedTileColor: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: .09),
                          leading: Icon(icons[i]),
                          title: Text(titles[i]),
                          onTap: () => setState(() => page = i),
                        ),
                      ),
                    const Spacer(),
                    const Divider(),
                    const SizedBox(height: 12),
                    Text(
                      s.user!['name'],
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(s.isAdmin ? 'Yönetici' : 'Çalışan'),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: s.busy
                          ? null
                          : () => runAction(context, s.logout),
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Çıkış yap'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: wide ? 36 : 20,
                      vertical: 18,
                    ),
                    color: Theme.of(context).colorScheme.surface,
                    child: Row(
                      children: [
                        if (!wide) ...[
                          const Brand(),
                          const Spacer(),
                        ] else ...[
                          Text(
                            'Çalışma alanım',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                        ],
                        if (wide) Text(date(DateTime.now())),
                        const SizedBox(width: 16),
                        IconButton(
                          tooltip: 'Görünümü değiştir',
                          onPressed: () => s.toggleDark(!s.dark),
                          icon: Icon(
                            s.dark
                                ? Icons.light_mode_outlined
                                : Icons.dark_mode_outlined,
                          ),
                        ),
                        Badge(
                          label: Text('${inv.lowStock.length}'),
                          isLabelVisible: inv.lowStock.isNotEmpty,
                          child: IconButton(
                            tooltip: 'Düşük stoklar',
                            onPressed: () => setState(() {
                              page = 1;
                              filter = 'Düşük stok';
                            }),
                            icon: const Icon(Icons.notifications_none_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (s.busy) const LinearProgressIndicator(minHeight: 2),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(wide ? 36 : 20),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1450),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 24,
                                runSpacing: 14,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        titles[page],
                                        style: Theme.of(
                                          context,
                                        ).textTheme.headlineLarge,
                                      ),
                                      const SizedBox(height: 7),
                                      Text(
                                        [
                                          'İşletmenizin nabzı, tek bir ekranda.',
                                          'Her ürün, her detay, güncel stok.',
                                          'Stoklarınızdaki değişimin izini sürün.',
                                          'Verilerinizi daha iyi kararlara dönüştürün.',
                                          'Çalışma alanınızı kendinize göre düzenleyin.',
                                        ][page],
                                      ),
                                    ],
                                  ),
                                  if (page < 2 && s.isAdmin)
                                    FilledButton.icon(
                                      onPressed: s.busy
                                          ? null
                                          : () => productDialog(),
                                      icon: const Icon(Icons.add),
                                      label: const Text('Yeni ürün'),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 26),
                              if (page == 0) dashboard(),
                              if (page == 1) productsPage(),
                              if (page == 2) historyPage(),
                              if (page == 3) reportsPage(),
                              if (page == 4) settingsPage(),
                              const SizedBox(height: 28),
                              Row(
                                children: [
                                  Icon(
                                    cloudEnabled
                                        ? Icons.cloud_outlined
                                        : Icons.offline_bolt_outlined,
                                    size: 16,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${s.syncMessage}${s.pending.isEmpty ? '' : ' • ${s.pending.length} bekleyen işlem'}',
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                                  if (cloudEnabled)
                                    IconButton(
                                      tooltip: 'Senkronize et',
                                      onPressed: s.busy ? null : s.sync,
                                      icon: const Icon(Icons.sync, size: 20),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget panel(
    String title,
    Widget child, {
    String? subtitle,
    Widget? action,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ?action,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 22),
          child,
        ],
      ),
    ),
  );
  Widget empty(String message) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 30),
    child: Center(
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 40,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
  Widget metrics(List<(String, String, IconData, String)> data) =>
      LayoutBuilder(
        builder: (context, c) {
          final cols = c.maxWidth > 1000
              ? 4
              : c.maxWidth > 450
              ? 2
              : 1;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: data
                .map(
                  (d) => SizedBox(
                    width: (c.maxWidth - 16 * (cols - 1)) / cols,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(d.$1)),
                                Icon(
                                  d.$3,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 22,
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            FittedBox(
                              child: Text(
                                d.$2,
                                style: const TextStyle(
                                  fontSize: 29,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -.8,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              d.$4,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      );
  Widget split(Widget left, Widget right) => LayoutBuilder(
    builder: (context, c) => c.maxWidth > 800
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: left),
              const SizedBox(width: 20),
              Expanded(flex: 2, child: right),
            ],
          )
        : Column(children: [left, const SizedBox(height: 20), right]),
  );

  Widget dashboard() {
    final now = DateTime.now();
    final monthEvents = inv.during(
      DateTime(now.year, now.month),
      now.add(const Duration(seconds: 1)),
    );
    final recent = List<Product>.from(s.products)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        metrics([
          (
            'Toplam stok değeri',
            money.format(inv.totalValue),
            Icons.account_balance_wallet_outlined,
            'Güncel alış maliyeti',
          ),
          (
            'Ürün çeşidi',
            '${s.products.length}',
            Icons.inventory_2_outlined,
            'Kayıtlı ürün sayısı',
          ),
          (
            'Düşük stok',
            '${inv.lowStock.length}',
            Icons.warning_amber_rounded,
            'Takip edilmesi gereken ürün',
          ),
          (
            'Bu ay hareket',
            '${monthEvents.where((e) => e.delta != 0).length}',
            Icons.swap_horiz,
            'Giriş ve çıkış işlemleri',
          ),
        ]),
        const SizedBox(height: 24),
        if (inv.lowStock.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF5B95B).withValues(alpha: .15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFBC7B20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    '${inv.lowStock.length} ürün için stok yenileme zamanı. Stok seviyelerini gözden geçirin.',
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    page = 1;
                    filter = 'Düşük stok';
                  }),
                  child: const Text('İncele'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        split(
          panel(
            'Stok değeri',
            valueChart(DateTime(now.year, now.month)),
            subtitle: 'Bu ay • Gün sonu alış maliyeti',
          ),
          panel(
            'En çok tüketilenler',
            consumptionChart(DateTime(now.year, now.month)),
            subtitle: 'Bu ay • Ürünlerin kendi birimlerine göre',
          ),
        ),
        const SizedBox(height: 24),
        split(
          panel(
            'Son hareketler',
            eventList(
              (List<StockEvent>.from(
                s.events,
              )..sort((a, b) => b.at.compareTo(a.at))).take(5).toList(),
            ),
            action: TextButton(
              onPressed: () => setState(() => page = 2),
              child: const Text('Tümü'),
            ),
          ),
          panel(
            'Son eklenen ürünler',
            recent.isEmpty
                ? empty('İlk ürününüzü ekleyerek başlayın.')
                : Column(children: recent.take(5).map(productTile).toList()),
          ),
        ),
        if (s.products.isEmpty && s.isAdmin && !cloudEnabled) ...[
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: s.busy ? null : () => runAction(context, s.seedExample),
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Örnek ürünlerle keşfet'),
          ),
        ],
      ],
    );
  }

  Widget valueChart(DateTime selected) {
    if (s.events.isEmpty) {
      return empty('Hareket eklediğinizde grafik burada görünecek.');
    }
    final now = DateTime.now();
    final count = selected.year == now.year && selected.month == now.month
        ? now.day
        : DateTime(selected.year, selected.month + 1, 0).day;
    final spots = List.generate(
      count,
      (i) => FlSpot(
        (i + 1).toDouble(),
        inv.valueAt(DateTime(selected.year, selected.month, i + 2)),
      ),
    );
    if (spots.length == 1) spots.insert(0, FlSpot(0, inv.valueAt(selected)));
    return SizedBox(
      height: 235,
      child: LineChart(
        LineChartData(
          minY: 0,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: max(1, (count / 5).ceil()).toDouble(),
                getTitlesWidget: (v, meta) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${v.toInt()}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 55,
                getTitlesWidget: (v, meta) => Text(
                  NumberFormat.compact(locale: 'tr_TR').format(v),
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots
                  .map(
                    (s) => LineTooltipItem(
                      '${s.x.toInt()}. gün\n${money.format(s.y)}',
                      const TextStyle(color: Colors.white),
                    ),
                  )
                  .toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              color: Theme.of(context).colorScheme.primary,
              barWidth: 3,
              isCurved: false,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: .22),
                    Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: .01),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget consumptionChart(DateTime selected) {
    final end = DateTime(selected.year, selected.month + 1);
    final ranked =
        s.products
            .map((p) => (p, inv.consumption(p.id, selected, end)))
            .where((r) => r.$2 > 0)
            .toList()
          ..sort((a, b) => b.$2.compareTo(a.$2));
    final top = ranked.take(5).toList();
    if (top.isEmpty) return empty('Bu dönemde tüketim kaydı yok.');
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (g, i, rod, ri) => BarTooltipItem(
                    '${top[i].$1.name}\n${number.format(rod.toY)} ${top[i].$1.unit}',
                    const TextStyle(color: Colors.white),
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < top.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: top[i].$2,
                        width: 28,
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 1 - i * .13),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...top.map(
          (r) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Expanded(child: Text(r.$1.name)),
                Text(
                  '${number.format(r.$2)} ${r.$1.unit}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget productTile(Product p) {
    final qty = inv.quantity(p.id), low = inv.quantity(p.id) <= p.threshold;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => details(p),
      leading: CircleAvatar(
        backgroundColor: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: .1),
        child: Icon(
          Icons.inventory_2_outlined,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Text(p.name),
      subtitle: Text(
        '${p.sku} · Kritik sınır: ${number.format(p.threshold)} ${p.unit}'
        '${p.isFrozen ? "\n⛔ STOK İŞLEMLERİ DONDURULDU" : ""}'
        '${p.adminMessage.isEmpty ? "" : "\nYönetici: ${p.adminMessage}"}',
      ),
      trailing: Text(
        '${number.format(qty)} ${p.unit}',
        style: TextStyle(
          color: low ? const Color(0xFFBE8228) : null,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget productsPage() {
    final list =
        s.products
            .where(
              (p) =>
                  '${p.name} ${p.sku} ${p.category}'.toLowerCase().contains(
                    query.toLowerCase(),
                  ) &&
                  (filter != 'Düşük stok' ||
                      inv.quantity(p.id) <= p.threshold) &&
                  (filter != 'Dondurulanlar' || p.isFrozen),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: search,
          decoration: InputDecoration(
            hintText: 'Ürün adı, stok kodu veya kategori ara…',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              tooltip: 'Aramayı temizle',
              onPressed: () {
                search.clear();
                setState(() => query = '');
              },
              icon: const Icon(Icons.close),
            ),
          ),
          onChanged: (v) => setState(() => query = v),
          onSubmitted: s.rememberSearch,
        ),
        const SizedBox(height: 12),
        if (s.searches.isNotEmpty)
          Wrap(
            spacing: 8,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text('Son aramalar:'),
              ),
              ...s.searches.map(
                (q) => ActionChip(
                  label: Text(q),
                  onPressed: () => setState(() {
                    query = q;
                    search.text = q;
                  }),
                ),
              ),
              IconButton(
                tooltip: 'Arama geçmişini temizle',
                onPressed: s.clearSearches,
                icon: const Icon(Icons.clear_all),
              ),
            ],
          ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: ['Tümü', 'Düşük stok', 'Dondurulanlar']
              .map(
                (f) => ChoiceChip(
                  label: Text(f),
                  selected: filter == f,
                  onSelected: (_) => setState(() => filter = f),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 20),
        panel(
          '${list.length} ürün',
          list.isEmpty
              ? empty('Bu görünümde ürün bulunamadı.')
              : LayoutBuilder(
                  builder: (context, c) {
                    if (c.maxWidth < 650) {
                      return Column(children: list.map(productTile).toList());
                    }
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: c.maxWidth),
                        child: DataTable(
                          horizontalMargin: 0,
                          columnSpacing: 20,
                          columns: const [
                            DataColumn(label: Text('ÜRÜN')),
                            DataColumn(label: Text('STOK'), numeric: true),
                            DataColumn(label: Text('MALİYET'), numeric: true),
                            DataColumn(label: Text('DURUM')),
                            DataColumn(label: Text('KRİTİK SINIR')),
                            DataColumn(label: Text('YÖNETİCİ MESAJI')),
                            DataColumn(label: Text('')),
                          ],
                          rows: list.map((p) {
                            final low = inv.quantity(p.id) <= p.threshold;
                            return DataRow(
                              cells: [
                                DataCell(
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '${p.sku} · ${p.category}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                  onTap: () => details(p),
                                ),
                                DataCell(
                                  Text(
                                    '${number.format(inv.quantity(p.id))} ${p.unit}',
                                  ),
                                ),
                                DataCell(Text(money.format(p.cost))),
                                DataCell(
                                  Chip(
                                    label: Text(
                                      p.isFrozen
                                          ? '⛔ Donduruldu'
                                          : low
                                          ? 'Kritik stok'
                                          : 'Yeterli',
                                    ),
                                    side: BorderSide.none,
                                    backgroundColor:
                                        (p.isFrozen
                                                ? Colors.red
                                                : low
                                                ? Colors.orange
                                                : Colors.teal)
                                            .withValues(alpha: .1),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    '${number.format(p.threshold)} ${p.unit}',
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 190,
                                    child: Text(
                                      p.adminMessage.isEmpty
                                          ? '—'
                                          : p.adminMessage,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  onTap: () => details(p),
                                ),
                                DataCell(
                                  IconButton(
                                    tooltip: p.isFrozen
                                        ? 'Stok işlemleri donduruldu'
                                        : s.isAdmin
                                        ? 'Stok giriş / çıkışı'
                                        : 'Stok çıkışı',
                                    onPressed: s.busy || p.isFrozen
                                        ? null
                                        : () => movementDialog(p),
                                    icon: const Icon(Icons.swap_horiz),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget eventList(List<StockEvent> list) => list.isEmpty
      ? empty('Henüz hareket kaydı yok.')
      : Column(
          children: list
              .map(
                (e) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: (e.delta < 0 ? Colors.orange : Colors.teal)
                        .withValues(alpha: .1),
                    child: Icon(
                      e.delta == 0
                          ? Icons.edit_outlined
                          : e.delta > 0
                          ? Icons.south_west
                          : Icons.north_east,
                      color: e.delta < 0 ? Colors.orange : Colors.teal,
                      size: 20,
                    ),
                  ),
                  title: Text(e.productName),
                  subtitle: Text(
                    '${kindName(e.kind)} · ${e.actorName}\n${DateFormat('dd MMM HH:mm', 'tr_TR').format(e.at.toLocal())}${e.note.isEmpty ? '' : ' · ${e.note}'}',
                  ),
                  isThreeLine: true,
                  trailing: Text(
                    e.delta == 0
                        ? '—'
                        : '${e.delta > 0 ? '+' : ''}${number.format(e.delta)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: e.delta < 0 ? Colors.orange : Colors.teal,
                    ),
                  ),
                ),
              )
              .toList(),
        );
  Widget monthPicker() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: 'Önceki ay',
        onPressed: () =>
            setState(() => month = DateTime(month.year, month.month - 1)),
        icon: const Icon(Icons.chevron_left),
      ),
      Text(
        DateFormat('MMMM yyyy', 'tr_TR').format(month),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      IconButton(
        tooltip: 'Sonraki ay',
        onPressed: DateTime(month.year, month.month + 1).isAfter(DateTime.now())
            ? null
            : () =>
                  setState(() => month = DateTime(month.year, month.month + 1)),
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
  Widget historyPage() {
    final list = inv.during(month, DateTime(month.year, month.month + 1))
      ..sort((a, b) => b.at.compareTo(a.at));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        monthPicker(),
        const SizedBox(height: 16),
        panel(
          'İşlem geçmişi',
          eventList(list),
          subtitle:
              'Kim, ne zaman, ne kadar • Kayıtlar silinmez; düzeltmeler yeni hareketle yapılır.',
        ),
      ],
    );
  }

  Widget reportsPage() {
    final rows = inv.during(month, DateTime(month.year, month.month + 1));
    final incoming = rows
        .where((e) => e.kind == 'in')
        .fold(0.0, (v, e) => v + e.valueDelta);
    final outgoing = rows
        .where((e) => e.kind == 'out')
        .fold(0.0, (v, e) => v - e.valueDelta);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            monthPicker(),
            OutlinedButton.icon(
              onPressed: () => export(false),
              icon: const Icon(Icons.download_outlined),
              label: const Text('CSV indir'),
            ),
            FilledButton.icon(
              onPressed: () => export(true),
              icon: const Icon(Icons.table_chart_outlined),
              label: const Text('Excel indir'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        metrics([
          (
            'Açılış değeri',
            money.format(inv.valueAt(month)),
            Icons.account_balance_wallet_outlined,
            'Ay başındaki stok değeri',
          ),
          (
            'Stok girişleri',
            money.format(incoming),
            Icons.south_west,
            'Dönemdeki giriş maliyeti',
          ),
          (
            'Stok çıkışları',
            money.format(outgoing),
            Icons.north_east,
            'Dönemdeki tüketim maliyeti',
          ),
          (
            'Kapanış değeri',
            money.format(inv.valueAt(DateTime(month.year, month.month + 1))),
            Icons.payments_outlined,
            'Devam eden ay için bugüne kadar',
          ),
        ]),
        const SizedBox(height: 24),
        split(
          panel(
            'Stok değeri zaman grafiği',
            valueChart(month),
            subtitle: 'TL • Gün sonu',
          ),
          panel('En çok tüketilen ürünler', consumptionChart(month)),
        ),
        const SizedBox(height: 24),
        panel(
          'Tahmini stok tükenme tarihleri',
          s.products.isEmpty
              ? empty('Tahmin için ürün ekleyin.')
              : Column(
                  children: s.products.map((p) {
                    final estimate = inv.depletion(p, DateTime.now());
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(p.name),
                      subtitle: Text(
                        'Günlük ortalama: ${number.format(inv.averageDaily(p, DateTime.now()))} ${p.unit}',
                      ),
                      trailing: Text(
                        estimate == null
                            ? 'Yeterli veri yok'
                            : inv.quantity(p.id) <= 0
                            ? 'Stok tükendi'
                            : date(estimate),
                      ),
                    );
                  }).toList(),
                ),
          subtitle:
              'Güncel stok / son 30 günlük ortalama tüketim. Yeni ürünlerde gözlenen süre kullanılır; tahmin kesin değildir.',
        ),
        const SizedBox(height: 16),
        const Text(
          'Raporlar alış maliyetine dayanır. Çıkışlar satış ve iç tüketimi birlikte gösterir; satış geliri veya kâr hesabı içermez.',
        ),
      ],
    );
  }

  Future<void> export(bool xlsx) => runAction(context, () async {
    final result = await exportReport(inv, month, xlsx: xlsx);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Dışa aktarma: $result')));
    }
  });
  Widget settingsPage() => Column(
    children: [
      panel(
        'Tercihler',
        Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Koyu tema'),
              subtitle: const Text('Tercihiniz bu cihazda hatırlanır.'),
              value: s.dark,
              onChanged: s.toggleDark,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Düşük stok bildirimleri'),
              subtitle: const Text(
                'Stok eşik seviyesine indiğinde cihaz bildirimi. Web’de uygulama içi uyarı gösterilir.',
              ),
              value: s.box.get('notifications', defaultValue: false),
              onChanged: (v) => runAction(
                context,
                v ? s.enableNotifications : s.disableNotifications,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      panel(
        'Hesap ve çalışma alanı',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${s.user!['name']} · ${s.isAdmin ? 'Yönetici' : 'Çalışan'}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(s.user!['email']),
            const SizedBox(height: 20),
            Text(
              cloudEnabled
                  ? 'Bulut senkronizasyonu etkin. Bağlantı kesilirse kayıtlar cihazda sıraya alınır. Bekleyen kayıtlar sunucu tarafından onaylanana kadar geçicidir.'
                  : 'Yerel mod: hesaplar ve stoklar bu cihazda saklanır. Bulut kullanmak için kurulum kılavuzundaki Supabase ayarlarını ekleyin.',
            ),
            if (s.pending.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '${s.pending.length} işlem sunucu onayı bekliyor. ${s.syncMessage}',
              ),
              ...s.pending.map(
                (p) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(p['event']['productName']),
                  subtitle: Text(
                    '${kindName(p['event']['kind'])} · ${p['event']['actorName']}',
                  ),
                  trailing: Text(number.format(p['event']['delta'])),
                ),
              ),
              TextButton(
                onPressed: s.busy ? null : resolveConflict,
                child: const Text(
                  'Bekleyenleri iptal et ve sunucu verisini al',
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (cloudEnabled)
              OutlinedButton.icon(
                onPressed: s.busy ? null : s.sync,
                icon: const Icon(Icons.sync),
                label: const Text('Şimdi senkronize et'),
              ),
            if (s.isAdmin && !cloudEnabled) ...[
              const SizedBox(height: 16),
              ...s.accounts.map(
                (u) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline),
                  title: Text(u['name']),
                  subtitle: Text(u['email']),
                  trailing: Text(u['role'] == 'admin' ? 'Yönetici' : 'Çalışan'),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => accountDialog(),
                icon: const Icon(Icons.person_add_outlined),
                label: const Text('Çalışan ekle'),
              ),
            ],
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: s.busy ? null : () => runAction(context, s.logout),
              icon: const Icon(Icons.logout),
              label: const Text('Hesaptan çıkış yap'),
            ),
          ],
        ),
      ),
    ],
  );

  Future<void> resolveConflict() async {
    final confirmed = await managedDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sunucu verisine dönülsün mü?'),
        content: Text(
          '${s.pending.length} bekleyen öneri iptal edilecek. Sunucunun kabul ettiği hareketler korunur. İptal edilen öneriler cihazda arşivlenir; gerekli hareketleri güncel stok üzerinden yeniden girin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('İptal et ve yenile'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await runAction(context, s.useServerSnapshot);
    }
  }

  Widget productNotice(Product p) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: (p.isFrozen ? Colors.red : Colors.amber).withValues(alpha: .12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (p.isFrozen)
          const Text(
            '⛔ STOK İŞLEMLERİ DONDURULDU',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
          ),
        if (p.isFrozen)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Stok görünür; giriş ve çıkış kapalıdır. İşlemleri yalnızca admin yeniden açabilir.',
            ),
          ),
        if (p.adminMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Yönetici mesajı: ${p.adminMessage}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
      ],
    ),
  );

  Future<void> details(Product original) => managedDialog(
    context: context,
    builder: (ctx) => ListenableBuilder(
      listenable: s,
      builder: (ctx, _) {
        final p = s.products.firstWhere(
          (p) => p.id == original.id,
          orElse: () => original,
        );
        return AlertDialog(
          title: Text(p.name),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${p.sku} · ${p.category}'),
                  const SizedBox(height: 20),
                  if (p.isFrozen || p.adminMessage.isNotEmpty) ...[
                    productNotice(p),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'Mevcut stok: ${number.format(inv.quantity(p.id))} ${p.unit}',
                  ),
                  const SizedBox(height: 8),
                  Text('Kritik sınır: ${number.format(p.threshold)} ${p.unit}'),
                  const SizedBox(height: 8),
                  Text('Birim maliyet: ${money.format(p.cost)}'),
                  const SizedBox(height: 8),
                  Text('Eklenme: ${date(p.createdAt)}'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Kapat'),
            ),
            if (s.isAdmin)
              TextButton(
                onPressed: s.busy
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        productDialog(p);
                      },
                child: const Text('Düzenle'),
              ),
            FilledButton(
              onPressed: s.busy || p.isFrozen
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      movementDialog(p);
                    },
              child: Text(
                p.isFrozen
                    ? 'İşlemler donduruldu'
                    : s.isAdmin
                    ? 'Giriş / çıkış'
                    : 'Stok çıkışı',
              ),
            ),
          ],
        );
      },
    ),
  );

  Future<void> productDialog([Product? p]) async {
    bool frozen = p?.isFrozen ?? false;
    final fields = [
      TextEditingController(text: p?.name),
      TextEditingController(text: p?.sku),
      TextEditingController(text: p?.category ?? 'Genel'),
      TextEditingController(text: p?.unit ?? 'adet'),
      TextEditingController(text: p?.cost.toString() ?? '0'),
      TextEditingController(text: p?.threshold.toString() ?? '5'),
      TextEditingController(text: p?.adminMessage ?? ''),
    ];
    await editDialog(
      p == null ? 'Yeni ürün' : 'Ürünü düzenle',
      fields,
      [
        'Ürün adı',
        'Stok kodu',
        'Kategori',
        'Stok birimi',
        'Birim alış maliyeti (TL)',
        'Kritik sınır (seçilen birimde)',
        'Kullanıcılara yönetici mesajı (isteğe bağlı)',
      ],
      () async {
        await s.saveProduct(
          Product(
            id: p?.id ?? ids.v4(),
            name: fields[0].text.trim(),
            sku: fields[1].text.trim(),
            category: fields[2].text.trim(),
            unit: fields[3].text.trim(),
            cost: parseNumber(fields[4].text),
            threshold: parseNumber(fields[5].text),
            adminMessage: fields[6].text.trim(),
            isFrozen: frozen,
            createdAt: p?.createdAt ?? DateTime.now(),
          ),
        );
      },
      numericFrom: 4,
      productForm: true,
      extra: (update) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Stok işlemlerini dondur'),
        subtitle: const Text(
          'Admin dahil giriş ve çıkış kapanır. Stok ve mesaj görünür kalır.',
        ),
        value: frozen,
        onChanged: (value) => update(() => frozen = value),
      ),
    );
    for (final f in fields) {
      f.dispose();
    }
  }

  Future<void> movementDialog(Product original) async {
    final amount = TextEditingController(), note = TextEditingController();
    bool outgoing = !s.isAdmin, waiting = false;
    String? error;
    await managedDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ListenableBuilder(
        listenable: s,
        builder: (ctx, _) => StatefulBuilder(
          builder: (ctx, update) {
            final p = s.products.firstWhere(
              (p) => p.id == original.id,
              orElse: () => original,
            );
            final blocked = waiting || s.busy || p.isFrozen;
            return AlertDialog(
              title: Text(p.name),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (p.isFrozen || p.adminMessage.isNotEmpty) ...[
                        productNotice(p),
                        const SizedBox(height: 16),
                      ],
                      if (s.isAdmin)
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: false,
                              label: Text('Stok girişi'),
                              icon: Icon(Icons.south_west),
                            ),
                            ButtonSegment(
                              value: true,
                              label: Text('Stok çıkışı'),
                              icon: Icon(Icons.north_east),
                            ),
                          ],
                          selected: {outgoing},
                          onSelectionChanged: blocked
                              ? null
                              : (v) => update(() => outgoing = v.first),
                        )
                      else
                        const Text(
                          'Stok çıkışı',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      const SizedBox(height: 20),
                      Text(
                        'Mevcut: ${number.format(inv.quantity(p.id))} ${p.unit}',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Kritik sınır: ${number.format(p.threshold)} ${p.unit}',
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: amount,
                        enabled: !blocked,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Miktar (${p.unit})',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: note,
                        enabled: !blocked,
                        decoration: const InputDecoration(
                          labelText: 'Açıklama (isteğe bağlı)',
                        ),
                      ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            error!,
                            style: TextStyle(
                              color: Theme.of(ctx).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: waiting ? null : () => Navigator.pop(ctx),
                  child: const Text('Vazgeç'),
                ),
                FilledButton(
                  onPressed: blocked
                      ? null
                      : () async {
                          update(() {
                            waiting = true;
                            error = null;
                          });
                          try {
                            await s.move(
                              p,
                              parseNumber(amount.text),
                              s.isAdmin ? outgoing : true,
                              note.text,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            if (ctx.mounted) {
                              update(() {
                                waiting = false;
                                error = e.toString().replaceFirst(
                                  'Bad state: ',
                                  '',
                                );
                              });
                            }
                          }
                        },
                  child: Text(
                    p.isFrozen
                        ? 'İşlemler donduruldu'
                        : waiting
                        ? 'Kaydediliyor…'
                        : 'Hareketi kaydet',
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    amount.dispose();
    note.dispose();
  }

  Future<void> accountDialog() async {
    final fields = List.generate(3, (_) => TextEditingController());
    await editDialog(
      'Çalışan ekle',
      fields,
      ['Ad soyad', 'E-posta', 'Parola (en az 8 karakter)'],
      () => s.createAccount(fields[0].text, fields[1].text, fields[2].text),
      passwordIndex: 2,
    );
    for (final f in fields) {
      f.dispose();
    }
  }

  Future<void> editDialog(
    String title,
    List<TextEditingController> fields,
    List<String> labels,
    Future<void> Function() save, {
    int numericFrom = 999,
    int passwordIndex = -1,
    bool productForm = false,
    Widget Function(StateSetter)? extra,
  }) async {
    bool waiting = false;
    String? error;
    await managedDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < fields.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: productForm && i == 3
                          ? DropdownButtonFormField<String>(
                              initialValue: fields[i].text,
                              decoration: InputDecoration(
                                labelText: labels[i],
                                helperText:
                                    'Kritik sınır da bu birimle değerlendirilir.',
                              ),
                              items:
                                  {'adet', 'kg', 'lt', 'gram', fields[i].text}
                                      .map(
                                        (unit) => DropdownMenuItem(
                                          value: unit,
                                          child: Text(unit),
                                        ),
                                      )
                                      .toList(),
                              onChanged: waiting
                                  ? null
                                  : (value) =>
                                        update(() => fields[i].text = value!),
                            )
                          : TextField(
                              enabled: !waiting,
                              controller: fields[i],
                              obscureText: i == passwordIndex,
                              keyboardType:
                                  i >= numericFrom && i < numericFrom + 2
                                  ? const TextInputType.numberWithOptions(
                                      decimal: true,
                                    )
                                  : TextInputType.text,
                              decoration: InputDecoration(labelText: labels[i]),
                            ),
                    ),
                  if (extra != null) extra(update),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: waiting ? null : () => Navigator.pop(ctx),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: waiting
                  ? null
                  : () async {
                      update(() {
                        waiting = true;
                        error = null;
                      });
                      try {
                        await save();
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        if (ctx.mounted) {
                          update(() {
                            waiting = false;
                            error = e.toString().replaceFirst(
                              'Bad state: ',
                              '',
                            );
                          });
                        }
                      }
                    },
              child: Text(waiting ? 'Kaydediliyor…' : 'Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}
