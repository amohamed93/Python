import 'dart:async';

import 'package:intl/intl.dart' as intl;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'l10n.dart';
import 'models.dart';
import 'state.dart';

const brandColor = Color(0xFFFF5A00);

String errorText(BuildContext context, Object e) {
  if (e is ApiException) {
    final key = 'err_${e.code}';
    final s = context.tr(key);
    return s == key ? context.tr('err_generic') : s;
  }
  return context.tr('err_generic');
}

void showError(BuildContext context, Object e) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(errorText(context, e)), backgroundColor: Colors.red.shade700));
}

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

Future<bool> confirm(BuildContext context, String question) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      content: Text(question),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(c.tr('no'))),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(c.tr('yes'))),
      ],
    ),
  );
  return ok ?? false;
}

String formatTime(BuildContext context, DateTime t) {
  final now = DateTime.now();
  final sameDay = t.year == now.year && t.month == now.month && t.day == now.day;
  if (context.isAr) {
    // Western digits, consistent with prices; Arabic AM/PM markers.
    final time = '${intl.DateFormat('h:mm', 'en').format(t)} ${t.hour < 12 ? 'ص' : 'م'}';
    return sameDay ? time : '${intl.DateFormat('d/M', 'en').format(t)} $time';
  }
  return intl.DateFormat(sameDay ? 'h:mm a' : 'd MMM, h:mm a', 'en').format(t);
}

/// Loads data, shows a spinner / error with retry, and optionally re-polls.
class DataView<T> extends StatefulWidget {
  const DataView({super.key, required this.load, required this.builder, this.pollEvery});

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;
  final Duration? pollEvery;

  @override
  State<DataView<T>> createState() => _DataViewState<T>();
}

class _DataViewState<T> extends State<DataView<T>> {
  T? _data;
  bool _hasData = false;
  Object? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _reload();
    if (widget.pollEvery != null) {
      _timer = Timer.periodic(widget.pollEvery!, (_) => _reload(silent: true));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _reload({bool silent = false}) async {
    try {
      final d = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = d;
        _hasData = true;
        _error = null;
      });
    } catch (e) {
      if (!mounted || (silent && _hasData)) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasData) {
      if (_error != null) {
        return MessageView(
          icon: Icons.cloud_off,
          text: errorText(context, _error!),
          action: FilledButton.tonal(
            onPressed: () {
              setState(() => _error = null);
              _reload();
            },
            child: Text(context.tr('retry')),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    return widget.builder(context, _data as T, _reload);
  }
}

class MessageView extends StatelessWidget {
  const MessageView({super.key, required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Wraps a scrollable list so "pull to refresh" works even when it is empty.
class RefreshList extends StatelessWidget {
  const RefreshList({super.key, required this.onRefresh, required this.children, this.empty});
  final Future<void> Function() onRefresh;
  final List<Widget> children;
  final Widget? empty;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: children.isEmpty && empty != null
          ? LayoutBuilder(
              builder: (c, box) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(height: box.maxHeight, child: empty),
              ),
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: children,
            ),
    );
  }
}

Color statusColor(String status) => switch (status) {
      'pending' => Colors.orange,
      'accepted' || 'preparing' => Colors.blue,
      'ready' => Colors.indigo,
      'picked_up' => Colors.purple,
      'delivered' => Colors.green,
      _ => Colors.red,
    };

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final c = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(context.tr('status_$status'),
          style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

IconData categoryIcon(String categoryEn) => switch (categoryEn.toLowerCase()) {
      'burgers' => Icons.lunch_dining,
      'pizza' => Icons.local_pizza,
      'asian' => Icons.ramen_dining,
      'egyptian' => Icons.rice_bowl,
      'desserts' => Icons.icecream,
      'coffee' => Icons.coffee,
      _ => Icons.restaurant,
    };

/// Placeholder "logo" until real images are uploaded.
class RestaurantLogo extends StatelessWidget {
  const RestaurantLogo({super.key, required this.restaurant, this.size = 64});
  final Restaurant restaurant;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = [Colors.deepOrange, Colors.teal, Colors.indigo, Colors.pink, Colors.green, Colors.brown];
    final c = colors[restaurant.id % colors.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
      child: Icon(categoryIcon(restaurant.categoryEn), color: c, size: size * 0.5),
    );
  }
}

class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => context.read<AppState>().toggleLanguage(),
      icon: const Icon(Icons.language),
      label: Text(context.tr('switch_language')),
    );
  }
}

