import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../l10n.dart';
import '../../models.dart';
import '../../state.dart';
import '../../widgets.dart';
import '../customer/order_screen.dart';

class RestaurantHome extends StatefulWidget {
  const RestaurantHome({super.key});

  @override
  State<RestaurantHome> createState() => _RestaurantHomeState();
}

class _RestaurantHomeState extends State<RestaurantHome> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final titles = [context.tr('active_orders'), context.tr('menu'), context.tr('history'), context.tr('account')];
    return Scaffold(
      appBar: AppBar(title: Text(titles[_tab])),
      body: switch (_tab) {
        0 => const _ActiveOrders(),
        1 => const _MenuManager(),
        2 => const _History(),
        _ => const _RestaurantAccount(),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.notifications_active_outlined), label: context.tr('orders')),
          NavigationDestination(icon: const Icon(Icons.restaurant_menu), label: context.tr('menu')),
          NavigationDestination(icon: const Icon(Icons.history), label: context.tr('history')),
          NavigationDestination(icon: const Icon(Icons.storefront_outlined), label: context.tr('account')),
        ],
      ),
    );
  }
}

class _ActiveOrders extends StatelessWidget {
  const _ActiveOrders();

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return DataView<List<Order>>(
      pollEvery: const Duration(seconds: 5),
      load: () async => parseList(await api.get('/restaurant/orders?status=active'), Order.fromJson),
      builder: (context, orders, reload) {
        Future<void> set(Order o, String status) async {
          await api.post('/restaurant/orders/${o.id}/status', {'status': status});
          await reload();
        }

        return RefreshList(
          onRefresh: reload,
          empty: MessageView(icon: Icons.inbox_outlined, text: context.tr('no_orders')),
          children: [
            for (final o in orders)
              OrderCard(
                order: o,
                showRestaurant: false,
                actions: switch (o.status) {
                  'pending' => [
                      AsyncButton(label: context.tr('act_reject'), danger: true, onPressed: () => set(o, 'rejected')),
                      AsyncButton(label: context.tr('act_accept'), onPressed: () => set(o, 'accepted')),
                    ],
                  'accepted' => [AsyncButton(label: context.tr('act_preparing'), onPressed: () => set(o, 'preparing'))],
                  'preparing' => [AsyncButton(label: context.tr('act_ready'), onPressed: () => set(o, 'ready'))],
                  _ => const <Widget>[],
                },
              ),
          ],
        );
      },
    );
  }
}

class _History extends StatelessWidget {
  const _History();

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return DataView<List<Order>>(
      load: () async => parseList(await api.get('/restaurant/orders'), Order.fromJson),
      builder: (context, orders, reload) => RefreshList(
        onRefresh: reload,
        empty: MessageView(icon: Icons.history, text: context.tr('no_orders')),
        children: [
          for (final o in orders)
            OrderCard(
              order: o,
              showRestaurant: false,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderScreen(orderId: o.id))),
            ),
        ],
      ),
    );
  }
}

