import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';

/// Session, language and platform settings.
class AppState extends ChangeNotifier {
  final Api api = Api();
  User? user;
  Locale locale = const Locale('ar');
  String currency = 'EGP';
  bool ready = false;
  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final savedLang = _prefs.getString('lang');
    final deviceLang = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    locale = Locale(savedLang ?? (deviceLang == 'ar' ? 'ar' : 'en'));

    final token = _prefs.getString('token');
    final savedUser = _prefs.getString('user');
    if (token != null && savedUser != null) {
      api.token = token;
      user = User.fromJson(jsonDecode(savedUser) as Map<String, dynamic>);
      refreshMe(); // validate in background; keeps working offline
    }
    loadSettings();
    ready = true;
    notifyListeners();
  }

  Future<void> loadSettings() async {
    try {
      final s = await api.get('/settings') as Map<String, dynamic>;
      currency = (s['currency'] as String?) ?? currency;
      notifyListeners();
    } on ApiException {
      // keep defaults
    }
  }

  Future<void> refreshMe() async {
    try {
      final res = await api.get('/auth/me') as Map<String, dynamic>;
      _setUser(User.fromJson(res['user'] as Map<String, dynamic>));
    } on ApiException catch (e) {
      if (e.status == 401) await logout();
    }
  }

  Future<void> login(String email, String password) async {
    final res = await api.post('/auth/login', {'email': email, 'password': password}) as Map<String, dynamic>;
    await _setSession(res);
  }

  Future<void> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String role,
  }) async {
    final res = await api.post('/auth/register', {
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
      'role': role,
    }) as Map<String, dynamic>;
    await _setSession(res);
  }

  Future<void> _setSession(Map<String, dynamic> res) async {
    api.token = res['token'] as String;
    await _prefs.setString('token', api.token!);
    _setUser(User.fromJson(res['user'] as Map<String, dynamic>));
  }

  void _setUser(User u) {
    user = u;
    _prefs.setString('user', jsonEncode(u.json));
    notifyListeners();
  }

  void updateUser(Map<String, dynamic> json) => _setUser(User.fromJson(json));

  Future<void> logout() async {
    api.token = null;
    user = null;
    await _prefs.remove('token');
    await _prefs.remove('user');
    notifyListeners();
  }

  void toggleLanguage() {
    locale = Locale(locale.languageCode == 'ar' ? 'en' : 'ar');
    _prefs.setString('lang', locale.languageCode);
    notifyListeners();
  }
}

class CartLine {
  CartLine(this.item, this.qty);
  final MenuItem item;
  int qty;
}

/// Customer cart. Holds items from a single restaurant at a time.
class CartState extends ChangeNotifier {
  Restaurant? restaurant;
  final Map<int, CartLine> lines = {};

  int get count => lines.values.fold(0, (s, l) => s + l.qty);
  double get subtotal => lines.values.fold(0.0, (s, l) => s + l.item.price * l.qty);
  int qtyOf(int itemId) => lines[itemId]?.qty ?? 0;

  bool belongsTo(Restaurant r) => restaurant == null || restaurant!.id == r.id || lines.isEmpty;

  void add(Restaurant r, MenuItem item) {
    if (!belongsTo(r)) lines.clear();
    restaurant = r;
    lines.putIfAbsent(item.id, () => CartLine(item, 0)).qty++;
    notifyListeners();
  }

  void remove(MenuItem item) {
    final line = lines[item.id];
    if (line == null) return;
    if (--line.qty <= 0) lines.remove(item.id);
    if (lines.isEmpty) restaurant = null;
    notifyListeners();
  }

  void clear() {
    lines.clear();
    restaurant = null;
    notifyListeners();
  }
}