/// Account tab shared by every role: profile, language, logout + extra content.
class AccountView extends StatelessWidget {
  const AccountView({super.key, this.children = const []});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final u = app.user!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: CircleAvatar(child: Text(u.name.isEmpty ? '?' : u.name[0].toUpperCase())),
            title: Text(u.name),
            subtitle: Text([u.email, if (u.phone != null && u.phone!.isNotEmpty) u.phone].join('\n')),
            trailing: Chip(label: Text(context.tr(u.role))),
            isThreeLine: u.phone != null && u.phone!.isNotEmpty,
          ),
        ),
        ...children,
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(context.tr('language')),
                trailing: Text(context.tr('switch_language'), style: const TextStyle(color: brandColor)),
                onTap: app.toggleLanguage,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: Text(context.tr('logout'), style: const TextStyle(color: Colors.red)),
                onTap: () async {
                  context.read<CartState>().clear();
                  await app.logout();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.icon});
  final String label, value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              if (icon != null) ...[Icon(icon, size: 18, color: Colors.grey.shade600), const SizedBox(width: 6)],
              Expanded(
                child: Text(label,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13), overflow: TextOverflow.ellipsis),
              ),
            ]),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

/// Lays out stat tiles two per row.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.tiles});
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      rows.add(Row(children: [
        Expanded(child: tiles[i]),
        Expanded(child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox()),
      ]));
    }
    return Column(children: rows);
  }
}

/// Compact order summary used by restaurant, driver and admin screens.
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    this.actions = const [],
    this.onTap,
    this.showRestaurant = true,
    this.showCustomer = true,
  });

  final Order order;
  final List<Widget> actions;
  final VoidCallback? onTap;
  final bool showRestaurant, showCustomer;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final itemsText = o.items.map((i) => '${i.qty}× ${context.pick(i.nameEn, i.nameAr)}').join(context.isAr ? '، ' : ', ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('#${o.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 8),
                Text(formatTime(context, o.createdAt), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                const Spacer(),
                StatusChip(o.status),
              ]),
              const SizedBox(height: 8),
              if (showRestaurant) _line(Icons.storefront, context.pick(o.restaurantNameEn, o.restaurantNameAr)),
              if (showCustomer)
                _line(Icons.person_outline,
                    [o.customerName, if (o.phone != null) o.phone].join(' · ')),
              _line(Icons.location_on_outlined, o.address),
              if (o.driverName != null) _line(Icons.delivery_dining, o.driverName!),
              const SizedBox(height: 6),
              Text(itemsText, style: TextStyle(color: Colors.grey.shade800)),
              if (o.notes != null && o.notes!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('“${o.notes}”', style: const TextStyle(fontStyle: FontStyle.italic)),
                ),
              const SizedBox(height: 8),
              Row(children: [
                Text(context.tr(o.paymentMethod), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                const Spacer(),
                Text(context.money(o.total), style: const TextStyle(fontWeight: FontWeight.bold)),
              ]),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end, children: actions),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Expanded(child: Text(text)),
        ]),
      );
}

/// Runs an async action while showing a busy indicator on the button.
class AsyncButton extends StatefulWidget {
  const AsyncButton({super.key, required this.label, required this.onPressed, this.tonal = false, this.danger = false});
  final String label;
  final Future<void> Function() onPressed;
  final bool tonal, danger;

  @override
  State<AsyncButton> createState() => _AsyncButtonState();
}

class _AsyncButtonState extends State<AsyncButton> {
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      await widget.onPressed();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = _busy
        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
        : Text(widget.label);
    if (widget.danger) {
      return OutlinedButton(
        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
        onPressed: _busy ? null : _run,
        child: child,
      );
    }
    return widget.tonal
        ? FilledButton.tonal(onPressed: _busy ? null : _run, child: child)
        : FilledButton(onPressed: _busy ? null : _run, child: child);
  }
}
