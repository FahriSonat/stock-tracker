import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notifications.dart';
import 'store.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Hive.initFlutter();
    if ((cloudUrl.isEmpty) != (cloudKey.isEmpty)) {
      throw StateError(
        'SUPABASE_URL ve SUPABASE_ANON_KEY birlikte tanımlanmalıdır.',
      );
    }
    if (cloudEnabled) {
      await Supabase.initialize(url: cloudUrl, publishableKey: cloudKey);
    }
    final box = await Hive.openBox(
      cloudEnabled
          ? 'stok_cloud_${Uri.parse(cloudUrl).host.replaceAll('.', '_')}'
          : 'stok_local',
    );
    final notifications = StockNotifications();
    try {
      await notifications.init();
    } catch (_) {
      /* App works without OS notifications. */
    }
    runApp(StockApp(store: AppStore(box, notifications)));
  } catch (e) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: SelectableText(
                'Uygulama başlatılamadı. Verileriniz silinmedi.\n$e',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StockApp extends StatelessWidget {
  final AppStore store;
  const StockApp({super.key, required this.store});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => MaterialApp(
      title: 'Stok Pilot',
      debugShowCheckedModeBanner: false,
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: appTheme(Brightness.light),
      darkTheme: appTheme(Brightness.dark),
      themeMode: store.dark ? ThemeMode.dark : ThemeMode.light,
      home: store.user == null
          ? LoginPage(store: store)
          : StockHome(store: store),
    ),
  );
}

ThemeData appTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF087F70),
    brightness: brightness,
    primary: dark ? const Color(0xFF6AD6BD) : const Color(0xFF087F70),
    surface: dark ? const Color(0xFF182321) : Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF101917)
        : const Color(0xFFF5F7F6),
    fontFamily: 'Segoe UI',
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .5)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textTheme: TextTheme(
      headlineLarge: const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -1,
      ),
      headlineSmall: const TextStyle(fontWeight: FontWeight.w700),
      titleMedium: const TextStyle(fontWeight: FontWeight.w600),
      bodyMedium: TextStyle(color: scheme.onSurface.withValues(alpha: .85)),
    ),
  );
}
