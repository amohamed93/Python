import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../l10n.dart';
import '../../models.dart';
import '../../state.dart';
import '../../widgets.dart';
import 'order_screen.dart';

class OrdersTab extends StatelessWidget {
  const OrdersTab({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return DataView<List<Order>>(
      pollEvery: const Duration(seconds: 10),
      load: () async => parseList(await api.get('/orders'), Order.fromJson),
      builder: (context, orders, reload) => RefreshList(
        onRefresh: reload,
        empty: MessageView(icon: Icons.receipt_long_outlined, text: context.tr('no_orders')),
        children: [
          for (final o in orders)
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                title: Text(context.pick(o.restaurantNameEn, o.restaurantNameAr),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('#${o.id} · ${formatTime(context, o.createdAt)}\n${context.money(o.total)}'),
                isThreeLine: true,
                trailing: StatusChip(o.status),
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderScreen(orderId: o.id)));
                  reload();
                },
              ),
            ),
        ],
      ),
    );
  }
}
