import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../l10n.dart';
import '../../models.dart';
import '../../state.dart';
import '../../widgets.dart';
import 'restaurant_screen.dart';

class RestaurantsTab extends StatefulWidget {
  const RestaurantsTab({super.key});

  @override
  State<RestaurantsTab> createState() => _RestaurantsTabState();
}

class _RestaurantsTabState extends State<RestaurantsTab> {
  String _query = '';
  String? _category;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    final params = <String, String>{
      if (_query.isNotEmpty) 'q': _query,
      'category': ?_category,
    };
    final qs = params.isEmpty ? '' : '?${Uri(queryParameters: params).query}';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: context.tr('search_restaurants'),
              prefixIcon: const Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), () => setState(() => _query = v.trim()));
            },
          ),
        ),
        SizedBox(
          height: 48,
          child: DataView<List<dynamic>>(
            load: () async => await api.get('/categories') as List<dynamic>,
            builder: (context, cats, _) => ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _chip(context.tr('all'), null),
                for (final c in cats) _chip(context.pick(c['category_en'] as String, c['category_ar'] as String), c['category_en'] as String),
              ],
            ),
          ),
        ),
        Expanded(
          child: DataView<List<Restaurant>>(
            key: ValueKey(qs),
            load: () async => parseList(await api.get('/restaurants$qs'), Restaurant.fromJson),
            builder: (context, list, reload) => RefreshList(
              onRefresh: reload,
              empty: MessageView(icon: Icons.search_off, text: context.tr('no_restaurants')),
              children: [for (final r in list) RestaurantCard(restaurant: r)],
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, String? value) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: _category == value,
          onSelected: (_) => setState(() => _category = value),
        ),
      );
}

class RestaurantCard extends StatelessWidget {
  const RestaurantCard({super.key, required this.restaurant});
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    final grey = TextStyle(color: Colors.grey.shade600, fontSize: 13);
    return Opacity(
      opacity: r.isOpen ? 1 : 0.55,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RestaurantScreen(restaurantId: r.id))),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                RestaurantLogo(restaurant: r),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(context.pick(r.nameEn, r.nameAr),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        if (!r.isOpen)
                          Text(context.tr('closed'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 2),
                      Text(context.pick(r.categoryEn, r.categoryAr), style: grey),
                      const SizedBox(height: 6),
                      Wrap(spacing: 12, children: [
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                          Text(' ${r.rating.toStringAsFixed(1)}'),
                        ]),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                          Text(' ${r.deliveryTimeMin} ${context.tr('min')}', style: grey),
                        ]),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.delivery_dining, size: 16, color: Colors.grey.shade600),
                          Text(' ${context.money(r.deliveryFee)}', style: grey),
                        ]),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
