// End-to-end API test: walks one order through every role.
const path = require('node:path');
const os = require('node:os');
const fs = require('node:fs');
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'delivery-test-'));
process.env.DB_FILE = path.join(tmp, 'test.db');

const { createApp } = require('../src/app');
const { seed, PASSWORD } = require('../src/seed');

let server;
let base;

before(async () => {
  seed();
  server = createApp().listen(0);
  await new Promise((r) => server.once('listening', r));
  base = `http://127.0.0.1:${server.address().port}/api`;
});
after(() => {
  server.close();
  fs.rmSync(tmp, { recursive: true, force: true });
});

async function call(method, url, token, body) {
  const res = await fetch(base + url, {
    method,
    headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  return { status: res.status, body: text ? JSON.parse(text) : null };
}
const login = async (email, password = PASSWORD) => (await call('POST', '/auth/login', null, { email, password })).body.token;

test('full order lifecycle across customer, restaurant, driver and admin', async () => {
  const [customer, restaurant, driver, admin] = await Promise.all(
    ['customer@demo.com', 'burger@demo.com', 'driver@demo.com', 'admin@demo.com'].map((e) => login(e)));

  const list = await call('GET', '/restaurants');
  assert.equal(list.status, 200);
  const burger = list.body.find((r) => r.name_en === 'Burger House');
  const detail = await call('GET', `/restaurants/${burger.id}`);
  const [item1, item2] = detail.body.menu;

  // Below minimum order is rejected.
  const tooSmall = await call('POST', '/orders', customer, {
    restaurant_id: burger.id, items: [{ menu_item_id: detail.body.menu.find((m) => m.price < 50).id, qty: 1 }], address: 'x',
  });
  assert.equal(tooSmall.body.error, 'below_min_order');

  // Client-supplied prices are ignored; server computes totals.
  const placed = await call('POST', '/orders', customer, {
    restaurant_id: burger.id, address: '12 Tahrir St, Cairo',
    items: [{ menu_item_id: item1.id, qty: 2, price: 1 }, { menu_item_id: item2.id, qty: 1 }],
  });
  assert.equal(placed.status, 201);
  const order = placed.body;
  const expectedSubtotal = item1.price * 2 + item2.price;
  assert.equal(order.subtotal, expectedSubtotal);
  assert.equal(order.total, expectedSubtotal + burger.delivery_fee + 5);
  assert.equal(order.status, 'pending');

  // Wrong role / wrong transitions are blocked.
  assert.equal((await call('POST', `/driver/orders/${order.id}/status`, driver, { status: 'picked_up' })).status, 404);
  assert.equal((await call('POST', `/restaurant/orders/${order.id}/status`, restaurant, { status: 'ready' })).status, 400);
  assert.equal((await call('GET', '/admin/stats', customer)).status, 403);

  // Restaurant accepts -> driver claims -> restaurant prepares -> ready.
  assert.equal((await call('POST', `/restaurant/orders/${order.id}/status`, restaurant, { status: 'accepted' })).body.status, 'accepted');
  const avail = await call('GET', '/driver/available', driver);
  assert.ok(avail.body.some((o) => o.id === order.id));
  assert.equal((await call('POST', `/driver/orders/${order.id}/accept`, driver)).status, 200);
  assert.equal((await call('POST', `/driver/orders/${order.id}/accept`, driver)).status, 409);
  await call('POST', `/restaurant/orders/${order.id}/status`, restaurant, { status: 'preparing' });
  await call('POST', `/restaurant/orders/${order.id}/status`, restaurant, { status: 'ready' });

  // Customer can no longer cancel.
  assert.equal((await call('POST', `/orders/${order.id}/cancel`, customer)).body.error, 'cannot_cancel');

  // Driver delivers.
  await call('POST', `/driver/orders/${order.id}/status`, driver, { status: 'picked_up' });
  const done = await call('POST', `/driver/orders/${order.id}/status`, driver, { status: 'delivered' });
  assert.equal(done.body.status, 'delivered');
  assert.deepEqual(done.body.events.map((e) => e.status),
    ['pending', 'accepted', 'preparing', 'ready', 'picked_up', 'delivered']);

  // Customer sees it, and stats add up.
  const mine = await call('GET', `/orders/${order.id}`, customer);
  assert.equal(mine.body.driver_name, 'Mohamed Driver');
  const stats = await call('GET', '/admin/stats', admin);
  assert.equal(stats.body.delivered_orders, 1);
  const dstats = await call('GET', '/driver/stats', driver);
  assert.equal(dstats.body.all_time.earnings, burger.delivery_fee);

  // Other customers can't see this order.
  const other = (await call('POST', '/auth/register', null, { name: 'B', email: 'b@x.com', password: 'secret1' })).body.token;
  assert.equal((await call('GET', `/orders/${order.id}`, other)).status, 404);
});

test('admin creates a restaurant and disables a user', async () => {
  const admin = await login('admin@demo.com');
  const created = await call('POST', '/admin/restaurants', admin, {
    name_en: 'Shawarma King', name_ar: 'ملك الشاورما', owner_email: 'shawarma@demo.com', owner_password: 'secret1',
    category_en: 'Syrian', category_ar: 'سوري',
  });
  assert.equal(created.status, 201);
  const owner = await login('shawarma@demo.com', 'secret1');
  const menuItem = await call('POST', '/restaurant/menu', owner, { name_en: 'Shawarma', name_ar: 'شاورما', price: 60 });
  assert.equal(menuItem.status, 201);

  const users = await call('GET', '/admin/users?role=customer', admin);
  const cust = users.body.find((u) => u.email === 'customer@demo.com');
  await call('PATCH', `/admin/users/${cust.id}`, admin, { active: false });
  assert.equal((await call('POST', '/auth/login', null, { email: 'customer@demo.com', password: PASSWORD })).status, 403);
  await call('PATCH', `/admin/users/${cust.id}`, admin, { active: true });
});
