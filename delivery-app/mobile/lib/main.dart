import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'l10n.dart';
import 'screens/admin/admin_home.dart';
import 'screens/auth/login_screen.dart';
import 'screens/customer/customer_home.dart';
import 'screens/driver/driver_home.dart';
import 'screens/restaurant/restaurant_home.dart';
import 'state.dart';
import 'widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()..init()),
        ChangeNotifierProvider(create: (_) => CartState()),
      ],
      child: const DeliveryApp(),
    ),
  );
}

class DeliveryApp extends StatelessWidget {
  const DeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return MaterialApp(
      title: 'Talabak',
      debugShowCheckedModeBanner: false,
      locale: app.locale,
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: const [AppStrings.delegate, ...GlobalMaterialLocalizations.delegates],
      theme: ThemeData(
        fontFamily: 'Cairo',
        colorScheme: ColorScheme.fromSeed(seedColor: brandColor, primary: brandColor),
        scaffoldBackgroundColor: const Color(0xFFF7F7F7),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.white, surfaceTintColor: Colors.white),
        cardTheme: const CardThemeData(color: Colors.white, elevation: 0, margin: EdgeInsets.all(4)),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
      ),
      home: !app.ready
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : switch (app.user?.role) {
              'customer' => const CustomerHome(),
              'restaurant' => const RestaurantHome(),
              'driver' => const DriverHome(),
              'admin' => const AdminHome(),
              _ => const LoginScreen(),
            },
    );
  }
}
