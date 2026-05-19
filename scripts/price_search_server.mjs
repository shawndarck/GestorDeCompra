import http from 'node:http';
import { spawn } from 'node:child_process';
import { createHash, pbkdf2Sync, randomBytes, timingSafeEqual } from 'node:crypto';
import net from 'node:net';
import { existsSync } from 'node:fs';
import { mkdir } from 'node:fs/promises';
import path from 'node:path';
import tls from 'node:tls';
import { DatabaseSync } from 'node:sqlite';

const PORT = Number(process.env.PRICESEC_PORT ?? 8768);
const CDP_PORT = 9222;
const SMTP_HOST = process.env.PRICESEC_SMTP_HOST;
const SMTP_PORT = Number(process.env.PRICESEC_SMTP_PORT ?? 587);
const SMTP_USER = process.env.PRICESEC_SMTP_USER;
const SMTP_PASS = process.env.PRICESEC_SMTP_PASS;
const SMTP_FROM = process.env.PRICESEC_SMTP_FROM ?? SMTP_USER;
const ROOT = path.resolve(import.meta.dirname, '..');
const PROFILE_DIR = path.join(ROOT, '.pricesec-chrome-profile');
const DB_PATH = path.join(ROOT, 'pricesec.db');
const CHROME_PATHS = [
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
  'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
];

const stores = {
  aliexpress: {
    label: 'AliExpress',
    searchUrl: (query) =>
      `https://www.aliexpress.com/wholesale?SearchText=${encodeURIComponent(query)}`,
  },
  temu: {
    label: 'Temu',
    searchUrl: (query) =>
      `https://www.temu.com/search_result.html?search_key=${encodeURIComponent(query)}`,
  },
  shein: {
    label: 'Shein',
    searchUrl: (query) =>
      `https://co.shein.com/pdsearch/${encodeURIComponent(query)}/`,
  },
  amazon: {
    label: 'Amazon',
    searchUrl: (query) =>
      `https://www.amazon.com/s?k=${encodeURIComponent(query)}`,
  },
};

const setupMessage =
  'Necesitas abrir la ventana PriceSec Chrome, iniciar sesion en las tiendas seleccionadas y volver a comparar.';

const defaultPermissions = [
  ['view_sales', 'Ver ventas'],
  ['create_publications', 'Crear publicaciones'],
  ['edit_publications', 'Editar publicaciones'],
  ['delete_publications', 'Eliminar publicaciones'],
  ['view_inventory', 'Consultar inventario'],
  ['modify_inventory', 'Modificar inventario'],
  ['manage_stores', 'Gestionar tiendas'],
  ['manage_collaborators', 'Gestionar colaboradores'],
  ['view_reports', 'Ver reportes'],
  ['manage_settings', 'Administrar configuracion'],
];

const allPermissionKeys = defaultPermissions.map(([key]) => key);

const db = new DatabaseSync(DB_PATH);
db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL UNIQUE,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    salt TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'user',
    tenant_id INTEGER,
    parent_user_id INTEGER,
    status TEXT NOT NULL DEFAULT 'active',
    profile_name TEXT NOT NULL DEFAULT '',
    phone TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
  );

  CREATE TABLE IF NOT EXISTS user_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    token_hash TEXT NOT NULL UNIQUE,
    expires_at TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
  );

  CREATE TABLE IF NOT EXISTS password_reset_codes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    code_hash TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    used_at TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
  );

  CREATE TABLE IF NOT EXISTS auth_email_outbox (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    email TEXT NOT NULL,
    subject TEXT NOT NULL,
    body TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'local_outbox',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
  );

  CREATE TABLE IF NOT EXISTS purchases (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    product_name TEXT NOT NULL,
    price_usd REAL NOT NULL DEFAULT 0,
    trm REAL NOT NULL DEFAULT 0,
    quantity REAL NOT NULL DEFAULT 0,
    origin_shipping_usd REAL NOT NULL DEFAULT 0,
    card_commission_rate REAL NOT NULL DEFAULT 0,
    height_cm REAL NOT NULL DEFAULT 0,
    width_cm REAL NOT NULL DEFAULT 0,
    length_cm REAL NOT NULL DEFAULT 0,
    box_count REAL NOT NULL DEFAULT 0,
    cbm_rate REAL NOT NULL DEFAULT 0,
    national_freight REAL NOT NULL DEFAULT 0,
    mercado_libre_price REAL NOT NULL DEFAULT 0,
    mercado_libre_commission_rate REAL NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
  )
`);

db.exec(`
  CREATE TABLE IF NOT EXISTS tenants (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    owner_user_id INTEGER,
    name TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
  );

  CREATE TABLE IF NOT EXISTS permissions (
    key TEXT PRIMARY KEY,
    label TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS user_permissions (
    user_id INTEGER NOT NULL,
    permission_key TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, permission_key),
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (permission_key) REFERENCES permissions(key)
  );

  CREATE TABLE IF NOT EXISTS mercado_libre_stores (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tenant_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    store_user TEXT NOT NULL DEFAULT '',
    store_url TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT 'active',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (tenant_id) REFERENCES tenants(id)
  );

  CREATE TABLE IF NOT EXISTS aliexpress_viabilities (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    number REAL NOT NULL DEFAULT 0,
    product_name TEXT NOT NULL,
    product_link TEXT NOT NULL DEFAULT '',
    order_home_cost REAL NOT NULL DEFAULT 0,
    quantity REAL NOT NULL DEFAULT 0,
    unit_home_cost REAL NOT NULL DEFAULT 0,
    mercado_libre_total_price REAL NOT NULL DEFAULT 0,
    meli_commission_rate REAL NOT NULL DEFAULT 0,
    commission_free_price REAL NOT NULL DEFAULT 0,
    viability REAL NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
  )
`);

db.exec(`
  CREATE TABLE IF NOT EXISTS inventory_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    product_name TEXT NOT NULL,
    unit_purchase_value REAL NOT NULL DEFAULT 0,
    quantity REAL NOT NULL DEFAULT 0,
    public_sale_value REAL NOT NULL DEFAULT 0,
    loaded_at TEXT NOT NULL,
    warehouse TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
  );

  CREATE TABLE IF NOT EXISTS sales (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    inventory_item_id INTEGER NOT NULL,
    product_name TEXT NOT NULL,
    warehouse TEXT NOT NULL,
    sold_at TEXT NOT NULL,
    quantity REAL NOT NULL DEFAULT 0,
    unit_sale_value REAL NOT NULL DEFAULT 0,
    total_sale_value REAL NOT NULL DEFAULT 0,
    remaining_quantity REAL NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (inventory_item_id) REFERENCES inventory_items(id)
  )
