import 'package:delivery_app/l10n.dart';
import 'package:delivery_app/models.dart';
import 'package:delivery_app/screens/auth/login_screen.dart';
import 'package:delivery_app/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

Widget _wrap(Widget child, Locale locale) => MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => CartState()),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [AppStrings.delegate, ...GlobalMaterialLocalizations.delegates],
        home: child,
      ),
    );

void main() {
  testWidgets('login screen renders in English and Arabic (RTL)', (tester) async {
    await tester.pumpWidget(_wrap(const LoginScreen(), const Locale('en')));
    expect(find.text('Log in'), findsOneWidget);

    await tester.pumpWidget(_wrap(const LoginScreen(), const Locale('ar')));
    await tester.pumpAndSettle();
    expect(find.text('تسجيل الدخول'), findsWidgets);
    expect(Directionality.of(tester.element(find.byType(LoginScreen))), TextDirection.rtl);
  });

  test('cart keeps one restaurant at a time and totals correctly', () {
    Restaurant r(int id) => Restaurant.fromJson({'id': id, 'name_en': 'R$id', 'name_ar': 'م$id'});
    MenuItem m(int id, int rid, num price) =>
        MenuItem.fromJson({'id': id, 'restaurant_id': rid, 'name_en': 'I$id', 'name_ar': 'ص$id', 'price': price, 'available': 1});

    final cart = CartState();
    cart.add(r(1), m(1, 1, 10));
    cart.add(r(1), m(1, 1, 10));
    cart.add(r(1), m(2, 1, 25.5));
    expect(cart.count, 3);
    expect(cart.subtotal, 45.5);

    expect(cart.belongsTo(r(2)), isFalse);
    cart.add(r(2), m(3, 2, 7)); // switching restaurant clears the cart
    expect(cart.count, 1);
    expect(cart.restaurant!.id, 2);

    cart.remove(m(3, 2, 7));
    expect(cart.count, 0);
    expect(cart.restaurant, isNull);
  });

  test('server timestamps are parsed as UTC', () {
    final t = parseServerTime('2026-01-02 03:04:05');
    expect(t.toUtc(), DateTime.utc(2026, 1, 2, 3, 4, 5));
  });
}
