double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
int _i(Object? v) => (v as num?)?.toInt() ?? 0;
bool _b(Object? v) => v == true || v == 1;
String _s(Object? v) => v?.toString() ?? '';

/// SQLite stores "YYYY-MM-DD HH:MM:SS" in UTC.
DateTime parseServerTime(String s) =>
    DateTime.tryParse('${s.replaceFirst(' ', 'T')}Z')?.toLocal() ?? DateTime.now();

class User {
  User.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        name = _s(j['name']),
        email = _s(j['email']),
        phone = j['phone'] as String?,
        role = _s(j['role']),
        active = _b(j['active']),
        isOnline = _b(j['is_online']),
        json = j;

  final int id;
  final String name, email, role;
  final String? phone;
  final bool active, isOnline;
  final Map<String, dynamic> json;
}

class MenuItem {
  MenuItem.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        restaurantId = _i(j['restaurant_id']),
        nameEn = _s(j['name_en']),
        nameAr = _s(j['name_ar']),
        descEn = _s(j['desc_en']),
        descAr = _s(j['desc_ar']),
        sectionEn = _s(j['section_en']),
        sectionAr = _s(j['section_ar']),
        price = _d(j['price']),
        available = _b(j['available']);

  final int id, restaurantId;
  final String nameEn, nameAr, descEn, descAr, sectionEn, sectionAr;
  final double price;
  final bool available;
}

class Restaurant {
  Restaurant.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        nameEn = _s(j['name_en']),
        nameAr = _s(j['name_ar']),
        descEn = _s(j['desc_en']),
        descAr = _s(j['desc_ar']),
        categoryEn = _s(j['category_en']),
        categoryAr = _s(j['category_ar']),
        deliveryTimeMin = _i(j['delivery_time_min']),
        minOrder = _d(j['min_order']),
        deliveryFee = _d(j['delivery_fee']),
        rating = _d(j['rating']),
        isOpen = _b(j['is_open']),
        approved = _b(j['approved']),
        commissionPct = _d(j['commission_pct']),
        ownerName = j['owner_name'] as String?,
        ownerEmail = j['owner_email'] as String?,
        menu = ((j['menu'] as List?) ?? const [])
            .map((m) => MenuItem.fromJson(m as Map<String, dynamic>))
            .toList();

  final int id, deliveryTimeMin;
  final String nameEn, nameAr, descEn, descAr, categoryEn, categoryAr;
  final double minOrder, deliveryFee, rating, commissionPct;
  final bool isOpen, approved;
  final String? ownerName, ownerEmail;
  final List<MenuItem> menu;
}

class OrderItem {
  OrderItem.fromJson(Map<String, dynamic> j)
      : nameEn = _s(j['name_en']),
        nameAr = _s(j['name_ar']),
        price = _d(j['price']),
        qty = _i(j['qty']);

  final String nameEn, nameAr;
  final double price;
  final int qty;
}

class OrderEvent {
  OrderEvent.fromJson(Map<String, dynamic> j)
      : status = _s(j['status']),
        at = parseServerTime(_s(j['at']));

  final String status;
  final DateTime at;
}

class Order {
  Order.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        customerId = _i(j['customer_id']),
        restaurantId = _i(j['restaurant_id']),
        driverId = j['driver_id'] == null ? null : _i(j['driver_id']),
        status = _s(j['status']),
        subtotal = _d(j['subtotal']),
        deliveryFee = _d(j['delivery_fee']),
        serviceFee = _d(j['service_fee']),
        total = _d(j['total']),
        address = _s(j['address']),
        phone = j['phone'] as String?,
        notes = j['notes'] as String?,
        paymentMethod = _s(j['payment_method']),
        createdAt = parseServerTime(_s(j['created_at'])),
        restaurantNameEn = _s(j['restaurant_name_en']),
        restaurantNameAr = _s(j['restaurant_name_ar']),
        customerName = _s(j['customer_name']),
        customerPhone = j['customer_phone'] as String?,
        driverName = j['driver_name'] as String?,
        driverPhone = j['driver_phone'] as String?,
        items = ((j['items'] as List?) ?? const [])
            .map((m) => OrderItem.fromJson(m as Map<String, dynamic>))
            .toList(),
        events = ((j['events'] as List?) ?? const [])
            .map((m) => OrderEvent.fromJson(m as Map<String, dynamic>))
            .toList();

  final int id, customerId, restaurantId;
  final int? driverId;
  final String status, address, paymentMethod, restaurantNameEn, restaurantNameAr, customerName;
  final String? phone, notes, customerPhone, driverName, driverPhone;
  final double subtotal, deliveryFee, serviceFee, total;
  final DateTime createdAt;
  final List<OrderItem> items;
  final List<OrderEvent> events;

  bool get isFinal => const ['delivered', 'rejected', 'cancelled'].contains(status);

  /// Customer-facing progress steps, in order.
  static const steps = ['pending', 'accepted', 'preparing', 'ready', 'picked_up', 'delivered'];
}

List<T> parseList<T>(Object? data, T Function(Map<String, dynamic>) f) =>
    (data as List).map((e) => f(e as Map<String, dynamic>)).toList();