`);

function tableColumns(tableName) {
  return db.prepare(`PRAGMA table_info(${tableName})`).all().map((row) => row.name);
}

function ensureColumn(tableName, columnName, definition) {
  if (!tableColumns(tableName).includes(columnName)) {
    db.exec(`ALTER TABLE ${tableName} ADD COLUMN ${columnName} ${definition}`);
  }
}

function runMigrations() {
  ensureColumn('users', 'tenant_id', 'INTEGER');
  ensureColumn('users', 'parent_user_id', 'INTEGER');
  ensureColumn('users', 'status', "TEXT NOT NULL DEFAULT 'active'");
  ensureColumn('users', 'profile_name', "TEXT NOT NULL DEFAULT ''");
  ensureColumn('users', 'phone', "TEXT NOT NULL DEFAULT ''");
  for (const table of ['purchases', 'aliexpress_viabilities', 'inventory_items', 'sales']) {
    ensureColumn(table, 'tenant_id', 'INTEGER');
  }
  for (const [key, label] of defaultPermissions) {
    db.prepare('INSERT OR IGNORE INTO permissions (key, label) VALUES (?, ?)').run(key, label);
  }
}

function ensureTenantForOwner(user) {
  if (user.tenant_id) return user.tenant_id;
  const result = db
    .prepare('INSERT INTO tenants (owner_user_id, name) VALUES (?, ?)')
    .run(user.id, user.profile_name || user.username);
  const tenantId = Number(result.lastInsertRowid);
  db.prepare(
    'UPDATE users SET tenant_id = ?, role = ?, status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
  ).run(tenantId, 'owner', 'active', user.id);
  db.prepare('UPDATE tenants SET owner_user_id = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?').run(
    user.id,
    tenantId,
  );
  return tenantId;
}

function backfillLegacyTenant() {
  const tenantRows = db.prepare('SELECT COUNT(*) AS count FROM tenants').get().count;
  const owner = db
    .prepare("SELECT * FROM users WHERE role IN ('owner', 'user') ORDER BY id LIMIT 1")
    .get();
  const legacyRows = ['purchases', 'aliexpress_viabilities', 'inventory_items', 'sales'].some(
    (table) => db.prepare(`SELECT COUNT(*) AS count FROM ${table} WHERE tenant_id IS NULL`).get().count > 0,
  );
  if (!owner && !legacyRows) return;
  if (!owner && tenantRows > 0) return;
  let tenantId = owner ? ensureTenantForOwner(owner) : null;
  if (!tenantId && tenantRows === 0) {
    const result = db.prepare('INSERT INTO tenants (name, status) VALUES (?, ?)').run(
      'Tenant legado PriceSec',
      'active',
    );
    tenantId = Number(result.lastInsertRowid);
  }
  if (!tenantId) return;
  db.prepare("UPDATE users SET role = 'owner', tenant_id = ? WHERE role = 'user'").run(tenantId);
  for (const table of ['purchases', 'aliexpress_viabilities', 'inventory_items', 'sales']) {
    db.prepare(`UPDATE ${table} SET tenant_id = ? WHERE tenant_id IS NULL`).run(tenantId);
  }
}

function seedInitialUsers() {
  const seedAdmin = process.env.PRICESEC_SEED_ADMIN === 'true';
  const seedExamples = process.env.PRICESEC_SEED_EXAMPLES === 'true';
  if (seedAdmin && !db.prepare("SELECT id FROM users WHERE username = 'SHAWNDARCK'").get()) {
    const { hash, salt } = hashPassword('PriceSecAdmin2026!');
    db.prepare(
      `
        INSERT INTO users (username, email, password_hash, salt, role, status, profile_name)
        VALUES (?, ?, ?, ?, 'super_admin', 'active', ?)
      `,
    ).run('SHAWNDARCK', 'admin@pricesec.local', hash, salt, 'SHAWNDARCK');
  }

  if (!seedExamples) return;
  let owner = db.prepare("SELECT * FROM users WHERE username = 'cliente_demo'").get();
  if (!owner) {
    createPrincipalUser({
      username: 'cliente_demo',
      email: 'cliente.demo@pricesec.local',
      password: 'ClienteDemo2026!',
      profileName: 'Cliente demo PriceSec',
      phone: '3000000000',
    });
    owner = db.prepare("SELECT * FROM users WHERE username = 'cliente_demo'").get();
  }
  if (owner) {
    const storeCount = db
      .prepare('SELECT COUNT(*) AS count FROM mercado_libre_stores WHERE tenant_id = ?')
      .get(owner.tenant_id).count;
    if (storeCount === 0) {
      createMercadoLibreStore(
        { role: 'owner', id: owner.id, tenant_id: owner.tenant_id },
        {
          name: 'Tienda Demo Principal',
          storeUser: 'cliente_demo_meli',
          storeUrl: 'https://www.mercadolibre.com.co/perfil/cliente_demo',
        },
      );
      createMercadoLibreStore(
        { role: 'owner', id: owner.id, tenant_id: owner.tenant_id },
        {
          name: 'Tienda Demo Outlet',
          storeUser: 'cliente_demo_outlet',
          storeUrl: 'https://www.mercadolibre.com.co/perfil/cliente_demo_outlet',
        },
      );
    }
    const collaboratorExists = db.prepare("SELECT id FROM users WHERE username = 'colaborador_demo'").get();
    if (!collaboratorExists) {
      createCollaborator(
        { role: 'owner', id: owner.id, tenant_id: owner.tenant_id },
        {
          username: 'colaborador_demo',
          email: 'colaborador.demo@pricesec.local',
          password: 'Colaborador2026!',
          profileName: 'Colaborador demo',
          permissions: ['view_inventory', 'view_sales', 'view_reports'],
        },
      );
    }
  }
}

runMigrations();

function json(res, status, body) {
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Allow-Private-Network': 'true',
  });
  res.end(JSON.stringify(body));
}

async function readJson(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  return JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}');
}

function hashToken(value) {
  return createHash('sha256').update(value).digest('hex');
}

function hashPassword(password, salt = randomBytes(16).toString('hex')) {
  const hash = pbkdf2Sync(String(password), salt, 120000, 32, 'sha256').toString(
    'hex',
  );
  return { hash, salt };
}

function verifyPassword(password, user) {
  const { hash } = hashPassword(password, user.salt);
  const stored = Buffer.from(user.password_hash, 'hex');
  const incoming = Buffer.from(hash, 'hex');
  return stored.length === incoming.length && timingSafeEqual(stored, incoming);
}

function publicUser(row) {
  const permissions = permissionsForUser(row);
  return {
    id: row.id,
    username: row.username,
    email: row.email,
    role: row.role,
    tenantId: row.tenant_id ?? null,
    parentUserId: row.parent_user_id ?? null,
    status: row.status ?? 'active',
    profileName: row.profile_name ?? '',
    phone: row.phone ?? '',
    permissions,
    stores: row.tenant_id ? listMercadoLibreStores(row) : [],
  };
}

function createSession(user) {
  const token = randomBytes(32).toString('hex');
  const expiresAt = new Date(Date.now() + 1000 * 60 * 60 * 12).toISOString();
  db.prepare(
    'INSERT INTO user_sessions (user_id, token_hash, expires_at) VALUES (?, ?, ?)',
  ).run(user.id, hashToken(token), expiresAt);
  return { token, expiresAt, user: publicUser(user) };
}

function getAuthUser(req) {
  const header = req.headers.authorization ?? '';
  const token = header.startsWith('Bearer ') ? header.slice(7).trim() : '';
  if (!token) return null;
  const row = db
    .prepare(
      `
        SELECT users.*
        FROM user_sessions
        JOIN users ON users.id = user_sessions.user_id
        WHERE user_sessions.token_hash = ?
          AND user_sessions.expires_at > CURRENT_TIMESTAMP
          AND users.status = 'active'
      `,
    )
    .get(hashToken(token));
  return row ?? null;
}

function requireAuth(req, res) {
  const user = getAuthUser(req);
  if (!user) {
    json(res, 401, { message: 'Debes iniciar sesion en PriceSec.' });
    return null;
  }
  return user;
}

function permissionsForUser(user) {
  if (!user) return [];
  if (user.role === 'super_admin' || user.role === 'owner') return allPermissionKeys;
  return db
    .prepare('SELECT permission_key FROM user_permissions WHERE user_id = ? ORDER BY permission_key')
    .all(user.id)
    .map((row) => row.permission_key);
}

function hasPermission(user, permissionKey) {
  if (!permissionKey) return true;
  if (user.role === 'super_admin' || user.role === 'owner') return true;
  return permissionsForUser(user).includes(permissionKey);
}

function requireRole(user, roles) {
  const allowed = Array.isArray(roles) ? roles : [roles];
  if (!allowed.includes(user.role)) {
    throw new Error('No tienes permisos para realizar esta accion.');
  }
}

function requirePermission(user, permissionKey) {
  if (!hasPermission(user, permissionKey)) {
    throw new Error('No tienes permisos para realizar esta accion.');
  }
}

function requireTenant(user) {
  if (!user.tenant_id) throw new Error('Este usuario no tiene tenant asociado.');
  return user.tenant_id;
}

function registerUser(input) {
  const username = String(input.username ?? '').trim();
  const email = String(input.email ?? '').trim().toLowerCase();
  const password = String(input.password ?? '');
  if (username.length < 3) throw new Error('El usuario debe tener minimo 3 caracteres.');
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    throw new Error('Escribe un correo valido.');
  }
  if (password.length < 8) throw new Error('La contraseña debe tener minimo 8 caracteres.');
  const userCount = db.prepare('SELECT COUNT(*) AS count FROM users').get().count;
  if (userCount > 0) {
    throw new Error('Solo el Super Admin puede crear nuevos usuarios principales.');
  }
  const { hash, salt } = hashPassword(password);
  const result = db
    .prepare(
      `
        INSERT INTO users (username, email, password_hash, salt, role, status, profile_name)
        VALUES (?, ?, ?, ?, 'super_admin', 'active', ?)
      `,
    )
    .run(username, email, hash, salt, username);
  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(Number(result.lastInsertRowid));
  if (user.status !== 'active') {
    throw new Error('Este usuario esta inactivo.');
  }
  return createSession(user);
}

function loginUser(input) {
  const username = String(input.username ?? '').trim();
  const password = String(input.password ?? '');
  const user = db
    .prepare('SELECT * FROM users WHERE username = ? OR email = ?')
    .get(username, username.toLowerCase());
  if (!user || !verifyPassword(password, user)) {
    throw new Error('Usuario o contraseña incorrectos.');
  }
  if (user.status !== 'active') {
    throw new Error('Este usuario esta inactivo.');
  }
  return createSession(user);
}

async function requestPasswordReset(input) {
  const email = String(input.email ?? '').trim().toLowerCase();
  const user = db.prepare('SELECT * FROM users WHERE email = ?').get(email);
  if (!user) return { ok: true };
  const recent = db
    .prepare(
      `
        SELECT id FROM password_reset_codes
        WHERE user_id = ?
          AND created_at > datetime('now', '-2 minutes')
          AND used_at IS NULL
        ORDER BY id DESC LIMIT 1
      `,
    )
    .get(user.id);
  if (recent) return { ok: true, throttled: true };

  const code = String(Math.floor(100000 + Math.random() * 900000));
  const expiresAt = new Date(Date.now() + 1000 * 60 * 10).toISOString();
  db.prepare(
    'INSERT INTO password_reset_codes (user_id, code_hash, expires_at) VALUES (?, ?, ?)',
  ).run(user.id, hashToken(code), expiresAt);

  const subject = 'Codigo de seguridad PriceSec';
  const body = `Tu codigo de seguridad PriceSec es ${code}. Expira en 10 minutos. Si no lo solicitaste, ignora este mensaje.`;
  const outbox = db.prepare(
    'INSERT INTO auth_email_outbox (user_id, email, subject, body) VALUES (?, ?, ?, ?)',
  ).run(user.id, user.email, subject, body);
  try {
    const sent = await sendSmtpMail({ to: user.email, subject, body });
    if (sent) {
      db.prepare('UPDATE auth_email_outbox SET status = ? WHERE id = ?').run(
        'sent',
        Number(outbox.lastInsertRowid),
      );
      return { ok: true, sent: true };
    }
  } catch (error) {
    console.warn(`PriceSec SMTP error: ${error?.message ?? error}`);
  }
  console.log(`PriceSec reset code for ${user.email}: ${code}`);
  return { ok: true, localOutbox: true };
}

function confirmPasswordReset(input) {
  const email = String(input.email ?? '').trim().toLowerCase();
  const code = String(input.code ?? '').trim();
  const password = String(input.password ?? '');
  if (password.length < 8) throw new Error('La contraseña debe tener minimo 8 caracteres.');
  const user = db.prepare('SELECT * FROM users WHERE email = ?').get(email);
  if (!user) throw new Error('Codigo invalido o vencido.');
  const reset = db
    .prepare(
      `
        SELECT * FROM password_reset_codes
        WHERE user_id = ?
          AND code_hash = ?
          AND expires_at > CURRENT_TIMESTAMP
          AND used_at IS NULL
        ORDER BY id DESC LIMIT 1
      `,
    )
    .get(user.id, hashToken(code));
  if (!reset) throw new Error('Codigo invalido o vencido.');
  const { hash, salt } = hashPassword(password);
  db.prepare(
    'UPDATE users SET password_hash = ?, salt = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
  ).run(hash, salt, user.id);
  db.prepare('UPDATE password_reset_codes SET used_at = CURRENT_TIMESTAMP WHERE id = ?').run(
    reset.id,
  );
  db.prepare('DELETE FROM user_sessions WHERE user_id = ?').run(user.id);
  return { ok: true };
}

function normalizePermissionList(input) {
  const values = Array.isArray(input) ? input : [];
  return [...new Set(values.map(String).filter((key) => allPermissionKeys.includes(key)))];
}

function listPermissions() {
  return db.prepare('SELECT key, label FROM permissions ORDER BY label').all();
}

function createPrincipalUser(input) {
  const username = String(input.username ?? '').trim();
  const email = String(input.email ?? '').trim().toLowerCase();
  const password = String(input.password ?? '');
  const profileName = String(input.profileName ?? input.profile_name ?? username).trim();
  const phone = String(input.phone ?? '').trim();
  if (username.length < 3) throw new Error('El usuario debe tener minimo 3 caracteres.');
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) throw new Error('Escribe un correo valido.');
  if (password.length < 8) throw new Error('La contrasena debe tener minimo 8 caracteres.');
  const { hash, salt } = hashPassword(password);
  const userResult = db
    .prepare(
      `
        INSERT INTO users (
          username, email, password_hash, salt, role, status, profile_name, phone
        ) VALUES (?, ?, ?, ?, 'owner', 'active', ?, ?)
      `,
    )
    .run(username, email, hash, salt, profileName, phone);
  const userId = Number(userResult.lastInsertRowid);
  const tenantResult = db
    .prepare('INSERT INTO tenants (owner_user_id, name, status) VALUES (?, ?, ?)')
    .run(userId, profileName || username, 'active');
  const tenantId = Number(tenantResult.lastInsertRowid);
  db.prepare('UPDATE users SET tenant_id = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?').run(
    tenantId,
    userId,
  );
  return {
    ...publicUser(db.prepare('SELECT * FROM users WHERE id = ?').get(userId)),
    tenantId,
  };
}

function listPrincipalUsers() {
  return db
    .prepare(
      `
        SELECT users.*, tenants.name AS tenant_name
        FROM users
        LEFT JOIN tenants ON tenants.id = users.tenant_id
        WHERE users.role = 'owner'
        ORDER BY users.created_at DESC, users.id DESC
      `,
    )
    .all()
    .map((row) => ({ ...publicUser(row), tenantName: row.tenant_name ?? '' }));
}

function updatePrincipalUser(id, input) {
  const row = db.prepare("SELECT * FROM users WHERE id = ? AND role = 'owner'").get(id);
  if (!row) throw new Error('Usuario principal no encontrado.');
  const profileName = String(input.profileName ?? input.profile_name ?? row.profile_name ?? '').trim();
  const phone = String(input.phone ?? row.phone ?? '').trim();
  const status = String(input.status ?? row.status ?? 'active');
  if (!['active', 'inactive'].includes(status)) throw new Error('Estado invalido.');
  db.prepare(
    `
      UPDATE users
      SET profile_name = ?, phone = ?, status = ?, updated_at = CURRENT_TIMESTAMP
      WHERE id = ?
    `,
  ).run(profileName, phone, status, id);
  if (row.tenant_id) {
    db.prepare('UPDATE tenants SET name = ?, status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?').run(
      profileName || row.username,
      status,
      row.tenant_id,
    );
  }
  return publicUser(db.prepare('SELECT * FROM users WHERE id = ?').get(id));
}

function createCollaborator(user, input) {
  const tenantId = requireTenant(user);
  requirePermission(user, 'manage_collaborators');
  const username = String(input.username ?? '').trim();
  const email = String(input.email ?? '').trim().toLowerCase();
  const password = String(input.password ?? '');
  const profileName = String(input.profileName ?? input.profile_name ?? username).trim();
  const permissions = normalizePermissionList(input.permissions);
  if (username.length < 3) throw new Error('El usuario debe tener minimo 3 caracteres.');
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) throw new Error('Escribe un correo valido.');
  if (password.length < 8) throw new Error('La contrasena debe tener minimo 8 caracteres.');
  const { hash, salt } = hashPassword(password);
  const result = db
    .prepare(
      `
        INSERT INTO users (
          username, email, password_hash, salt, role, tenant_id, parent_user_id,
          status, profile_name
        ) VALUES (?, ?, ?, ?, 'collaborator', ?, ?, 'active', ?)
      `,
    )
    .run(username, email, hash, salt, tenantId, user.id, profileName);
  const collaboratorId = Number(result.lastInsertRowid);
  setUserPermissions(collaboratorId, permissions);
  return publicUser(db.prepare('SELECT * FROM users WHERE id = ?').get(collaboratorId));
}

function listCollaborators(user) {
  const tenantId = requireTenant(user);
  requirePermission(user, 'manage_collaborators');
  return db
    .prepare(
      `
        SELECT * FROM users
        WHERE role = 'collaborator' AND tenant_id = ?
        ORDER BY created_at DESC, id DESC
      `,
    )
    .all(tenantId)
    .map(publicUser);
}

function setUserPermissions(userId, permissions) {
  db.prepare('DELETE FROM user_permissions WHERE user_id = ?').run(userId);
  for (const permission of normalizePermissionList(permissions)) {
    db.prepare('INSERT OR IGNORE INTO user_permissions (user_id, permission_key) VALUES (?, ?)').run(
      userId,
      permission,
    );
  }
}

function updateCollaborator(user, id, input) {
  const tenantId = requireTenant(user);
  requirePermission(user, 'manage_collaborators');
  const collaborator = db
    .prepare("SELECT * FROM users WHERE id = ? AND role = 'collaborator' AND tenant_id = ?")
    .get(id, tenantId);
  if (!collaborator) throw new Error('Colaborador no encontrado.');
  const profileName = String(input.profileName ?? input.profile_name ?? collaborator.profile_name ?? '').trim();
  const status = String(input.status ?? collaborator.status ?? 'active');
  if (!['active', 'inactive'].includes(status)) throw new Error('Estado invalido.');
  db.prepare(
    'UPDATE users SET profile_name = ?, status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
  ).run(profileName, status, id);
  if (Array.isArray(input.permissions)) setUserPermissions(id, input.permissions);
  return publicUser(db.prepare('SELECT * FROM users WHERE id = ?').get(id));
}

function mercadoLibreStoreFromRow(row) {
  return {
    id: row.id,
    tenantId: row.tenant_id,
    name: row.name,
    storeUser: row.store_user,
    storeUrl: row.store_url,
    status: row.status,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function listMercadoLibreStores(user) {
  if (!user?.tenant_id) return [];
  return db
    .prepare('SELECT * FROM mercado_libre_stores WHERE tenant_id = ? ORDER BY id DESC')
    .all(user.tenant_id)
    .map(mercadoLibreStoreFromRow);
}

function createMercadoLibreStore(user, input) {
  const tenantId = requireTenant(user);
  requirePermission(user, 'manage_stores');
  const name = String(input.name ?? '').trim();
  const storeUser = String(input.storeUser ?? input.store_user ?? '').trim();
  const storeUrl = String(input.storeUrl ?? input.store_url ?? '').trim();
  if (!name) throw new Error('El nombre de la tienda es obligatorio.');
  const result = db
    .prepare(
      `
        INSERT INTO mercado_libre_stores (tenant_id, name, store_user, store_url, status)
        VALUES (?, ?, ?, ?, 'active')
      `,
    )
    .run(tenantId, name, storeUser, storeUrl);
  return mercadoLibreStoreFromRow(
    db.prepare('SELECT * FROM mercado_libre_stores WHERE id = ?').get(Number(result.lastInsertRowid)),
  );
}

function updateMercadoLibreStore(user, id, input) {
  const tenantId = requireTenant(user);
  requirePermission(user, 'manage_stores');
  const current = db
    .prepare('SELECT * FROM mercado_libre_stores WHERE id = ? AND tenant_id = ?')
    .get(id, tenantId);
  if (!current) throw new Error('Tienda no encontrada.');
  const status = String(input.status ?? current.status ?? 'active');
  if (!['active', 'inactive'].includes(status)) throw new Error('Estado invalido.');
  db.prepare(
    `
      UPDATE mercado_libre_stores
      SET name = ?, store_user = ?, store_url = ?, status = ?, updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND tenant_id = ?
    `,
  ).run(
    String(input.name ?? current.name).trim(),
    String(input.storeUser ?? input.store_user ?? current.store_user).trim(),
    String(input.storeUrl ?? input.store_url ?? current.store_url).trim(),
    status,
    id,
    tenantId,
  );
  return mercadoLibreStoreFromRow(db.prepare('SELECT * FROM mercado_libre_stores WHERE id = ?').get(id));
}

function smtpConfigured() {
  return Boolean(SMTP_HOST && SMTP_PORT && SMTP_USER && SMTP_PASS && SMTP_FROM);
}

function encodeAddress(value) {
  const text = String(value ?? '').trim();
  const match = text.match(/<([^>]+)>/);
  return match ? match[1] : text;
}

function smtpRead(socket) {
  return new Promise((resolve, reject) => {
    let buffer = '';
    const onData = (chunk) => {
      buffer += chunk.toString('utf8');
      const lines = buffer.split(/\r?\n/).filter(Boolean);
      if (lines.length && /^[0-9]{3}\s/.test(lines.at(-1))) {
        cleanup();
        resolve(buffer);
      }
    };
    const onError = (error) => {
      cleanup();
      reject(error);
    };
    const cleanup = () => {
      socket.off('data', onData);
      socket.off('error', onError);
    };
    socket.on('data', onData);
    socket.on('error', onError);
  });
}

async function smtpCommand(socket, command, expected = [250]) {
  if (command) socket.write(`${command}\r\n`);
  const response = await smtpRead(socket);
  const code = Number(response.slice(0, 3));
  if (!expected.includes(code)) {
    throw new Error(`SMTP ${code}: ${response.trim()}`);
  }
  return response;
}

function smtpConnect() {
  return new Promise((resolve, reject) => {
    const socket = net.connect(SMTP_PORT, SMTP_HOST);
    socket.once('connect', () => resolve(socket));
    socket.once('error', reject);
  });
}

async function sendSmtpMail({ to, subject, body }) {
  if (!smtpConfigured()) return false;

  let socket = await smtpConnect();
  try {
    await smtpCommand(socket, null, [220]);
    await smtpCommand(socket, `EHLO ${process.env.COMPUTERNAME ?? 'pricesec.local'}`);
    await smtpCommand(socket, 'STARTTLS', [220]);

    socket = tls.connect({
      socket,
      servername: SMTP_HOST,
    });
    await new Promise((resolve, reject) => {
      socket.once('secureConnect', resolve);
      socket.once('error', reject);
    });

    await smtpCommand(socket, `EHLO ${process.env.COMPUTERNAME ?? 'pricesec.local'}`);
    await smtpCommand(socket, 'AUTH LOGIN', [334]);
    await smtpCommand(socket, Buffer.from(SMTP_USER).toString('base64'), [334]);
    await smtpCommand(socket, Buffer.from(SMTP_PASS).toString('base64'), [235]);
    await smtpCommand(socket, `MAIL FROM:<${encodeAddress(SMTP_FROM)}>`);
    await smtpCommand(socket, `RCPT TO:<${encodeAddress(to)}>`, [250, 251]);
    await smtpCommand(socket, 'DATA', [354]);

    const message = [
      `From: ${SMTP_FROM}`,
      `To: ${to}`,
      `Subject: ${subject}`,
      'MIME-Version: 1.0',
      'Content-Type: text/plain; charset=utf-8',
      '',
      body,
      '.',
      '',
    ].join('\r\n');
    socket.write(message);
    await smtpCommand(socket, null);
    await smtpCommand(socket, 'QUIT', [221]);
    return true;
  } finally {
    socket.destroy();
  }
}

async function ensureChrome() {
  if (await isCdpReady()) return;

  const chromePath = CHROME_PATHS.find(existsSync);
  if (!chromePath) {
    throw new Error('No encontre Chrome o Edge instalado.');
  }

  await mkdir(PROFILE_DIR, { recursive: true });
  spawn(
    chromePath,
    [
      `--remote-debugging-port=${CDP_PORT}`,
      `--user-data-dir=${PROFILE_DIR}`,
      '--no-first-run',
      '--no-default-browser-check',
      'about:blank',
    ],
    { detached: true, stdio: 'ignore' },
  ).unref();

  const deadline = Date.now() + 12000;
  while (Date.now() < deadline) {
    if (await isCdpReady()) return;
    await delay(350);
  }

  throw new Error(setupMessage);
}

async function isCdpReady() {
  try {
    const response = await fetch(`http://127.0.0.1:${CDP_PORT}/json/version`);
    return response.ok;
  } catch {
    return false;
  }
}

