// Shared order helpers: loading full orders and enforcing the status workflow.
const { db } = require('./db');

// pending -> accepted -> preparing -> ready -> picked_up -> delivered
// pending -> rejected (restaurant) | cancelled (customer)
const TRANSITIONS = {
  restaurant: {
    pending: ['accepted', 'rejected'],
    accepted: ['preparing'],
    preparing: ['ready'],
  },
  driver: {
    ready: ['picked_up'],
    picked_up: ['delivered'],
  },
  customer: {
    pending: ['cancelled'],
  },
};
// Admin can force any non-final order to any status (support use case).
const FINAL = ['delivered', 'rejected', 'cancelled'];
const ALL_STATUSES = ['pending', 'accepted', 'preparing', 'ready', 'picked_up', 'delivered', 'rejected', 'cancelled'];

function canTransition(role, from, to) {
  if (role === 'admin') return !FINAL.includes(from) && ALL_STATUSES.includes(to) && from !== to;
  return (TRANSITIONS[role]?.[from] || []).includes(to);
}

function setStatus(orderId, status) {
  db.prepare("UPDATE orders SET status = ?, updated_at = datetime('now') WHERE id = ?").run(status, orderId);
  db.prepare('INSERT INTO order_events (order_id, status) VALUES (?, ?)').run(orderId, status);
}

const ORDER_SELECT = `
  SELECT o.*,
    r.name_en AS restaurant_name_en, r.name_ar AS restaurant_name_ar,
    c.name AS customer_name, c.phone AS customer_phone,
    d.name AS driver_name, d.phone AS driver_phone
  FROM orders o
  JOIN restaurants r ON r.id = o.restaurant_id
  JOIN users c ON c.id = o.customer_id
  LEFT JOIN users d ON d.id = o.driver_id`;

function withDetails(orders) {
  if (!orders.length) return orders;
  const ids = orders.map((o) => o.id);
  const ph = ids.map(() => '?').join(',');
  const items = db.prepare(`SELECT * FROM order_items WHERE order_id IN (${ph})`).all(...ids);
  const events = db.prepare(`SELECT * FROM order_events WHERE order_id IN (${ph}) ORDER BY id`).all(...ids);
  return orders.map((o) => ({
    ...o,
    items: items.filter((i) => i.order_id === o.id),
    events: events.filter((e) => e.order_id === o.id),
  }));
}

function listOrders(where = '', params = [], limit = 200) {
  const rows = db.prepare(`${ORDER_SELECT} ${where} ORDER BY o.id DESC LIMIT ${Number(limit)}`).all(...params);
  return withDetails(rows);
}

function getOrder(id) {
  return listOrders('WHERE o.id = ?', [id])[0] || null;
}

module.exports = { canTransition, setStatus, listOrders, getOrder, ALL_STATUSES, FINAL };
