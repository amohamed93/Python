import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n.dart';
import '../../models.dart';
import '../../state.dart';
import '../../widgets.dart';
import 'order_screen.dart';
import 'restaurant_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _form = GlobalKey<FormState>();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();
  String _payment = 'cash';
  bool _busy = false;
  double _serviceFee = 0;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _phone.text = app.user?.phone ?? '';
    SharedPreferences.getInstance().then((p) {
      if (mounted && _address.text.isEmpty) _address.text = p.getString('last_address') ?? '';
    });
    app.api.get('/settings').then((s) {
      if (mounted) setState(() => _serviceFee = ((s as Map)['service_fee'] as num).toDouble());
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _address.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (!_form.currentState!.validate()) return;
    final cart = context.read<CartState>();
    final api = context.read<AppState>().api;
    setState(() => _busy = true);
    try {
      final res = await api.post('/orders', {
        'restaurant_id': cart.restaurant!.id,
        'items': [for (final l in cart.lines.values) {'menu_item_id': l.item.id, 'qty': l.qty}],
        'address': _address.text.trim(),
        'phone': _phone.text.trim(),
        'notes': _notes.text.trim(),
        'payment_method': _payment,
      });
      final order = Order.fromJson(res as Map<String, dynamic>);
      (await SharedPreferences.getInstance()).setString('last_address', _address.text.trim());
      cart.clear();
      if (!mounted) return;
      showMessage(context, context.tr('order_placed'));
      Navigator.of(context).popUntil((r) => r.isFirst);
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderScreen(orderId: order.id)));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartState>();
    final r = cart.restaurant;
    if (r == null || cart.count == 0) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('cart'))),
        body: MessageView(icon: Icons.shopping_bag_outlined, text: context.tr('cart_empty')),
      );
    }
    final total = cart.subtotal + r.deliveryFee + _serviceFee;
    final belowMin = cart.subtotal < r.minOrder;

    Widget row(String label, double v, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
            const Spacer(),
            Text(context.money(v), style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
          ]),
        );

    return Scaffold(
      appBar: AppBar(title: Text(context.pick(r.nameEn, r.nameAr))),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              child: Column(children: [
                for (final l in cart.lines.values)
                  ListTile(
                    title: Text(context.pick(l.item.nameEn, l.item.nameAr)),
                    subtitle: Text(context.money(l.item.price * l.qty)),
                    trailing: QtyStepper(
                      qty: l.qty,
                      onAdd: () => cart.add(r, l.item),
                      onRemove: () => cart.remove(l.item),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              maxLines: 2,
              decoration: InputDecoration(labelText: context.tr('address'), prefixIcon: const Icon(Icons.location_on_outlined)),
              validator: (v) => (v == null || v.trim().isEmpty) ? context.tr('required') : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: context.tr('phone'), prefixIcon: const Icon(Icons.phone_outlined)),
              validator: (v) => (v == null || v.trim().isEmpty) ? context.tr('required') : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _notes,
              decoration: InputDecoration(labelText: context.tr('notes'), prefixIcon: const Icon(Icons.edit_note)),
            ),
            const SizedBox(height: 16),
            Text(context.tr('payment'), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'cash', icon: const Icon(Icons.payments_outlined), label: Text(context.tr('cash'))),
                ButtonSegment(value: 'card', icon: const Icon(Icons.credit_card), label: Text(context.tr('card'))),
              ],
              selected: {_payment},
              onSelectionChanged: (s) => setState(() => _payment = s.first),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  row(context.tr('subtotal'), cart.subtotal),
                  row(context.tr('delivery_fee'), r.deliveryFee),
                  row(context.tr('service_fee'), _serviceFee),
                  const Divider(),
                  row(context.tr('total'), total, bold: true),
                ]),
              ),
            ),
            if (belowMin)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('${context.tr('err_below_min_order')} (${context.money(r.minOrder)})',
                    style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _busy || belowMin ? null : _placeOrder,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('${context.tr('place_order')} · ${context.money(total)}'),
          ),
        ),
      ),
    );
  }
}