async function createTab(url) {
  const response = await fetch(
    `http://127.0.0.1:${CDP_PORT}/json/new?${encodeURIComponent(url)}`,
    { method: 'PUT' },
  );
  if (!response.ok) throw new Error(setupMessage);
  const tab = await response.json();
  return tab.webSocketDebuggerUrl;
}

class CdpClient {
  constructor(wsUrl) {
    this.ws = new WebSocket(wsUrl);
    this.id = 0;
    this.pending = new Map();
    this.events = new Map();
    this.ws.onmessage = (event) => this.onMessage(event);
  }

  async ready() {
    await new Promise((resolve, reject) => {
      this.ws.onopen = resolve;
      this.ws.onerror = reject;
    });
  }

  onMessage(event) {
    const message = JSON.parse(event.data);
    if (message.id && this.pending.has(message.id)) {
      const { resolve, reject } = this.pending.get(message.id);
      this.pending.delete(message.id);
      if (message.error) reject(new Error(message.error.message));
      else resolve(message.result);
      return;
    }
    if (message.method && this.events.has(message.method)) {
      for (const resolve of this.events.get(message.method)) resolve(message.params);
      this.events.delete(message.method);
    }
  }

  send(method, params = {}) {
    const id = ++this.id;
    this.ws.send(JSON.stringify({ id, method, params }));
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      setTimeout(() => {
        if (!this.pending.has(id)) return;
        this.pending.delete(id);
        reject(new Error(`Timeout en ${method}`));
      }, 20000);
    });
  }

  waitFor(method, timeoutMs = 20000) {
    return new Promise((resolve, reject) => {
      const listeners = this.events.get(method) ?? [];
      listeners.push(resolve);
      this.events.set(method, listeners);
      setTimeout(() => reject(new Error(`Timeout esperando ${method}`)), timeoutMs);
    });
  }

  close() {
    this.ws.close();
  }
}

