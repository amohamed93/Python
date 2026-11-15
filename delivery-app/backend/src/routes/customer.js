// Customer-facing endpoints: browsing restaurants and placing/tracking orders.
const express = require('express');
const { db, tx, getSettings } = require('../db');
const { requireAuth } = require('../auth');
const { canTransition, setStatus, listOrders, getOrder } = require('../orders');

const router = express.Router();
const round2 = (n) => Math.round(n * 100) / 100;

router.get('/settings', (req, res) => res.json(getSettings()));

// List approved restaurants. ?q= searches names/categories, ?category= filters by English category.
router.get('/restaurants', (req, res) => {
  const { q, category } = req.query;
  let sql = 'SELECT * FROM restaurants WHERE approved = 1';
  const params = [];
  if (q) {
    sql += ' AND (name_en LIKE ? OR name_ar LIKE ? OR category_en LIKE ? OR category_ar LIKE ?)';
    const like = `%${q}%`;
    params.push(like, like, like, like);
  }
  if (category) {
    sql += ' AND category_en = ?';
    params.push(category);
  }
  sql += ' ORDER BY is_open DESC, rating DESC';
  res.json(db.prepare(sql).all(...params));
});

router.get('/categories', (req, res) => {
  res.json(db.prepare(
    'SELECT DISTINCT category_en, category_ar FROM restaurants WHERE approved = 1 ORDER BY category_en'
  ).all());
});

router.get('/restaurants/:id', (req, res) => {
  const r = db.prepare('SELECT * FROM restaurants WHERE id = ? AND approved = 1').get(req.params.id);
  if (!r) return res.status(404).json({ error: 'not_found' });
  const menu = db.prepare('SELECT * FROM menu_items WHERE restaurant_id = ? ORDER BY section_en, id').all(r.id);
  res.json({ ...r, menu });
});

router.post('/orders', requireAuth('customer'), (req, res) => {
  const { restaurant_id, items, address, phone, notes, payment_method = 'cash' } = req.body || {};
  if (!restaurant_id || !Array.isArray(items) || !items.length || !address) {
    return res.status(400).json({ error: 'missing_fields' });
  }
  if (!['cash', 'card'].includes(payment_method)) return res.status(400).json({ error: 'invalid_payment_method' });
  const r = db.prepare('SELECT * FROM restaurants WHERE id = ? AND approved = 1').get(restaurant_id);
  if (!r) return res.status(404).json({ error: 'restaurant_not_found' });
  if (!r.is_open) return res.status(400).json({ error: 'restaurant_closed' });

  // Prices always come from the database, never from the client.
  const getItem = db.prepare('SELECT * FROM menu_items WHERE id = ? AND restaurant_id = ?');
  const lines = [];
  for (const it of items) {
    const qty = Number.parseInt(it.qty, 10);
    if (!Number.isInteger(qty) || qty < 1 || qty > 99) return res.status(400).json({ error: 'invalid_quantity' });
    const m = getItem.get(it.menu_item_id, r.id);
    if (!m) return res.status(400).json({ error: 'item_not_found', menu_item_id: it.menu_item_id });
    if (!m.available) return res.status(400).json({ error: 'item_unavailable', menu_item_id: m.id });
    lines.push({ m, qty });
  }
  const subtotal = round2(lines.reduce((s, l) => s + l.m.price * l.qty, 0));
  if (subtotal < r.min_order) return res.status(400).json({ error: 'below_min_order', min_order: r.min_order });
  const { service_fee } = getSettings();
  const total = round2(subtotal + r.delivery_fee + service_fee);

  const orderId = tx(() => {
    const { lastInsertRowid } = db.prepare(`INSERT INTO orders
      (customer_id, restaurant_id, status, subtotal, delivery_fee, service_fee, total, address, phone, notes, payment_method)
      VALUES (?, ?, 'pending', ?, ?, ?, ?, ?, ?, ?, ?)`)
      .run(req.user.id, r.id, subtotal, r.delivery_fee, service_fee, total, address,
        phone || req.user.phone || null, notes || null, payment_method);
    const ins = db.prepare('INSERT INTO order_items (order_id, menu_item_id, name_en, name_ar, price, qty) VALUES (?, ?, ?, ?, ?, ?)');
    for (const { m, qty } of lines) ins.run(lastInsertRowid, m.id, m.name_en, m.name_ar, m.price, qty);
    db.prepare("INSERT INTO order_events (order_id, status) VALUES (?, 'pending')").run(lastInsertRowid);
    return lastInsertRowid;
  });
  res.status(201).json(getOrder(orderId));
});

router.get('/orders', requireAuth('customer'), (req, res) => {
  res.json(listOrders('WHERE o.customer_id = ?', [req.user.id]));
});

router.get('/orders/:id', requireAuth(), (req, res) => {
  const o = getOrder(req.params.id);
  if (!o) return res.status(404).json({ error: 'not_found' });
  const u = req.user;
  const ownsRestaurant = u.role === 'restaurant' &&
    db.prepare('SELECT 1 FROM restaurants WHERE id = ? AND owner_id = ?').get(o.restaurant_id, u.id);
  const allowed = u.role === 'admin' || o.customer_id === u.id || o.driver_id === u.id || ownsRestaurant;
  if (!allowed) return res.status(404).json({ error: 'not_found' });
  res.json(o);
});

router.post('/orders/:id/cancel', requireAuth('customer'), (req, res) => {
  const o = db.prepare('SELECT * FROM orders WHERE id = ? AND customer_id = ?').get(req.params.id, req.user.id);
  if (!o) return res.status(404).json({ error: 'not_found' });
  if (!canTransition('customer', o.status, 'cancelled')) return res.status(400).json({ error: 'cannot_cancel' });
  setStatus(o.id, 'cancelled');
  res.json(getOrder(o.id));
});

module.exports = router;
