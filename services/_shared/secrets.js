// Credential resolution for Daig.
//
// OpenBao is the Linux Foundation fork of HashiCorp Vault - same API, same CLI
// verbs, Mozilla Public Licence instead of BUSL. Everything here works
// unchanged against Vault if that is what your organisation runs.
//
// RESOLUTION ORDER, and the order is deliberate:
//   1. OpenBao via AppRole  - production, and the default when configured
//   2. Process environment  - local development, with a loud warning
//   3. Exit 78              - misconfigured, and we refuse to guess
//
// Why AppRole and not a token: a token in an environment variable is the exact
// problem we are trying to solve. AppRole splits the credential in two - a
// role_id that is not secret and can live in config, and a secret_id that is
// short-lived and delivered separately. Compromising one gets you nothing.
'use strict';

const fs = require('fs');

const EX_CONFIG = 78;
const DUMMY = 'CHANGE_ME_DEV_ONLY';

function log(level, obj) {
  process.stdout.write(JSON.stringify({
    level, service: 'secrets', time: new Date().toISOString(), ...obj
  }) + '\n');
}

function die(msg, extra = {}) {
  log('fatal', { msg, exit_code: EX_CONFIG, ...extra });
  process.exit(EX_CONFIG);
}

// --------------------------------------------------------------------------
// Docker / Swarm secret convention. A mounted secret arrives as a FILE (e.g.
// /run/secrets/db_url on a tmpfs), and the container is told where via a
// companion FOO_FILE variable. Any FOO_FILE we find is read into FOO before
// anything else looks at the environment, so `DATABASE_URL_FILE=/run/secrets/db_url`
// behaves exactly like `DATABASE_URL=...`. The plain variable wins if both are set.
//
// This is what lets `docker stack deploy` (swarm/daig-stack.yml) work: mounted
// secret files are a real secret store, unlike loose environment variables.
// Returns the set of keys that came from files, so the production guard below
// can allow file-backed secrets while still refusing plain-env credentials.
// --------------------------------------------------------------------------
function loadFileBackedEnv() {
  const loaded = new Set();
  for (const [key, path] of Object.entries(process.env)) {
    if (!key.endsWith('_FILE') || !path) continue;
    const target = key.slice(0, -'_FILE'.length);
    if (process.env[target]) continue;               // explicit plain value wins
    try {
      process.env[target] = fs.readFileSync(path, 'utf8').trim();
      loaded.add(target);
      log('info', { msg: 'loaded secret from mounted file', key: target, path });
    } catch (err) {
      die(`${key} is set but its file could not be read`, { path, error: err.message });
    }
  }
  return loaded;
}