async function scrapeStore(storeKey, product) {
  const store = stores[storeKey];
  const url = store.searchUrl(product);
  const client = new CdpClient(await createTab(url));
  await client.ready();
  try {
    await client.send('Page.enable');
    await client.send('Runtime.enable');
    const loaded = client.waitFor('Page.loadEventFired', 25000).catch(() => null);
    await client.send('Page.navigate', { url });
    await loaded;
    await delay(4500);

    const result = await client.send('Runtime.evaluate', {
      returnByValue: true,
      awaitPromise: true,
      expression: extractionExpression(storeKey, store.label),
    });

    const payload = result?.result?.value;
    if (payload?.needsLogin) {
      return { store: store.label, needsLogin: true, results: [] };
    }
    return { store: store.label, needsLogin: false, results: payload?.results ?? [] };
  } finally {
    client.close();
  }
}

function extractionExpression(storeKey, storeLabel) {
  return `(() => {
    const normalize = (value) => (value || '').replace(/\\s+/g, ' ').trim();
    const bodyText = normalize(document.body?.innerText || '').toLowerCase();
    const loginSignals = [
      'sign in', 'sign-in', 'iniciar sesion', 'iniciar sesión',
      'log in', 'login', 'account', 'cuenta'
    ];
    const hasResultsText = /\\$|cop|reviews?|sold|vendidos?|rating|estrellas?/i.test(bodyText);
    const needsLogin = loginSignals.some((signal) => bodyText.includes(signal)) && !hasResultsText;

    const parsePrice = (text) => {
      const cop = text.match(/(?:COP|\\$)\\s*([0-9][0-9.,]{3,})/i);
      if (cop) {
        const raw = cop[1].replace(/\\./g, '').replace(/,/g, '');
        const value = Number.parseInt(raw, 10);
        if (Number.isFinite(value)) return value;
      }
      const dollars = text.match(/US\\s*\\$\\s*([0-9]+(?:[.,][0-9]{1,2})?)/i) ||
        text.match(/\\$\\s*([0-9]+(?:[.,][0-9]{1,2})?)/i);
      if (dollars) {
        const usd = Number.parseFloat(dollars[1].replace(',', '.'));
        if (Number.isFinite(usd)) return Math.round(usd * 3900);
      }
      return 0;
    };
    const parseRating = (text) => {
      const rating = text.match(/([3-5](?:[.,]\\d)?)\\s*(?:stars?|estrellas?|rating)/i) ||
        text.match(/(?:stars?|estrellas?|rating)\\s*([3-5](?:[.,]\\d)?)/i);
      return rating ? Number.parseFloat(rating[1].replace(',', '.')) : 0;
    };
    const parseSales = (text) => {
      const sales = text.match(/([0-9][0-9.,]*)(k)?\\s*(?:sold|vendidos?|ventas|reviews?|reseñas?)/i);
      if (!sales) return 0;
      const base = Number.parseFloat(sales[1].replace(/\\./g, '').replace(',', '.'));
      return Math.round(base * (sales[2] ? 1000 : 1));
    };
    const parseDelivery = (text) => {
      const days = text.match(/([0-9]{1,2})\\s*(?:days?|dias|días)/i);
      return days ? Number.parseInt(days[1], 10) : 0;
    };
    const hasFreeShipping = (text) => /free shipping|env[ií]o gratis|env[ií]o incluido|gratis/i.test(text);

    const isProductLink = (href) => {
      if ('${storeKey}' === 'amazon') return /\\/dp\\/|\\/gp\\/product\\//i.test(href);
      if ('${storeKey}' === 'aliexpress') return /\\/item\\/|item\\//i.test(href);
      if ('${storeKey}' === 'temu') return /\\/g-|goods|product/i.test(href);
      if ('${storeKey}' === 'shein') return /-p-\\d+|\\/p-\\d+|product/i.test(href);
      return true;
    };

    const anchors = Array.from(document.querySelectorAll('a[href]'));
    const seen = new Set();
    const results = [];
    for (const anchor of anchors) {
      const href = new URL(anchor.getAttribute('href'), location.href).href;
      if (seen.has(href) || href.includes('javascript:')) continue;
      if (!isProductLink(href)) continue;
      seen.add(href);
      const card = anchor.closest('article, li, [data-component-type], [class*=product], [class*=item], [class*=card], div') || anchor;
      const imageText = Array.from(card.querySelectorAll?.('img[alt]') || [])
        .map((img) => img.getAttribute('alt'))
        .filter(Boolean)
        .join(' ');
      const text = normalize([card.innerText, anchor.innerText, imageText].filter(Boolean).join(' '));
      const price = parsePrice(text);
      if (text.length < 12 || !price) continue;
      const title = normalize(anchor.getAttribute('title') || anchor.innerText || imageText || text).slice(0, 90);
      results.push({
        store: '${storeKey}',
        title: title || '${storeLabel} resultado',
        totalPrice: price,
        rating: parseRating(text),
        sales: parseSales(text),
        shippingIncluded: hasFreeShipping(text),
        deliveryDays: parseDelivery(text),
        listingUrl: href
      });
      if (results.length >= 12) break;
    }
    return { needsLogin, results };
  })()`;
}

