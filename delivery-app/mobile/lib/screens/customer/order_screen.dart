import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../l10n.dart';
import '../../models.dart';
import '../../state.dart';
import '../../widgets.dart';

/// Live order tracking. Refreshes every 5 seconds until the order is finished.
/// Admins get an extra "change status" control.
class OrderScreen extends StatelessWidget {
  const OrderScreen({super.key, required this.orderId});
  final int orderId;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text('${context.tr('order')} #$orderId')),
      body: DataView<Order>(
        pollEvery: const Duration(seconds: 5),
        load: () async => Order.fromJson(await app.api.get('/orders/$orderId') as Map<String, dynamic>),
        builder: (context, o, reload) => _OrderDetails(order: o, reload: reload, role: app.user?.role ?? ''),
      ),
    );
  }
}

class _OrderDetails extends StatelessWidget {
  const _OrderDetails({required this.order, required this.reload, required this.role});
  final Order order;
  final Future<void> Function() reload;
  final String role;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final api = context.read<AppState>().api;
    Widget money(String label, double v, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
            const Spacer(),
            Text(context.money(v), style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
          ]),
        );

    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(context.pick(o.restaurantNameEn, o.restaurantNameAr),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  StatusChip(o.status),
                ]),
                const SizedBox(height: 4),
                Text(formatTime(context, o.createdAt), style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 16),
                _Timeline(order: o),
              ]),
            ),
          ),
          if (o.driverName != null)
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.delivery_dining)),
                title: Text(o.driverName!),
                subtitle: Text(context.tr('your_driver')),
                trailing: o.driverPhone == null ? null : Text(o.driverPhone!, textDirection: TextDirection.ltr),
              ),
            ),
          if (role != 'customer')
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(o.customerName),
                subtitle: Text(context.tr('customer_info')),
                trailing: o.phone == null ? null : Text(o.phone!, textDirection: TextDirection.ltr),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.tr('items'), style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                for (final i in o.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Text('${i.qty}×  '),
                      Expanded(child: Text(context.pick(i.nameEn, i.nameAr))),
                      Text(context.money(i.price * i.qty)),
                    ]),
                  ),
                const Divider(height: 24),
                money(context.tr('subtotal'), o.subtotal),
                money(context.tr('delivery_fee'), o.deliveryFee),
                money(context.tr('service_fee'), o.serviceFee),
                const Divider(),
                money(context.tr('total'), o.total, bold: true),
                const SizedBox(height: 8),
                Text('${context.tr('payment')}: ${context.tr(o.paymentMethod)}', style: TextStyle(color: Colors.grey.shade700)),
              ]),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(o.address),
              subtitle: o.notes == null || o.notes!.isEmpty ? null : Text(o.notes!),
            ),
          ),
          const SizedBox(height: 12),
          if (role == 'customer' && o.status == 'pending')
            AsyncButton(
              label: context.tr('cancel_order'),
              danger: true,
              onPressed: () async {
                if (!await confirm(context, context.tr('cancel_order_q'))) return;
                await api.post('/orders/${o.id}/cancel');
                await reload();
              },
            ),
          if (role == 'admin' && !o.isFinal) _AdminStatusControl(order: o, reload: reload),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final o = order;
    if (o.status == 'rejected' || o.status == 'cancelled') {
      return Row(children: [
        const Icon(Icons.cancel, color: Colors.red),
        const SizedBox(width: 8),
        Text(context.tr('status_${o.status}'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      ]);
    }
    final current = Order.steps.indexOf(o.status);
    final times = {for (final e in o.events) e.status: e.at};
    return Column(
      children: [
        for (var i = 0; i < Order.steps.length; i++)
          Row(children: [
            Icon(
              i < current || o.status == 'delivered'
                  ? Icons.check_circle
                  : i == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
              color: i <= current ? brandColor : Colors.grey.shade400,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  context.tr('status_${Order.steps[i]}'),
                  style: TextStyle(
                    fontWeight: i == current ? FontWeight.bold : null,
                    color: i <= current ? null : Colors.grey.shade500,
                  ),
                ),
              ),
            ),
            if (times[Order.steps[i]] != null)
              Text(formatTime(context, times[Order.steps[i]]!), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ]),
      ],
    );
  }
}

class _AdminStatusControl extends StatelessWidget {
  const _AdminStatusControl({required this.order, required this.reload});
  final Order order;
  final Future<void> Function() reload;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    const all = ['pending', 'accepted', 'preparing', 'ready', 'picked_up', 'delivered', 'rejected', 'cancelled'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr('set_status'), style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in all.where((s) => s != order.status))
              ActionChip(
                label: Text(context.tr('status_$s')),
                onPressed: () async {
                  try {
                    await api.post('/admin/orders/${order.id}/status', {'status': s});
                    await reload();
                  } catch (e) {
                    if (context.mounted) showError(context, e);
                  }
                },
              ),
          ]),
        ]),
      ),
    );
  }
}
