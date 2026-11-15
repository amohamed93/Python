import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../l10n.dart';
import '../../state.dart';
import '../../widgets.dart';
import 'cart_screen.dart';
import 'orders_tab.dart';
import 'restaurants_tab.dart';

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartState>();
    final titles = [context.tr('app_name'), context.tr('my_orders'), context.tr('account')];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_tab], style: _tab == 0 ? const TextStyle(color: brandColor, fontWeight: FontWeight.bold) : null),
        actions: [
          IconButton(
            tooltip: context.tr('cart'),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
            icon: Badge(
              isLabelVisible: cart.count > 0,
              label: Text('${cart.count}'),
              child: const Icon(Icons.shopping_bag_outlined),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          const RestaurantsTab(),
          // Rebuilt when selected so the list is fresh.
          _tab == 1 ? const OrdersTab() : const SizedBox(),
          const AccountView(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.storefront_outlined), label: context.tr('restaurants')),
          NavigationDestination(icon: const Icon(Icons.receipt_long_outlined), label: context.tr('orders')),
          NavigationDestination(icon: const Icon(Icons.person_outline), label: context.tr('account')),
        ],
      ),
    );
  }
}