function filterResults(results, filters) {
  const minRating = Number(filters?.minRating ?? 0);
  const minSales = Number(filters?.minSales ?? 0);
  const shippingFilter = filters?.shippingFilter ?? 'included';
  return results.filter((result) => {
    if (!result.totalPrice || !result.listingUrl) return false;
    if (result.rating > 0 && result.rating < minRating) return false;
    if (result.sales > 0 && result.sales < minSales) return false;
    if (shippingFilter === 'included' && !result.shippingIncluded) return false;
    if (shippingFilter === 'notIncluded' && result.shippingIncluded) return false;
    return true;
  }).sort((a, b) => a.totalPrice - b.totalPrice);
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function number(value) {
  if (typeof value === 'number') return Number.isFinite(value) ? value : 0;
  let text = String(value ?? '')
    .replaceAll('%', '')
    .replaceAll('$', '')
    .replaceAll('COP', '')
    .replaceAll('USD', '')
    .replace(/\s/g, '');
  if (!text) return 0;
  const hasDot = text.includes('.');
  const hasComma = text.includes(',');
  if (hasDot && hasComma) {
    const decimalSep = text.lastIndexOf(',') > text.lastIndexOf('.') ? ',' : '.';
    const groupSep = decimalSep === ',' ? '.' : ',';
    text = text.replaceAll(groupSep, '').replace(decimalSep, '.');
  } else if (hasDot || hasComma) {
    const sep = hasDot ? '.' : ',';
    const parts = text.split(sep);
    if (parts.length > 2) {
      text = parts.join('');
    } else {
      const [left, right] = parts;
      text =
        right.length === 3 && left.length > 0 && left.length <= 3
          ? `${left}${right}`
          : `${left}.${right}`;
    }
  }
  const parsed = Number(text);
  return Number.isFinite(parsed) ? parsed : 0;
}

async function fetchCurrentTrm() {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 7000);
  try {
    const response = await fetch('https://open.er-api.com/v6/latest/USD', {
      signal: controller.signal,
    });
    if (!response.ok) throw new Error(`TRM API ${response.status}`);
    const data = await response.json();
    const rate = Number(data?.rates?.COP);
    if (!Number.isFinite(rate) || rate <= 0) throw new Error('TRM no disponible.');
    return {
      rate,
      source: 'open.er-api.com',
      fetchedAt: new Date().toISOString(),
    };
  } finally {
    clearTimeout(timeout);
  }
}

