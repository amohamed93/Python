import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../l10n.dart';
import '../../models.dart';
import '../../state.dart';
import '../../widgets.dart';
import 'cart_screen.dart';

class RestaurantScreen extends StatelessWidget {
  const RestaurantScreen({super.key, required this.restaurantId});
  final int restaurantId;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return Scaffold(
      appBar: AppBar(),
      body: DataView<Restaurant>(
        load: () async => Restaurant.fromJson(await api.get('/restaurants/$restaurantId') as Map<String, dynamic>),
        builder: (context, r, reload) => _Menu(restaurant: r, onRefresh: reload),
      ),
      bottomNavigationBar: _CartBar(restaurantId: restaurantId),
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({required this.restaurant, required this.onRefresh});
  final Restaurant restaurant;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    // Group items by section, keeping server order.
    final sections = <String, List<MenuItem>>{};
    for (final m in r.menu) {
      sections.putIfAbsent(context.pick(m.sectionEn, m.sectionAr), () => []).add(m);
    }
    final grey = TextStyle(color: Colors.grey.shade700);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              RestaurantLogo(restaurant: r, size: 72),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(context.pick(r.nameEn, r.nameAr), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(context.pick(r.descEn, r.descAr), style: grey),
                  const SizedBox(height: 8),
                  Wrap(spacing: 14, runSpacing: 4, children: [
                    Text('★ ${r.rating.toStringAsFixed(1)}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                    Text('${r.deliveryTimeMin} ${context.tr('min')}', style: grey),
                    Text('${context.tr('delivery')}: ${context.money(r.deliveryFee)}', style: grey),
                    Text('${context.tr('min_order')}: ${context.money(r.minOrder)}', style: grey),
                  ]),
                ]),
              ),
            ]),
          ),
          if (!r.isOpen)
            Container(
              color: Colors.red.shade50,
              padding: const EdgeInsets.all(12),
              child: Text(context.tr('closed_now'), textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade800)),
            ),
          for (final entry in sections.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text(entry.key, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            for (final item in entry.value) _MenuItemTile(restaurant: r, item: item),
          ],
        ],
      ),
    );
  }
}

class _MenuItemTile extends StatelessWidget {
  const _MenuItemTile({required this.restaurant, required this.item});
  final Restaurant restaurant;
  final MenuItem item;

  Future<void> _add(BuildContext context) async {
    final cart = context.read<CartState>();
    if (!cart.belongsTo(restaurant)) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(c.tr('new_cart_title')),
          content: Text(c.tr('new_cart_body')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(c.tr('cancel'))),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(c.tr('new_cart'))),
          ],
        ),
      );
      if (ok != true) return;
    }
    cart.add(restaurant, item);
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartState>();
    final qty = cart.restaurant?.id == restaurant.id ? cart.qtyOf(item.id) : 0;
    final canOrder = restaurant.isOpen && item.available;
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.pick(item.nameEn, item.nameAr), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              if (item.descEn.isNotEmpty || item.descAr.isNotEmpty)
                Text(context.pick(item.descEn, item.descAr), style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              const SizedBox(height: 4),
              Text(context.money(item.price), style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
          ),
          if (!item.available)
            Text(context.tr('unavailable'), style: TextStyle(color: Colors.grey.shade500))
          else if (qty == 0)
            IconButton.filledTonal(
              tooltip: context.tr('add'),
              onPressed: canOrder ? () => _add(context) : null,
              icon: const Icon(Icons.add),
            )
          else
            QtyStepper(
              qty: qty,
              onAdd: () => cart.add(restaurant, item),
              onRemove: () => cart.remove(item),
            ),
        ],
      ),
    );
  }
}

class QtyStepper extends StatelessWidget {
  const QtyStepper({super.key, required this.qty, required this.onAdd, required this.onRemove});
  final int qty;
  final VoidCallback onAdd, onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: brandColor), borderRadius: BorderRadius.circular(24)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          tooltip: '−',
          visualDensity: VisualDensity.compact,
          onPressed: onRemove,
          icon: const Icon(Icons.remove, size: 18),
        ),
        Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold)),
        IconButton(
          tooltip: '+',
          visualDensity: VisualDensity.compact,
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 18),
        ),
      ]),
    );
  }
}

class _CartBar extends StatelessWidget {
  const _CartBar({required this.restaurantId});
  final int restaurantId;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartState>();
    if (cart.count == 0 || cart.restaurant?.id != restaurantId) return const SizedBox.shrink();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
          child: Row(children: [
            CircleAvatar(radius: 13, backgroundColor: Colors.white24, child: Text('${cart.count}', style: const TextStyle(color: Colors.white, fontSize: 13))),
            const SizedBox(width: 10),
            Text(context.tr('view_cart')),
            const Spacer(),
            Text(context.money(cart.subtotal)),
          ]),
        ),
      ),
    );
  }
}
