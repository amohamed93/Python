// Admin panel endpoints: platform stats, users, restaurants, orders, fees.
const express = require('express');
const bcrypt = require('bcryptjs');
const { db, tx, getSettings } = require('../db');
const { requireAuth, publicUser } = require('../auth');
const { canTransition, setStatus, listOrders, getOrder } = require('../orders');

const router = express.Router();
router.use(requireAuth('admin'));

router.get('/stats', (req, res) => {
  const count = (sql, ...p) => db.prepare(sql).get(...p).n;
  const delivered = db.prepare(`SELECT COUNT(*) AS orders, COALESCE(SUM(total),0) AS gmv,
    COALESCE(SUM(o.subtotal * r.commission_pct / 100.0 + o.service_fee),0) AS platform_revenue
    FROM orders o JOIN restaurants r ON r.id = o.restaurant_id WHERE o.status = 'delivered'`).get();
  res.json({
    users: count("SELECT COUNT(*) AS n FROM users WHERE role = 'customer'"),
    drivers: count("SELECT COUNT(*) AS n FROM users WHERE role = 'driver'"),
    drivers_online: count("SELECT COUNT(*) AS n FROM users WHERE role = 'driver' AND is_online = 1"),
    restaurants: count('SELECT COUNT(*) AS n FROM restaurants'),
    pending_restaurants: count('SELECT COUNT(*) AS n FROM restaurants WHERE approved = 0'),
    orders_total: count('SELECT COUNT(*) AS n FROM orders'),
    orders_active: count("SELECT COUNT(*) AS n FROM orders WHERE status NOT IN ('delivered','cancelled','rejected')"),
    orders_today: count("SELECT COUNT(*) AS n FROM orders WHERE date(created_at) = date('now')"),
    delivered_orders: delivered.orders,
    gmv: Math.round(delivered.gmv * 100) / 100,
    platform_revenue: Math.round(delivered.platform_revenue * 100) / 100,
  });
});

router.get('/users', (req, res) => {
  const { role } = req.query;
  const rows = role
    ? db.prepare('SELECT * FROM users WHERE role = ? ORDER BY id DESC').all(role)
    : db.prepare('SELECT * FROM users ORDER BY id DESC').all();
  res.json(rows.map(publicUser));
});

router.patch('/users/:id', (req, res) => {
  const u = db.prepare('SELECT * FROM users WHERE id = ?').get(req.params.id);
  if (!u) return res.status(404).json({ error: 'not_found' });
  if (u.id === req.user.id) return res.status(400).json({ error: 'cannot_modify_self' });
  const { active } = req.body || {};
  if (active !== undefined) db.prepare('UPDATE users SET active = ? WHERE id = ?').run(active ? 1 : 0, u.id);
  res.json(publicUser(db.prepare('SELECT * FROM users WHERE id = ?').get(u.id)));
});

router.get('/restaurants', (req, res) => {
  res.json(db.prepare(`SELECT r.*, u.name AS owner_name, u.email AS owner_email
    FROM restaurants r JOIN users u ON u.id = r.owner_id ORDER BY r.id DESC`).all());
});

// Creates a restaurant together with its owner's login.
router.post('/restaurants', (req, res) => {
  const b = req.body || {};
  if (!b.name_en || !b.name_ar || !b.owner_email || !b.owner_password) return res.status(400).json({ error: 'missing_fields' });
  if (String(b.owner_password).length < 6) return res.status(400).json({ error: 'password_too_short' });
  const email = String(b.owner_email).trim().toLowerCase();
  if (db.prepare('SELECT 1 FROM users WHERE email = ?').get(email)) return res.status(409).json({ error: 'email_taken' });
  const id = tx(() => {
    const owner = db.prepare("INSERT INTO users (name, email, phone, password_hash, role) VALUES (?, ?, ?, ?, 'restaurant')")
      .run(b.owner_name || b.name_en, email, b.owner_phone || null, bcrypt.hashSync(String(b.owner_password), 10));
    return db.prepare(`INSERT INTO restaurants (owner_id, name_en, name_ar, desc_en, desc_ar, category_en, category_ar,
      delivery_time_min, min_order, delivery_fee, commission_pct, approved) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)`).run(
      owner.lastInsertRowid, b.name_en, b.name_ar, b.desc_en || '', b.desc_ar || '', b.category_en || '', b.category_ar || '',
      Number(b.delivery_time_min ?? 30), Number(b.min_order ?? 0), Number(b.delivery_fee ?? 15),
      Number(b.commission_pct ?? 15), b.approved === false ? 0 : 1).lastInsertRowid;
  });
  res.status(201).json(db.prepare('SELECT * FROM restaurants WHERE id = ?').get(id));
});

const ADMIN_RESTAURANT_FIELDS = ['approved', 'commission_pct', 'is_open', 'delivery_fee', 'min_order', 'rating'];

router.patch('/restaurants/:id', (req, res) => {
  const r = db.prepare('SELECT * FROM restaurants WHERE id = ?').get(req.params.id);
  if (!r) return res.status(404).json({ error: 'not_found' });
  const b = req.body || {};
  const fields = ADMIN_RESTAURANT_FIELDS.filter((f) => f in b);
  if (fields.length) {
    const vals = fields.map((f) => (['approved', 'is_open'].includes(f) ? (b[f] ? 1 : 0) : Number(b[f])));
    db.prepare(`UPDATE restaurants SET ${fields.map((f) => `${f} = ?`).join(', ')} WHERE id = ?`).run(...vals, r.id);
  }
  res.json(db.prepare('SELECT * FROM restaurants WHERE id = ?').get(r.id));
});

router.get('/orders', (req, res) => {
  const { status } = req.query;
  if (status) return res.json(listOrders('WHERE o.status = ?', [status]));
  res.json(listOrders());
});

router.post('/orders/:id/status', (req, res) => {
  const o = db.prepare('SELECT * FROM orders WHERE id = ?').get(req.params.id);
  if (!o) return res.status(404).json({ error: 'not_found' });
  const { status } = req.body || {};
  if (!canTransition('admin', o.status, status)) return res.status(400).json({ error: 'invalid_transition', from: o.status, to: status });
  setStatus(o.id, status);
  res.json(getOrder(o.id));
});

router.get('/settings', (req, res) => res.json(getSettings()));

router.put('/settings', (req, res) => {
  const b = req.body || {};
  const up = db.prepare('INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value');
  if ('service_fee' in b) {
    if (!(Number(b.service_fee) >= 0)) return res.status(400).json({ error: 'invalid_service_fee' });
    up.run('service_fee', String(Number(b.service_fee)));
  }
  if ('currency' in b && b.currency) up.run('currency', String(b.currency));
  res.json(getSettings());
});

module.exports = router;
