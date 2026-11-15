const { createApp } = require('./app');
const { db } = require('./db');
const { seed } = require('./seed');

// Seed demo data on first run so the app is usable immediately.
if (db.prepare('SELECT COUNT(*) AS n FROM users').get().n === 0) seed();

const PORT = Number(process.env.PORT) || 3000;
createApp().listen(PORT, '0.0.0.0', () => {
  console.log(`Delivery API listening on http://localhost:${PORT}`);
});