// --------------------------------------------------------------------------
// AppRole login. Exchanges role_id + secret_id for a short-lived token.
// --------------------------------------------------------------------------
async function appRoleLogin(addr, roleId, secretId) {
  const res = await fetch(`${addr}/v1/auth/approle/login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ role_id: roleId, secret_id: secretId }),
    signal: AbortSignal.timeout(5000)
  });

  if (!res.ok) {
    const body = await res.text().catch(() => '');
    throw new Error(`AppRole login failed: HTTP ${res.status} ${body.slice(0, 200)}`);
  }

  const json = await res.json();
  const auth = json.auth;
  if (!auth || !auth.client_token) throw new Error('AppRole login returned no client_token');

  log('info', {
    msg: 'authenticated to OpenBao via AppRole',
    lease_duration_s: auth.lease_duration,
    renewable: auth.renewable
  });
  return auth.client_token;
}

// --------------------------------------------------------------------------
// Read a KV v2 secret. Note the /data/ segment - KV v2 paths are not the same
// as the path you write with the CLI, which catches everyone exactly once.
//   CLI:  bao kv get daig/database
//   API:  GET /v1/daig/data/database
// --------------------------------------------------------------------------
async function readKv(addr, token, mount, path) {
  const res = await fetch(`${addr}/v1/${mount}/data/${path}`, {
    headers: { 'X-Vault-Token': token },
    signal: AbortSignal.timeout(5000)
  });

  if (res.status === 403) throw new Error(`403 reading ${mount}/${path} - the policy does not allow it`);
  if (res.status === 404) throw new Error(`404 - no secret at ${mount}/${path}`);
  if (!res.ok) throw new Error(`HTTP ${res.status} reading ${mount}/${path}`);

  const json = await res.json();
  return json.data.data;
}

// --------------------------------------------------------------------------
// Optional: ask OpenBao to mint a database credential that expires.
//
// This is the part worth understanding. Instead of one long-lived password
// shared by every instance, OpenBao creates a PostgreSQL user per request with
// a TTL. A leaked credential expires by itself; revocation is one lease rather
// than a password rotation across every service.
// --------------------------------------------------------------------------
async function readDynamicDbCredential(addr, token, mount, role) {
  const res = await fetch(`${addr}/v1/${mount}/creds/${role}`, {
    headers: { 'X-Vault-Token': token },
    signal: AbortSignal.timeout(8000)
  });
  if (!res.ok) throw new Error(`HTTP ${res.status} minting a dynamic credential for role ${role}`);

  const json = await res.json();
  log('info', {
    msg: 'minted a dynamic database credential',
    username: json.data.username,
    lease_id: json.lease_id,
    ttl_s: json.lease_duration
  });
  return {
    username: json.data.username,
    password: json.data.password,
    lease_id: json.lease_id,
    ttl_s: json.lease_duration
  };
}

// --------------------------------------------------------------------------
// The public entry point. Every service calls this before opening a port.
// --------------------------------------------------------------------------
async function bootstrap(serviceName, spec = {}) {
  // Resolve *_FILE (Docker/Swarm) secrets first, so both the OpenBao path (a
  // file-delivered BAO_SECRET_ID) and the file path below see plain values.
  const fileBacked = loadFileBackedEnv();

  const addr = process.env.BAO_ADDR || process.env.VAULT_ADDR;
  const roleId = process.env.BAO_ROLE_ID;
  const secretId = process.env.BAO_SECRET_ID;
  const mount = process.env.BAO_KV_MOUNT || 'daig';
  const required = spec.required || ['DATABASE_URL'];

  // ---------------- path 1: OpenBao ----------------
  if (addr && roleId && secretId) {
    try {
      const token = await appRoleLogin(addr, roleId, secretId);
      const db = await readKv(addr, token, mount, 'database');
      const app = await readKv(addr, token, mount, 'app').catch(() => ({}));

      let databaseUrl = db.url;

      // Dynamic credentials, when the database secrets engine is mounted.
      if (process.env.BAO_DYNAMIC_DB === 'true') {
        const dyn = await readDynamicDbCredential(
          addr, token, process.env.BAO_DB_MOUNT || 'daig-db', serviceName
        );
        databaseUrl = `postgresql://${dyn.username}:${encodeURIComponent(dyn.password)}` +
                      `@${db.host}:${db.port || 5432}/${db.dbname || 'daig'}`;
        log('warn', {
          msg: 'dynamic credential in use - it WILL expire',
          ttl_s: dyn.ttl_s,
          note: 'a real service renews the lease or reconnects before expiry'
        });
      }

      const config = {
        source: 'openbao',
        DATABASE_URL: databaseUrl,
        JWT_SECRET: app.jwt_secret,
        PAYMENT_API_KEY: app.payment_api_key
      };

      const missing = required.filter((k) => !config[k]);
      if (missing.length) die('OpenBao reachable but required keys are absent', { missing });

      log('info', { msg: 'configuration loaded from OpenBao', keys: Object.keys(config).filter(k => k !== 'source') });
      return config;
    } catch (err) {
      // Deliberate: do NOT silently fall back to environment variables. A
      // service that quietly degrades from "secrets from the vault" to
      // "secrets from the environment" is how a misconfiguration becomes a
      // credential leak nobody notices for six months.
      die('OpenBao is configured but unreachable or unauthorised', {
        error: err.message,
        addr,
        remedy: 'Fix OpenBao, or unset BAO_ADDR to use environment variables deliberately.'
      });
    }
  }

  // ---------------- path 2: mounted secret files / environment ----------------
  // Mounted secret files (Docker/Swarm) are a legitimate production store.
  // Loose environment variables are not - that silent degradation is the leak
  // we refuse. So production is allowed only when every required key was
  // file-backed; otherwise we die exactly as before.
  const requiredFromFiles = required.every((k) => fileBacked.has(k));

  if (process.env.NODE_ENV === 'production' && !requiredFromFiles) {
    die('No secret store configured while NODE_ENV=production', {
      remedy: 'Configure OpenBao (BAO_ADDR/BAO_ROLE_ID/BAO_SECRET_ID), or deliver secrets as *_FILE Docker/Swarm secrets. See vault/README.md.'
    });
  }

  if (process.env.NODE_ENV !== 'production') {
    log('warn', {
      msg: 'no secret store configured - reading credentials from the environment',
      note: 'acceptable for local development only. See vault/README.md.'
    });
  }

  const config = {
    source: requiredFromFiles ? 'docker-secret' : 'environment',
    DATABASE_URL: process.env.DATABASE_URL,
    JWT_SECRET: process.env.JWT_SECRET,
    PAYMENT_API_KEY: process.env.PAYMENT_API_KEY
  };

  // ---------------- path 3: refuse ----------------
  const missing = required.filter((k) => !config[k] || String(config[k]).trim() === '');
  if (missing.length) {
    die(`Missing required configuration: ${missing.join(', ')}`, {
      missing,
      remedy: 'Set the variables, or configure OpenBao. See .env.example and vault/README.md.'
    });
  }

  const dummies = Object.entries(config)
    .filter(([, v]) => typeof v === 'string' && v.includes(DUMMY))
    .map(([k]) => k);
  if (dummies.length && process.env.NODE_ENV === 'production') {
    die('Registered dummy values present while NODE_ENV=production', { keys: dummies });
  }

  return config;
}

module.exports = { bootstrap, EX_CONFIG };
