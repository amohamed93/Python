import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../l10n.dart';
import '../../models.dart';
import '../../state.dart';
import '../../widgets.dart';
import '../customer/order_screen.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final titles = [context.tr('overview'), context.tr('restaurants'), context.tr('orders'), context.tr('users'), context.tr('settings')];
    return Scaffold(
      appBar: AppBar(title: Text(titles[_tab])),
      body: switch (_tab) {
        0 => const _Overview(),
        1 => const _Restaurants(),
        2 => const _Orders(),
        3 => const _Users(),
        _ => const _Settings(),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: [
          NavigationDestination(icon: const Icon(Icons.dashboard_outlined), label: context.tr('overview')),
          NavigationDestination(icon: const Icon(Icons.storefront_outlined), label: context.tr('restaurants')),
          NavigationDestination(icon: const Icon(Icons.receipt_long_outlined), label: context.tr('orders')),
          NavigationDestination(icon: const Icon(Icons.people_outline), label: context.tr('users')),
          NavigationDestination(icon: const Icon(Icons.settings_outlined), label: context.tr('settings')),
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview();

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return DataView<Map<String, dynamic>>(
      pollEvery: const Duration(seconds: 15),
      load: () async => await api.get('/admin/stats') as Map<String, dynamic>,
      builder: (context, s, reload) => RefreshList(
        onRefresh: reload,
        children: [
          StatGrid(tiles: [
            StatTile(label: context.tr('orders_today'), value: '${s['orders_today']}', icon: Icons.today),
            StatTile(label: context.tr('orders_active'), value: '${s['orders_active']}', icon: Icons.local_fire_department),
            StatTile(label: context.tr('gmv'), value: context.money(s['gmv'] as num), icon: Icons.trending_up),
            StatTile(label: context.tr('platform_revenue'), value: context.money(s['platform_revenue'] as num), icon: Icons.account_balance),
            StatTile(label: context.tr('delivered_orders'), value: '${s['delivered_orders']}', icon: Icons.check_circle_outline),
            StatTile(label: context.tr('orders_total'), value: '${s['orders_total']}', icon: Icons.receipt_long),
            StatTile(label: context.tr('restaurants'), value: '${s['restaurants']}', icon: Icons.storefront),
            StatTile(label: context.tr('pending_restaurants'), value: '${s['pending_restaurants']}', icon: Icons.pending_actions),
            StatTile(label: context.tr('customers'), value: '${s['users']}', icon: Icons.people),
            StatTile(label: context.tr('drivers_online'), value: '${s['drivers_online']} / ${s['drivers']}', icon: Icons.delivery_dining),
          ]),
        ],
      ),
    );
  }
}

class _Restaurants extends StatelessWidget {
  const _Restaurants();

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return DataView<List<Restaurant>>(
      load: () async => parseList(await api.get('/admin/restaurants'), Restaurant.fromJson),
      builder: (context, list, reload) {
        Future<void> patch(Restaurant r, Map<String, dynamic> body) async {
          try {
            await api.patch('/admin/restaurants/${r.id}', body);
            await reload();
          } catch (e) {
            if (context.mounted) showError(context, e);
          }
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add_business),
            label: Text(context.tr('add_restaurant')),
            onPressed: () async {
              final created = await showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                builder: (c) => Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
                  child: const _AddRestaurantForm(),
                ),
              );
              if (created == true) reload();
            },
          ),
          body: RefreshList(
            onRefresh: reload,
            empty: MessageView(icon: Icons.storefront, text: context.tr('no_restaurants')),
            children: [
              for (final r in list)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        RestaurantLogo(restaurant: r, size: 44),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(context.pick(r.nameEn, r.nameAr), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('${r.ownerName ?? ''} · ${r.ownerEmail ?? ''}',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          ]),
                        ),
                        Text(r.isOpen ? context.tr('open') : context.tr('closed'),
                            style: TextStyle(color: r.isOpen ? Colors.green : Colors.red)),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        FilterChip(
                          label: Text(context.tr('approved')),
                          selected: r.approved,
                          onSelected: (v) => patch(r, {'approved': v}),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          icon: const Icon(Icons.percent, size: 18),
                          label: Text('${context.tr('commission')}: ${r.commissionPct}%'),
                          onPressed: () async {
                            final v = await _askNumber(context, context.tr('commission'), r.commissionPct);
                            if (v != null) patch(r, {'commission_pct': v});
                          },
                        ),
                      ]),
                    ]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

Future<double?> _askNumber(BuildContext context, String label, num initial) {
  final c = TextEditingController(text: '$initial');
  return showDialog<double>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(label),
      content: TextField(
        controller: c,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: Text(d.tr('cancel'))),
        FilledButton(
          onPressed: () {
            final v = double.tryParse(c.text.trim());
            if (v != null && v >= 0) Navigator.pop(d, v);
          },
          child: Text(d.tr('save')),
        ),
      ],
    ),
  ).whenComplete(c.dispose);
}

class _AddRestaurantForm extends StatefulWidget {
  const _AddRestaurantForm();

  @override
  State<_AddRestaurantForm> createState() => _AddRestaurantFormState();
}

