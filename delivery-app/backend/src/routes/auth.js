const express = require('express');
const bcrypt = require('bcryptjs');
const { db } = require('../db');
const { signToken, publicUser, requireAuth } = require('../auth');

const router = express.Router();

// Self sign-up is allowed for customers and drivers. Restaurant accounts are created by an admin.
router.post('/register', (req, res) => {
  const { name, email, phone, password, role = 'customer' } = req.body || {};
  if (!name || !email || !password) return res.status(400).json({ error: 'missing_fields' });
  if (String(password).length < 6) return res.status(400).json({ error: 'password_too_short' });
  if (!['customer', 'driver'].includes(role)) return res.status(400).json({ error: 'invalid_role' });
  const normEmail = String(email).trim().toLowerCase();
  if (db.prepare('SELECT 1 FROM users WHERE email = ?').get(normEmail)) {
    return res.status(409).json({ error: 'email_taken' });
  }
  const hash = bcrypt.hashSync(String(password), 10);
  const { lastInsertRowid } = db
    .prepare('INSERT INTO users (name, email, phone, password_hash, role) VALUES (?, ?, ?, ?, ?)')
    .run(String(name).trim(), normEmail, phone || null, hash, role);
  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(lastInsertRowid);
  res.status(201).json({ token: signToken(user), user: publicUser(user) });
});

router.post('/login', (req, res) => {
  const { email, password } = req.body || {};
  if (!email || !password) return res.status(400).json({ error: 'missing_fields' });
  const user = db.prepare('SELECT * FROM users WHERE email = ?').get(String(email).trim().toLowerCase());
  if (!user || !bcrypt.compareSync(String(password), user.password_hash)) {
    return res.status(401).json({ error: 'invalid_credentials' });
  }
  if (!user.active) return res.status(403).json({ error: 'account_disabled' });
  res.json({ token: signToken(user), user: publicUser(user) });
});

router.get('/me', requireAuth(), (req, res) => res.json({ user: publicUser(req.user) }));

router.patch('/me', requireAuth(), (req, res) => {
  const { name, phone } = req.body || {};
  db.prepare('UPDATE users SET name = COALESCE(?, name), phone = COALESCE(?, phone) WHERE id = ?')
    .run(name ?? null, phone ?? null, req.user.id);
  res.json({ user: publicUser(db.prepare('SELECT * FROM users WHERE id = ?').get(req.user.id)) });
});

module.exports = router;