class _MenuManager extends StatelessWidget {
  const _MenuManager();

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return DataView<List<MenuItem>>(
      load: () async => parseList(await api.get('/restaurant/menu'), MenuItem.fromJson),
      builder: (context, items, reload) => Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            if (await showMenuItemForm(context) == true) reload();
          },
          icon: const Icon(Icons.add),
          label: Text(context.tr('add_item')),
        ),
        body: RefreshList(
          onRefresh: reload,
          empty: MessageView(icon: Icons.restaurant_menu, text: context.tr('add_item')),
          children: [
            for (final m in items)
              Card(
                child: ListTile(
                  title: Text(context.pick(m.nameEn, m.nameAr)),
                  subtitle: Text('${context.pick(m.sectionEn, m.sectionAr)} · ${context.money(m.price)}'),
                  onTap: () async {
                    if (await showMenuItemForm(context, item: m) == true) reload();
                  },
                  trailing: Switch(
                    value: m.available,
                    onChanged: (v) async {
                      try {
                        await api.patch('/restaurant/menu/${m.id}', {'available': v});
                        reload();
                      } catch (e) {
                        if (context.mounted) showError(context, e);
                      }
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Add/edit dialog for a menu item. Returns true when something changed.
Future<bool?> showMenuItemForm(BuildContext context, {MenuItem? item}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _MenuItemForm(item: item),
    ),
  );
}

class _MenuItemForm extends StatefulWidget {
  const _MenuItemForm({this.item});
  final MenuItem? item;

  @override
  State<_MenuItemForm> createState() => _MenuItemFormState();
}

class _MenuItemFormState extends State<_MenuItemForm> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c;

  @override
  void initState() {
    super.initState();
    final m = widget.item;
    _c = {
      'name_en': TextEditingController(text: m?.nameEn),
      'name_ar': TextEditingController(text: m?.nameAr),
      'desc_en': TextEditingController(text: m?.descEn),
      'desc_ar': TextEditingController(text: m?.descAr),
      'section_en': TextEditingController(text: m?.sectionEn ?? 'Menu'),
      'section_ar': TextEditingController(text: m?.sectionAr ?? 'القائمة'),
      'price': TextEditingController(text: m == null ? '' : m.price.toString()),
    };
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final api = context.read<AppState>().api;
    final body = {
      for (final e in _c.entries) e.key: e.key == 'price' ? double.parse(e.value.text.trim()) : e.value.text.trim(),
    };
    if (widget.item == null) {
      await api.post('/restaurant/menu', body);
    } else {
      await api.patch('/restaurant/menu/${widget.item!.id}', body);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    String? req(String? v) => (v == null || v.trim().isEmpty) ? context.tr('required') : null;
    Widget field(String key, {String? Function(String?)? validator, TextInputType? type, TextDirection? dir}) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextFormField(
            controller: _c[key],
            keyboardType: type,
            textDirection: dir,
            decoration: InputDecoration(labelText: context.tr(key), isDense: true),
            validator: validator,
          ),
        );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(context.tr(widget.item == null ? 'add_item' : 'edit_item'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            field('name_en', validator: req, dir: TextDirection.ltr),
            field('name_ar', validator: req, dir: TextDirection.rtl),
            field('desc_en', dir: TextDirection.ltr),
            field('desc_ar', dir: TextDirection.rtl),
            Row(children: [
              Expanded(child: field('section_en', dir: TextDirection.ltr)),
              const SizedBox(width: 8),
              Expanded(child: field('section_ar', dir: TextDirection.rtl)),
            ]),
            field('price',
                type: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => (double.tryParse(v?.trim() ?? '') ?? 0) > 0 ? null : context.tr('required')),
            const SizedBox(height: 8),
            Row(children: [
              if (widget.item != null)
                AsyncButton(
                  label: context.tr('delete'),
                  danger: true,
                  onPressed: () async {
                    if (!await confirm(context, context.tr('delete_item_q'))) return;
                    if (!context.mounted) return;
                    await context.read<AppState>().api.delete('/restaurant/menu/${widget.item!.id}');
                    if (context.mounted) Navigator.pop(context, true);
                  },
                ),
              const Spacer(),
              AsyncButton(label: context.tr('save'), onPressed: _save),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _RestaurantAccount extends StatelessWidget {
  const _RestaurantAccount();

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return DataView<(Restaurant, Map<String, dynamic>)>(
      load: () async => (
        Restaurant.fromJson(await api.get('/restaurant/me') as Map<String, dynamic>),
        await api.get('/restaurant/stats') as Map<String, dynamic>,
      ),
      builder: (context, data, reload) {
        final (r, stats) = data;
        final today = stats['today'] as Map<String, dynamic>;
        final all = stats['all_time'] as Map<String, dynamic>;
        return AccountView(children: [
          Card(
            child: SwitchListTile(
              secondary: RestaurantLogo(restaurant: r, size: 44),
              title: Text(context.pick(r.nameEn, r.nameAr), style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(r.isOpen ? context.tr('restaurant_open') : context.tr('closed'),
                  style: TextStyle(color: r.isOpen ? Colors.green : Colors.red)),
              value: r.isOpen,
              onChanged: (v) async {
                try {
                  await api.patch('/restaurant/me', {'is_open': v});
                  reload();
                } catch (e) {
                  if (context.mounted) showError(context, e);
                }
              },
            ),
          ),
          StatGrid(tiles: [
            StatTile(label: '${context.tr('orders')} · ${context.tr('today')}', value: '${today['orders']}', icon: Icons.receipt),
            StatTile(label: '${context.tr('revenue')} · ${context.tr('today')}', value: context.money(today['revenue'] as num), icon: Icons.payments),
            StatTile(label: '${context.tr('orders')} · ${context.tr('all_time')}', value: '${all['orders']}', icon: Icons.receipt_long),
            StatTile(label: '${context.tr('revenue')} · ${context.tr('all_time')}', value: context.money(all['revenue'] as num), icon: Icons.account_balance_wallet),
            StatTile(label: context.tr('active_orders'), value: '${stats['active']}', icon: Icons.local_fire_department),
            StatTile(label: context.tr('commission'), value: '${stats['commission_pct']}%', icon: Icons.percent),
          ]),
        ]);
      },
    );
  }
}
