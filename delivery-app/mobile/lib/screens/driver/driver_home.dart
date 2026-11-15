import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../l10n.dart';
import '../../models.dart';
import '../../state.dart';
import '../../widgets.dart';
import '../customer/order_screen.dart';

class DriverHome extends StatefulWidget {
  const DriverHome({super.key});

  @override
  State<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends State<DriverHome> {
  int _tab = 0;

  Future<void> _setOnline(bool v) async {
    final app = context.read<AppState>();
    try {
      final res = await app.api.patch('/driver/me', {'is_online': v}) as Map<String, dynamic>;
      app.updateUser(res['user'] as Map<String, dynamic>);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = context.watch<AppState>().user?.isOnline ?? false;
    final titles = [context.tr('available_orders'), context.tr('my_deliveries'), context.tr('account')];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_tab]),
        actions: [
          Text(online ? context.tr('online') : context.tr('offline'),
              style: TextStyle(color: online ? Colors.green : Colors.grey, fontWeight: FontWeight.w600)),
          Switch(value: online, onChanged: _setOnline),
          const SizedBox(width: 8),
        ],
      ),
      body: switch (_tab) {
        // Keyed by online state so the list reloads when toggled.
        0 => _Available(key: ValueKey(online), online: online, onClaimed: () => setState(() => _tab = 1)),
        1 => const _MyDeliveries(),
        _ => const _DriverAccount(),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.radar), label: context.tr('available_orders')),
          NavigationDestination(icon: const Icon(Icons.delivery_dining), label: context.tr('my_deliveries')),
          NavigationDestination(icon: const Icon(Icons.account_balance_wallet_outlined), label: context.tr('earnings')),
        ],
      ),
    );
  }
}

class _Available extends StatelessWidget {
  const _Available({super.key, required this.online, required this.onClaimed});
  final bool online;
  final VoidCallback onClaimed;

  @override
  Widget build(BuildContext context) {
    if (!online) return MessageView(icon: Icons.power_settings_new, text: context.tr('go_online_hint'));
    final api = context.read<AppState>().api;
    return DataView<List<Order>>(
      pollEvery: const Duration(seconds: 5),
      load: () async => parseList(await api.get('/driver/available'), Order.fromJson),
      builder: (context, orders, reload) => RefreshList(
        onRefresh: reload,
        empty: MessageView(icon: Icons.hourglass_empty, text: context.tr('no_available')),
        children: [
          for (final o in orders)
            OrderCard(
              order: o,
              actions: [
                AsyncButton(
                  label: '${context.tr('act_claim')} · ${context.money(o.deliveryFee)}',
                  onPressed: () async {
                    try {
                      await api.post('/driver/orders/${o.id}/accept');
                      onClaimed();
                    } catch (e) {
                      await reload();
                      rethrow;
                    }
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MyDeliveries extends StatelessWidget {
  const _MyDeliveries();

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return DataView<List<Order>>(
      pollEvery: const Duration(seconds: 5),
      load: () async => parseList(await api.get('/driver/orders'), Order.fromJson),
      builder: (context, orders, reload) {
        Future<void> set(Order o, String status) async {
          await api.post('/driver/orders/${o.id}/status', {'status': status});
          await reload();
        }

        // Active first, then history.
        final sorted = [...orders.where((o) => !o.isFinal), ...orders.where((o) => o.isFinal)];
        return RefreshList(
          onRefresh: reload,
          empty: MessageView(icon: Icons.delivery_dining, text: context.tr('no_orders')),
          children: [
            for (final o in sorted)
              OrderCard(
                order: o,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderScreen(orderId: o.id))),
                actions: switch (o.status) {
                  'ready' => [AsyncButton(label: context.tr('act_pick_up'), onPressed: () => set(o, 'picked_up'))],
                  'picked_up' => [AsyncButton(label: context.tr('act_deliver'), onPressed: () => set(o, 'delivered'))],
                  _ => const <Widget>[],
                },
              ),
          ],
        );
      },
    );
  }
}

class _DriverAccount extends StatelessWidget {
  const _DriverAccount();

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return DataView<Map<String, dynamic>>(
      load: () async => await api.get('/driver/stats') as Map<String, dynamic>,
      builder: (context, s, reload) {
        final today = s['today'] as Map<String, dynamic>;
        final all = s['all_time'] as Map<String, dynamic>;
        return AccountView(children: [
          StatGrid(tiles: [
            StatTile(label: '${context.tr('deliveries')} · ${context.tr('today')}', value: '${today['deliveries']}', icon: Icons.check_circle_outline),
            StatTile(label: '${context.tr('earnings')} · ${context.tr('today')}', value: context.money(today['earnings'] as num), icon: Icons.payments_outlined),
            StatTile(label: '${context.tr('deliveries')} · ${context.tr('all_time')}', value: '${all['deliveries']}', icon: Icons.delivery_dining),
            StatTile(label: '${context.tr('earnings')} · ${context.tr('all_time')}', value: context.money(all['earnings'] as num), icon: Icons.account_balance_wallet_outlined),
          ]),
        ]);
      },
    );
  }
}
