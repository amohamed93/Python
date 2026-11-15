// Delivery driver endpoints: go online, claim orders, update pickup/delivery.
const express = require('express');
const { db } = require('../db');
const { requireAuth, publicUser } = require('../auth');
const { canTransition, setStatus, listOrders, getOrder } = require('../orders');

const router = express.Router();
router.use(requireAuth('driver'));

router.patch('/me', (req, res) => {
  const { is_online } = req.body || {};
  db.prepare('UPDATE users SET is_online = ? WHERE id = ?').run(is_online ? 1 : 0, req.user.id);
  res.json({ user: publicUser(db.prepare('SELECT * FROM users WHERE id = ?').get(req.user.id)) });
});

// Orders the restaurant has accepted and that no driver has claimed yet.
router.get('/available', (req, res) => {
  if (!req.user.is_online) return res.json([]);
  res.json(listOrders("WHERE o.driver_id IS NULL AND o.status IN ('accepted','preparing','ready')"));
});

router.get('/orders', (req, res) => {
  const { status } = req.query;
  if (status === 'active') {
    return res.json(listOrders("WHERE o.driver_id = ? AND o.status NOT IN ('delivered','cancelled','rejected')", [req.user.id]));
  }
  res.json(listOrders('WHERE o.driver_id = ?', [req.user.id]));
});

router.post('/orders/:id/accept', (req, res) => {
  if (!req.user.is_online) return res.status(400).json({ error: 'driver_offline' });
  // Atomic claim: only succeeds if nobody else took it first.
  const r = db.prepare(`UPDATE orders SET driver_id = ?, updated_at = datetime('now')
    WHERE id = ? AND driver_id IS NULL AND status IN ('accepted','preparing','ready')`).run(req.user.id, req.params.id);
  if (!r.changes) return res.status(409).json({ error: 'order_unavailable' });
  res.json(getOrder(req.params.id));
});

router.post('/orders/:id/status', (req, res) => {
  const o = db.prepare('SELECT * FROM orders WHERE id = ? AND driver_id = ?').get(req.params.id, req.user.id);
  if (!o) return res.status(404).json({ error: 'not_found' });
  const { status } = req.body || {};
  if (!canTransition('driver', o.status, status)) return res.status(400).json({ error: 'invalid_transition', from: o.status, to: status });
  setStatus(o.id, status);
  res.json(getOrder(o.id));
});

router.get('/stats', (req, res) => {
  const row = db.prepare(`SELECT COUNT(*) AS deliveries, COALESCE(SUM(delivery_fee),0) AS earnings
    FROM orders WHERE driver_id = ? AND status = 'delivered'`).get(req.user.id);
  const today = db.prepare(`SELECT COUNT(*) AS deliveries, COALESCE(SUM(delivery_fee),0) AS earnings
    FROM orders WHERE driver_id = ? AND status = 'delivered' AND date(updated_at) = date('now')`).get(req.user.id);
  res.json({ all_time: row, today });
});

module.exports = router;
