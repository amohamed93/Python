// Restaurant owner dashboard: incoming orders, menu management, open/closed status.
const express = require('express');
const { db } = require('../db');
const { requireAuth } = require('../auth');
const { canTransition, setStatus, listOrders, getOrder } = require('../orders');

const router = express.Router();
router.use(requireAuth('restaurant'));

// Attach the restaurant this owner manages.
router.use((req, res, next) => {
  const r = db.prepare('SELECT * FROM restaurants WHERE owner_id = ?').get(req.user.id);
  if (!r) return res.status(404).json({ error: 'no_restaurant' });
  req.restaurant = r;
  next();
});

router.get('/me', (req, res) => res.json(req.restaurant));

const EDITABLE = ['name_en', 'name_ar', 'desc_en', 'desc_ar', 'category_en', 'category_ar', 'image_url',
  'delivery_time_min', 'min_order', 'delivery_fee', 'is_open'];

router.patch('/me', (req, res) => {
  const body = req.body || {};
  const fields = EDITABLE.filter((f) => f in body);
  if (fields.length) {
    const vals = fields.map((f) => (f === 'is_open' ? (body[f] ? 1 : 0) : body[f]));
    db.prepare(`UPDATE restaurants SET ${fields.map((f) => `${f} = ?`).join(', ')} WHERE id = ?`)
      .run(...vals, req.restaurant.id);
  }
  res.json(db.prepare('SELECT * FROM restaurants WHERE id = ?').get(req.restaurant.id));
});

// ?status=active returns orders still in progress; ?status=<name> filters by one status.
router.get('/orders', (req, res) => {
  const { status } = req.query;
  if (status === 'active') {
    return res.json(listOrders("WHERE o.restaurant_id = ? AND o.status IN ('pending','accepted','preparing','ready','picked_up')", [req.restaurant.id]));
  }
  if (status) return res.json(listOrders('WHERE o.restaurant_id = ? AND o.status = ?', [req.restaurant.id, status]));
  res.json(listOrders('WHERE o.restaurant_id = ?', [req.restaurant.id]));
});

router.post('/orders/:id/status', (req, res) => {
  const o = db.prepare('SELECT * FROM orders WHERE id = ? AND restaurant_id = ?').get(req.params.id, req.restaurant.id);
  if (!o) return res.status(404).json({ error: 'not_found' });
  const { status } = req.body || {};
  if (!canTransition('restaurant', o.status, status)) return res.status(400).json({ error: 'invalid_transition', from: o.status, to: status });
  setStatus(o.id, status);
  res.json(getOrder(o.id));
});

router.get('/stats', (req, res) => {
  const id = req.restaurant.id;
  const today = db.prepare(`SELECT COUNT(*) AS orders, COALESCE(SUM(subtotal),0) AS revenue FROM orders
    WHERE restaurant_id = ? AND status = 'delivered' AND date(created_at) = date('now')`).get(id);
  const all = db.prepare(`SELECT COUNT(*) AS orders, COALESCE(SUM(subtotal),0) AS revenue FROM orders
    WHERE restaurant_id = ? AND status = 'delivered'`).get(id);
  const active = db.prepare(`SELECT COUNT(*) AS n FROM orders WHERE restaurant_id = ?
    AND status IN ('pending','accepted','preparing','ready')`).get(id).n;
  res.json({ today, all_time: all, active, commission_pct: req.restaurant.commission_pct });
});

// --- Menu ---
const MENU_FIELDS = ['name_en', 'name_ar', 'desc_en', 'desc_ar', 'section_en', 'section_ar', 'price', 'image_url', 'available'];

router.get('/menu', (req, res) => {
  res.json(db.prepare('SELECT * FROM menu_items WHERE restaurant_id = ? ORDER BY section_en, id').all(req.restaurant.id));
});

router.post('/menu', (req, res) => {
  const b = req.body || {};
  if (!b.name_en || !b.name_ar || !(Number(b.price) > 0)) return res.status(400).json({ error: 'missing_fields' });
  const { lastInsertRowid } = db.prepare(`INSERT INTO menu_items
    (restaurant_id, name_en, name_ar, desc_en, desc_ar, section_en, section_ar, price, image_url, available)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`).run(
    req.restaurant.id, b.name_en, b.name_ar, b.desc_en || '', b.desc_ar || '',
    b.section_en || 'Menu', b.section_ar || 'القائمة', Number(b.price), b.image_url || null, b.available === false ? 0 : 1);
  res.status(201).json(db.prepare('SELECT * FROM menu_items WHERE id = ?').get(lastInsertRowid));
});

router.patch('/menu/:id', (req, res) => {
  const item = db.prepare('SELECT * FROM menu_items WHERE id = ? AND restaurant_id = ?').get(req.params.id, req.restaurant.id);
  if (!item) return res.status(404).json({ error: 'not_found' });
  const b = req.body || {};
  if ('price' in b && !(Number(b.price) > 0)) return res.status(400).json({ error: 'invalid_price' });
  const fields = MENU_FIELDS.filter((f) => f in b);
  if (fields.length) {
    const vals = fields.map((f) => (f === 'available' ? (b[f] ? 1 : 0) : f === 'price' ? Number(b[f]) : b[f]));
    db.prepare(`UPDATE menu_items SET ${fields.map((f) => `${f} = ?`).join(', ')} WHERE id = ?`).run(...vals, item.id);
  }
  res.json(db.prepare('SELECT * FROM menu_items WHERE id = ?').get(item.id));
});

router.delete('/menu/:id', (req, res) => {
  const r = db.prepare('DELETE FROM menu_items WHERE id = ? AND restaurant_id = ?').run(req.params.id, req.restaurant.id);
  if (!r.changes) return res.status(404).json({ error: 'not_found' });
  res.status(204).end();
});

module.exports = router;