function normalizePurchase(input) {
  return {
    productName: String(input.productName ?? '').trim(),
    priceUsd: number(input.priceUsd),
    trm: number(input.trm),
    quantity: number(input.quantity),
    originShippingUsd: number(input.originShippingUsd),
    cardCommissionRate: number(input.cardCommissionRate),
    heightCm: number(input.heightCm),
    widthCm: number(input.widthCm),
    lengthCm: number(input.lengthCm),
    boxCount: number(input.boxCount),
    cbmRate: number(input.cbmRate),
    nationalFreight: number(input.nationalFreight),
    mercadoLibrePrice: number(input.mercadoLibrePrice),
    mercadoLibreCommissionRate: number(input.mercadoLibreCommissionRate),
  };
}

function purchaseFromRow(row) {
  return {
    id: row.id,
    productName: row.product_name,
    priceUsd: row.price_usd,
    trm: row.trm,
    quantity: row.quantity,
    originShippingUsd: row.origin_shipping_usd,
    cardCommissionRate: row.card_commission_rate,
    heightCm: row.height_cm,
    widthCm: row.width_cm,
    lengthCm: row.length_cm,
    boxCount: row.box_count,
    cbmRate: row.cbm_rate,
    nationalFreight: row.national_freight,
    mercadoLibrePrice: row.mercado_libre_price,
    mercadoLibreCommissionRate: row.mercado_libre_commission_rate,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function listPurchases(user) {
  const tenantId = requireTenant(user);
  requirePermission(user, 'view_reports');
  return db
    .prepare('SELECT * FROM purchases WHERE tenant_id = ? ORDER BY updated_at DESC, id DESC')
    .all(tenantId)
    .map(purchaseFromRow);
}

function createPurchase(input, user) {
  const tenantId = requireTenant(user);
  requirePermission(user, 'create_publications');
  const purchase = normalizePurchase(input);
  if (!purchase.productName) throw new Error('El nombre del producto es obligatorio.');
  const result = db
    .prepare(`
      INSERT INTO purchases (
        tenant_id,
        product_name, price_usd, trm, quantity, origin_shipping_usd,
        card_commission_rate, height_cm, width_cm, length_cm, box_count,
        cbm_rate, national_freight, mercado_libre_price,
        mercado_libre_commission_rate
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `)
    .run(
      tenantId,
      purchase.productName,
      purchase.priceUsd,
      purchase.trm,
      purchase.quantity,
      purchase.originShippingUsd,
      purchase.cardCommissionRate,
      purchase.heightCm,
      purchase.widthCm,
      purchase.lengthCm,
      purchase.boxCount,
      purchase.cbmRate,
      purchase.nationalFreight,
      purchase.mercadoLibrePrice,
      purchase.mercadoLibreCommissionRate,
    );
  return getPurchase(Number(result.lastInsertRowid), user);
}

function updatePurchase(id, input, user) {
  requirePermission(user, 'edit_publications');
  const purchase = normalizePurchase(input);
  if (!purchase.productName) throw new Error('El nombre del producto es obligatorio.');
  db.prepare(`
    UPDATE purchases SET
      product_name = ?,
      price_usd = ?,
      trm = ?,
      quantity = ?,
      origin_shipping_usd = ?,
      card_commission_rate = ?,
      height_cm = ?,
      width_cm = ?,
      length_cm = ?,
      box_count = ?,
      cbm_rate = ?,
      national_freight = ?,
      mercado_libre_price = ?,
      mercado_libre_commission_rate = ?,
      updated_at = CURRENT_TIMESTAMP
    WHERE id = ? AND tenant_id = ?
  `).run(
    purchase.productName,
    purchase.priceUsd,
    purchase.trm,
    purchase.quantity,
    purchase.originShippingUsd,
    purchase.cardCommissionRate,
    purchase.heightCm,
    purchase.widthCm,
    purchase.lengthCm,
    purchase.boxCount,
    purchase.cbmRate,
    purchase.nationalFreight,
    purchase.mercadoLibrePrice,
    purchase.mercadoLibreCommissionRate,
    id,
    requireTenant(user),
  );
  return getPurchase(id, user);
}

function getPurchase(id, user) {
  const row = db.prepare('SELECT * FROM purchases WHERE id = ? AND tenant_id = ?').get(id, requireTenant(user));
  if (!row) throw new Error('Compra no encontrada.');
  return purchaseFromRow(row);
}

function removePurchase(id, user) {
  requirePermission(user, 'delete_publications');
  db.prepare('DELETE FROM purchases WHERE id = ? AND tenant_id = ?').run(id, requireTenant(user));
}

function normalizeAliExpressViability(input) {
  // Replica las formulas del Excel de viabilidad y guarda los resultados
  // calculados para que la UI pueda listar rapido sin reimportar el archivo.
  const record = {
    number: number(input.number),
    productName: String(input.productName ?? '').trim(),
    productLink: String(input.productLink ?? '').trim(),
    orderHomeCost: number(input.orderHomeCost),
    quantity: number(input.quantity),
    mercadoLibreTotalPrice: number(input.mercadoLibreTotalPrice),
    meliCommissionRate: number(input.meliCommissionRate),
  };
  record.unitHomeCost = record.quantity === 0 ? 0 : record.orderHomeCost / record.quantity;
  record.commissionFreePrice =
    record.mercadoLibreTotalPrice -
    record.mercadoLibreTotalPrice * record.meliCommissionRate;
  record.viability = record.unitHomeCost === 0 ? 0 : record.commissionFreePrice / record.unitHomeCost;
  return record;
}

function aliExpressViabilityFromRow(row) {
  return {
    id: row.id,
    number: row.number,
    productName: row.product_name,
    productLink: row.product_link,
    orderHomeCost: row.order_home_cost,
    quantity: row.quantity,
    unitHomeCost: row.unit_home_cost,
    mercadoLibreTotalPrice: row.mercado_libre_total_price,
    meliCommissionRate: row.meli_commission_rate,
    commissionFreePrice: row.commission_free_price,
    viability: row.viability,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function listAliExpressViabilities(user) {
  const tenantId = requireTenant(user);
  requirePermission(user, 'view_reports');
  return db
    .prepare('SELECT * FROM aliexpress_viabilities WHERE tenant_id = ? ORDER BY updated_at DESC, id DESC')
    .all(tenantId)
    .map(aliExpressViabilityFromRow);
}

function createAliExpressViability(input, user) {
  const tenantId = requireTenant(user);
  requirePermission(user, 'create_publications');
  const record = normalizeAliExpressViability(input);
  if (!record.productName) throw new Error('El nombre del producto es obligatorio.');
  const result = db
    .prepare(`
      INSERT INTO aliexpress_viabilities (
        tenant_id,
        number, product_name, product_link, order_home_cost, quantity,
        unit_home_cost, mercado_libre_total_price, meli_commission_rate,
        commission_free_price, viability
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `)
    .run(
      tenantId,
      record.number,
      record.productName,
      record.productLink,
      record.orderHomeCost,
      record.quantity,
      record.unitHomeCost,
      record.mercadoLibreTotalPrice,
      record.meliCommissionRate,
      record.commissionFreePrice,
      record.viability,
    );
  return getAliExpressViability(Number(result.lastInsertRowid), user);
}

function updateAliExpressViability(id, input, user) {
  requirePermission(user, 'edit_publications');
  const record = normalizeAliExpressViability(input);
  if (!record.productName) throw new Error('El nombre del producto es obligatorio.');
  db.prepare(`
    UPDATE aliexpress_viabilities SET
      number = ?,
      product_name = ?,
      product_link = ?,
      order_home_cost = ?,
      quantity = ?,
      unit_home_cost = ?,
      mercado_libre_total_price = ?,
      meli_commission_rate = ?,
      commission_free_price = ?,
      viability = ?,
      updated_at = CURRENT_TIMESTAMP
    WHERE id = ? AND tenant_id = ?
  `).run(
    record.number,
    record.productName,
    record.productLink,
    record.orderHomeCost,
    record.quantity,
    record.unitHomeCost,
    record.mercadoLibreTotalPrice,
    record.meliCommissionRate,
    record.commissionFreePrice,
    record.viability,
    id,
    requireTenant(user),
  );
  return getAliExpressViability(id, user);
}

function getAliExpressViability(id, user) {
  const row = db
    .prepare('SELECT * FROM aliexpress_viabilities WHERE id = ? AND tenant_id = ?')
    .get(id, requireTenant(user));
  if (!row) throw new Error('Viabilidad no encontrada.');
  return aliExpressViabilityFromRow(row);
}

function removeAliExpressViability(id, user) {
  requirePermission(user, 'delete_publications');
  db.prepare('DELETE FROM aliexpress_viabilities WHERE id = ? AND tenant_id = ?').run(
    id,
    requireTenant(user),
  );
}

function normalizeInventoryItem(input) {
  return {
    productName: String(input.productName ?? '').trim(),
    unitPurchaseValue: number(input.unitPurchaseValue),
    quantity: number(input.quantity),
    publicSaleValue: number(input.publicSaleValue),
    loadedAt: String(input.loadedAt ?? '').trim(),
    warehouse: String(input.warehouse ?? '').trim(),
  };
}

function inventoryItemFromRow(row) {
  return {
    id: row.id,
    productName: row.product_name,
    unitPurchaseValue: row.unit_purchase_value,
    quantity: row.quantity,
    publicSaleValue: row.public_sale_value,
    loadedAt: row.loaded_at,
    warehouse: row.warehouse,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function listInventoryItems(user) {
  const tenantId = requireTenant(user);
  requirePermission(user, 'view_inventory');
  return db
    .prepare('SELECT * FROM inventory_items WHERE tenant_id = ? ORDER BY updated_at DESC, id DESC')
    .all(tenantId)
    .map(inventoryItemFromRow);
}

function createInventoryItem(input, user) {
  const tenantId = requireTenant(user);
  requirePermission(user, 'modify_inventory');
  const item = normalizeInventoryItem(input);
  if (!item.productName) throw new Error('El nombre del producto es obligatorio.');
  if (!item.warehouse) throw new Error('La bodega es obligatoria.');
  if (!item.loadedAt) throw new Error('La fecha de carga es obligatoria.');
  if (item.unitPurchaseValue <= 0 || item.quantity <= 0 || item.publicSaleValue <= 0) {
    throw new Error('Los valores numericos deben ser mayores que 0.');
  }
  const result = db
    .prepare(
      `
        INSERT INTO inventory_items (
          tenant_id,
          product_name, unit_purchase_value, quantity, public_sale_value,
          loaded_at, warehouse
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
      `,
    )
    .run(
      tenantId,
      item.productName,
      item.unitPurchaseValue,
      item.quantity,
      item.publicSaleValue,
      item.loadedAt,
      item.warehouse,
    );
  return getInventoryItem(Number(result.lastInsertRowid), user);
}

function getInventoryItem(id, user) {
  const row = db.prepare('SELECT * FROM inventory_items WHERE id = ? AND tenant_id = ?').get(
    id,
    requireTenant(user),
  );
  if (!row) throw new Error('Producto de inventario no encontrado.');
  return inventoryItemFromRow(row);
}

function removeInventoryItem(id, user) {
  requirePermission(user, 'modify_inventory');
  db.prepare('DELETE FROM inventory_items WHERE id = ? AND tenant_id = ?').run(id, requireTenant(user));
}

function saleFromRow(row) {
  return {
    id: row.id,
    inventoryItemId: row.inventory_item_id,
    productName: row.product_name,
    warehouse: row.warehouse,
    soldAt: row.sold_at,
    quantity: row.quantity,
    unitSaleValue: row.unit_sale_value,
    totalSaleValue: row.total_sale_value,
    remainingQuantity: row.remaining_quantity,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function listSales(user) {
  const tenantId = requireTenant(user);
  requirePermission(user, 'view_sales');
  return db
    .prepare('SELECT * FROM sales WHERE tenant_id = ? ORDER BY sold_at DESC, id DESC')
    .all(tenantId)
    .map(saleFromRow);
}

function createSale(input, user) {
  const tenantId = requireTenant(user);
  requirePermission(user, 'view_sales');
  requirePermission(user, 'modify_inventory');
  const inventoryItemId = Number(input.inventoryItemId ?? 0);
  const soldAt = String(input.soldAt ?? '').trim();
  const quantity = number(input.quantity);
  const unitSaleValue = number(input.unitSaleValue);
  if (!inventoryItemId) throw new Error('Selecciona un producto del inventario.');
  if (!soldAt) throw new Error('La fecha de venta es obligatoria.');
  if (quantity <= 0 || unitSaleValue <= 0) throw new Error('Cantidad y precio deben ser mayores que 0.');

  const item = getInventoryItem(inventoryItemId, user);
  if (quantity > item.quantity) throw new Error('No hay suficiente inventario en esa bodega.');
  const remaining = item.quantity - quantity;
  const total = quantity * unitSaleValue;

  db.exec('BEGIN');
  try {
    db.prepare(
      'UPDATE inventory_items SET quantity = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND tenant_id = ?',
    ).run(remaining, inventoryItemId, tenantId);
    const result = db
      .prepare(
        `
          INSERT INTO sales (
            tenant_id,
            inventory_item_id, product_name, warehouse, sold_at, quantity,
            unit_sale_value, total_sale_value, remaining_quantity
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        `,
      )
      .run(
        tenantId,
        item.id,
        item.productName,
        item.warehouse,
        soldAt,
        quantity,
        unitSaleValue,
        total,
        remaining,
      );
    db.exec('COMMIT');
    return {
      sale: db
        .prepare('SELECT * FROM sales WHERE id = ?')
        .get(Number(result.lastInsertRowid)),
      lowStock: remaining < 3,
    };
  } catch (error) {
    db.exec('ROLLBACK');
    throw error;
  }
}

backfillLegacyTenant();
seedInitialUsers();

const server = http.createServer(async (req, res) => {
  if (req.method === 'OPTIONS') return json(res, 200, {});
  if (req.url === '/health') return json(res, 200, { ok: true });
  if (req.url === '/auth/status' && req.method === 'GET') {
    return json(res, 200, {
      hasUsers: db.prepare('SELECT COUNT(*) AS count FROM users').get().count > 0,
    });
  }
  if (req.url === '/auth/register' && req.method === 'POST') {
    try {
      return json(res, 200, registerUser(await readJson(req)));
    } catch (error) {
      return json(res, 400, { message: error?.message ?? 'No pude registrar.' });
    }
  }
  if (req.url === '/auth/login' && req.method === 'POST') {
    try {
      return json(res, 200, loginUser(await readJson(req)));
    } catch (error) {
      return json(res, 401, { message: error?.message ?? 'No pude iniciar sesion.' });
    }
  }
  if (req.url === '/auth/reset/request' && req.method === 'POST') {
    try {
      return json(res, 200, await requestPasswordReset(await readJson(req)));
    } catch (error) {
      return json(res, 400, { message: error?.message ?? 'No pude enviar codigo.' });
    }
  }
  if (req.url === '/auth/reset/confirm' && req.method === 'POST') {
    try {
      return json(res, 200, confirmPasswordReset(await readJson(req)));
    } catch (error) {
      return json(res, 400, { message: error?.message ?? 'No pude restablecer.' });
    }
  }
  if (req.url === '/auth/me' && req.method === 'GET') {
    const user = requireAuth(req, res);
    if (!user) return;
    return json(res, 200, { user: publicUser(user) });
  }
  if (req.url === '/trm' && req.method === 'GET') {
    try {
      return json(res, 200, await fetchCurrentTrm());
    } catch (error) {
      return json(res, 502, {
        message:
          'No pude consultar la TRM automaticamente. Puedes ingresarla manualmente.',
      });
    }
  }
  const user = requireAuth(req, res);
  if (!user) return;
  if (req.url === '/permissions' && req.method === 'GET') {
    return json(res, 200, { permissions: listPermissions() });
  }
  if (req.url === '/admin/principal-users' && req.method === 'GET') {
    try {
      requireRole(user, 'super_admin');
      return json(res, 200, { users: listPrincipalUsers() });
    } catch (error) {
      return json(res, 403, { message: error?.message ?? 'No autorizado.' });
    }
  }
  if (req.url === '/admin/principal-users' && req.method === 'POST') {
    try {
      requireRole(user, 'super_admin');
      return json(res, 200, { user: createPrincipalUser(await readJson(req)) });
    } catch (error) {
      return json(res, 400, { message: error?.message ?? 'No pude crear usuario.' });
    }
  }
  const principalUserMatch = req.url.match(/^\/admin\/principal-users\/(\d+)$/);
  if (principalUserMatch && req.method === 'PUT') {
    try {
      requireRole(user, 'super_admin');
      return json(res, 200, {
        user: updatePrincipalUser(Number(principalUserMatch[1]), await readJson(req)),
      });
    } catch (error) {
      return json(res, 400, { message: error?.message ?? 'No pude actualizar usuario.' });
    }
  }
  if (req.url === '/collaborators' && req.method === 'GET') {
    try {
      return json(res, 200, { collaborators: listCollaborators(user) });
    } catch (error) {
      return json(res, 403, { message: error?.message ?? 'No autorizado.' });
    }
  }
  if (req.url === '/collaborators' && req.method === 'POST') {
    try {
      return json(res, 200, { collaborator: createCollaborator(user, await readJson(req)) });
    } catch (error) {
      return json(res, 400, { message: error?.message ?? 'No pude crear colaborador.' });
    }
  }
  const collaboratorMatch = req.url.match(/^\/collaborators\/(\d+)$/);
  if (collaboratorMatch && req.method === 'PUT') {
    try {
      return json(res, 200, {
        collaborator: updateCollaborator(user, Number(collaboratorMatch[1]), await readJson(req)),
      });
    } catch (error) {
      return json(res, 400, { message: error?.message ?? 'No pude actualizar colaborador.' });
    }
  }
  if (req.url === '/mercado-libre-stores' && req.method === 'GET') {
    try {
      requirePermission(user, 'manage_stores');
      return json(res, 200, { stores: listMercadoLibreStores(user) });
    } catch (error) {
      return json(res, 403, { message: error?.message ?? 'No autorizado.' });
    }
  }
  if (req.url === '/mercado-libre-stores' && req.method === 'POST') {
    try {
      return json(res, 200, { store: createMercadoLibreStore(user, await readJson(req)) });
    } catch (error) {
      return json(res, 400, { message: error?.message ?? 'No pude crear tienda.' });
    }
  }
  const storeMatch = req.url.match(/^\/mercado-libre-stores\/(\d+)$/);
  if (storeMatch && req.method === 'PUT') {
    try {
      return json(res, 200, {
        store: updateMercadoLibreStore(user, Number(storeMatch[1]), await readJson(req)),
      });
    } catch (error) {
      return json(res, 400, { message: error?.message ?? 'No pude actualizar tienda.' });
    }
  }
  if (req.url === '/purchases' && req.method === 'GET') {
    try {
      return json(res, 200, { purchases: listPurchases(user) });
    } catch (error) {
      return json(res, 403, { message: error?.message ?? 'No autorizado.' });
    }
  }
  if (req.url === '/purchases' && req.method === 'POST') {
    try {
      return json(res, 200, { purchase: createPurchase(await readJson(req), user) });
    } catch (error) {
      return json(res, 400, { message: error?.message ?? 'No pude guardar.' });
    }
  }
  const purchaseMatch = req.url.match(/^\/purchases\/(\d+)$/);
  if (purchaseMatch && req.method === 'PUT') {
    try {
      return json(res, 200, {
        purchase: updatePurchase(Number(purchaseMatch[1]), await readJson(req), user),
      });
    } catch (error) {
      return json(res, 400, { message: error?.message ?? 'No pude actualizar.' });
    }
  }
  if (purchaseMatch && req.method === 'DELETE') {
    try {
      removePurchase(Number(purchaseMatch[1]), user);
    } catch (error) {
      return json(res, 403, { message: error?.message ?? 'No autorizado.' });
    }
    return json(res, 200, { ok: true });
  }
  if (req.url === '/aliexpress-viabilities' && req.method === 'GET') {
    // Seccion independiente del segundo Excel: no comparte datos con purchases.
    try {
      return json(res, 200, { records: listAliExpressViabilities(user) });
    } catch (error) {
      return json(res, 403, { message: error?.message ?? 'No autorizado.' });
    }
  }
  if (req.url === '/aliexpress-viabilities' && req.method === 'POST') {
    try {
      return json(res, 200, {
        record: createAliExpressViability(await readJson(req), user),
      });
    } catch (error) {
      return json(res, 400, { message: error?.message ?? 'No pude guardar.' });
    }
  }
  const viabilityMatch = req.url.match(/^\/aliexpress-viabilities\/(\d+)$/);
  if (viabilityMatch && req.method === 'PUT') {
    try {
      return json(res, 200, {
        record: updateAliExpressViability(
          Number(viabilityMatch[1]),
          await readJson(req),
          user,
        ),
      });
    } catch (error) {
      return json(res, 400, { message: error?.message ?? 'No pude actualizar.' });
    }
  }
  if (viabilityMatch && req.method === 'DELETE') {
    try {
      removeAliExpressViability(Number(viabilityMatch[1]), user);
    } catch (error) {
      return json(res, 403, { message: error?.message ?? 'No autorizado.' });
    }
    return json(res, 200, { ok: true });
  }
  if (req.url === '/inventory' && req.method === 'GET') {
    try {
      return json(res, 200, { items: listInventoryItems(user) });
    } catch (error) {
      return json(res, 403, { message: error?.message ?? 'No autorizado.' });
    }
  }
  if (req.url === '/inventory' && req.method === 'POST') {
    try {
      return json(res, 200, { item: createInventoryItem(await readJson(req), user) });
    } catch (error) {
      return json(res, 400, { message: error?.message ?? 'No pude guardar inventario.' });
    }
  }
  const inventoryMatch = req.url.match(/^\/inventory\/(\d+)$/);
  if (inventoryMatch && req.method === 'DELETE') {
    try {
      removeInventoryItem(Number(inventoryMatch[1]), user);
    } catch (error) {
      return json(res, 403, { message: error?.message ?? 'No autorizado.' });
    }
    return json(res, 200, { ok: true });
  }
  if (req.url === '/sales' && req.method === 'GET') {
    try {
      return json(res, 200, { sales: listSales(user) });
    } catch (error) {
      return json(res, 403, { message: error?.message ?? 'No autorizado.' });
    }
  }
  if (req.url === '/sales' && req.method === 'POST') {
    try {
      const created = createSale(await readJson(req), user);
      return json(res, 200, {
        sale: saleFromRow(created.sale),
        lowStock: created.lowStock,
      });
    } catch (error) {
      return json(res, 400, { message: error?.message ?? 'No pude registrar la venta.' });
    }
  }
  if (req.url !== '/search' || req.method !== 'POST') {
    return json(res, 404, { message: 'Ruta no encontrada.' });
  }

  try {
    requireTenant(user);
    requirePermission(user, 'create_publications');
    const body = await readJson(req);
    const product = String(body.product ?? '').trim();
    const selectedStores = Array.isArray(body?.filters?.stores)
      ? body.filters.stores.filter((store) => stores[store])
      : ['aliexpress', 'temu'];
    if (!product) return json(res, 400, { message: 'Escribe un producto.' });
    if (!selectedStores.length) {
      return json(res, 400, { message: 'Selecciona al menos una tienda.' });
    }

    await ensureChrome();

    const settled = await Promise.allSettled(
      selectedStores.map((store) => scrapeStore(store, product)),
    );
    const results = [];
    const loginStores = [];
    const failedStores = [];

    for (const item of settled) {
      if (item.status === 'rejected') {
        failedStores.push(item.reason?.message ?? 'tienda desconocida');
        continue;
      }
      if (item.value.needsLogin) loginStores.push(item.value.store);
      results.push(...item.value.results);
    }

    const filtered = filterResults(results, body.filters).slice(0, 30);
    if (loginStores.length && !filtered.length) {
      return json(res, 401, {
        message: `Necesitas iniciar sesion en ${loginStores.join(', ')} dentro de la ventana PriceSec Chrome y volver a comparar.`,
        results: [],
      });
    }

    return json(res, 200, {
      message: failedStores.length
        ? `Busqueda parcial. Revise estas tiendas: ${failedStores.join(', ')}`
        : 'Busqueda real lista.',
      results: filtered,
    });
  } catch (error) {
    return json(res, 503, {
      message: error?.message || setupMessage,
      results: [],
    });
  }
});

server.listen(PORT, () => {
  console.log(`PriceSec local search service: http://localhost:${PORT}`);
  console.log(`Chrome profile: ${PROFILE_DIR}`);
});