class _AddRestaurantFormState extends State<_AddRestaurantForm> {
  final _form = GlobalKey<FormState>();
  final _c = {
    for (final k in ['name_en', 'name_ar', 'category_en', 'category_ar', 'owner_name', 'owner_email', 'owner_password',
      'delivery_fee', 'min_order', 'delivery_time'])
      k: TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    _c['delivery_fee']!.text = '15';
    _c['min_order']!.text = '50';
    _c['delivery_time']!.text = '30';
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
    String v(String k) => _c[k]!.text.trim();
    await context.read<AppState>().api.post('/admin/restaurants', {
      'name_en': v('name_en'),
      'name_ar': v('name_ar'),
      'category_en': v('category_en'),
      'category_ar': v('category_ar'),
      'owner_name': v('owner_name'),
      'owner_email': v('owner_email'),
      'owner_password': v('owner_password'),
      'delivery_fee': double.tryParse(v('delivery_fee')) ?? 15,
      'min_order': double.tryParse(v('min_order')) ?? 0,
      'delivery_time_min': int.tryParse(v('delivery_time')) ?? 30,
    });
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    String? req(String? v) => (v == null || v.trim().isEmpty) ? context.tr('required') : null;
    Widget f(String key, {bool required = false, bool number = false, bool obscure = false, String? label}) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextFormField(
            controller: _c[key],
            obscureText: obscure,
            keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : null,
            decoration: InputDecoration(labelText: context.tr(label ?? key), isDense: true),
            validator: required ? req : null,
          ),
        );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(context.tr('add_restaurant'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            f('name_en', required: true),
            f('name_ar', required: true),
            Row(children: [
              Expanded(child: f('category_en')),
              const SizedBox(width: 8),
              Expanded(child: f('category_ar')),
            ]),
            Row(children: [
              Expanded(child: f('delivery_fee', number: true)),
              const SizedBox(width: 8),
              Expanded(child: f('min_order', number: true)),
              const SizedBox(width: 8),
              Expanded(child: f('delivery_time', number: true)),
            ]),
            const Divider(),
            f('owner_name', required: true),
            f('owner_email', required: true),
            f('owner_password', required: true, obscure: true),
            const SizedBox(height: 8),
            Align(alignment: AlignmentDirectional.centerEnd, child: AsyncButton(label: context.tr('save'), onPressed: _save)),
          ]),
        ),
      ),
    );
  }
}

class _Orders extends StatefulWidget {
  const _Orders();

  @override
  State<_Orders> createState() => _OrdersState();
}

class _OrdersState extends State<_Orders> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    const statuses = ['pending', 'accepted', 'preparing', 'ready', 'picked_up', 'delivered', 'rejected', 'cancelled'];
    return Column(children: [
      SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            for (final s in [null, ...statuses])
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ChoiceChip(
                  label: Text(s == null ? context.tr('all') : context.tr('status_$s')),
                  selected: _status == s,
                  onSelected: (_) => setState(() => _status = s),
                ),
              ),
          ],
        ),
      ),
      Expanded(
        child: DataView<List<Order>>(
          key: ValueKey(_status),
          pollEvery: const Duration(seconds: 10),
          load: () async => parseList(await api.get('/admin/orders${_status == null ? '' : '?status=$_status'}'), Order.fromJson),
          builder: (context, orders, reload) => RefreshList(
            onRefresh: reload,
            empty: MessageView(icon: Icons.receipt_long, text: context.tr('no_orders')),
            children: [
              for (final o in orders)
                OrderCard(
                  order: o,
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderScreen(orderId: o.id)));
                    reload();
                  },
                ),
            ],
          ),
        ),
      ),
    ]);
  }
}

class _Users extends StatefulWidget {
  const _Users();

  @override
  State<_Users> createState() => _UsersState();
}

class _UsersState extends State<_Users> {
  String _role = 'customer';

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    final me = context.read<AppState>().user!.id;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: SegmentedButton<String>(
          segments: [
            for (final r in ['customer', 'driver', 'restaurant', 'admin'])
              ButtonSegment(value: r, label: Text(context.tr(r))),
          ],
          selected: {_role},
          onSelectionChanged: (s) => setState(() => _role = s.first),
        ),
      ),
      Expanded(
        child: DataView<List<User>>(
          key: ValueKey(_role),
          load: () async => parseList(await api.get('/admin/users?role=$_role'), User.fromJson),
          builder: (context, users, reload) => RefreshList(
            onRefresh: reload,
            empty: MessageView(icon: Icons.people_outline, text: '—'),
            children: [
              for (final u in users)
                Card(
                  child: SwitchListTile(
                    title: Row(children: [
                      Flexible(child: Text(u.name)),
                      if (u.role == 'driver' && u.isOnline) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.circle, size: 10, color: Colors.green),
                      ],
                    ]),
                    subtitle: Text([u.email, if (u.phone != null) u.phone].join(' · ')),
                    value: u.active,
                    onChanged: u.id == me
                        ? null
                        : (v) async {
                            try {
                              await api.patch('/admin/users/${u.id}', {'active': v});
                              reload();
                            } catch (e) {
                              if (context.mounted) showError(context, e);
                            }
                          },
                  ),
                ),
            ],
          ),
        ),
      ),
    ]);
  }
}

class _Settings extends StatelessWidget {
  const _Settings();

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return DataView<Map<String, dynamic>>(
      load: () async => await api.get('/admin/settings') as Map<String, dynamic>,
      builder: (context, s, reload) => AccountView(children: [
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.receipt),
              title: Text(context.tr('service_fee')),
              trailing: Text(context.money(s['service_fee'] as num)),
              onTap: () async {
                final v = await _askNumber(context, context.tr('service_fee'), s['service_fee'] as num);
                if (v == null) return;
                try {
                  await api.put('/admin/settings', {'service_fee': v});
                  await reload();
                  if (context.mounted) showMessage(context, context.tr('saved'));
                } catch (e) {
                  if (context.mounted) showError(context, e);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.currency_exchange),
              title: Text(context.tr('currency')),
              trailing: Text('${s['currency']}'),
            ),
          ]),
        ),
      ]),
    );
  }
}
