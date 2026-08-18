// ============================================================================
// DELIBERATELY VULNERABLE ENDPOINTS - TRAINING TARGET ONLY
// ============================================================================
//
// This module is loaded ONLY when INSECURE_MODE=true. It is off by default and
// the startup guard refuses to load it when NODE_ENV=production.
//
// Purpose: give interns real vulnerabilities to find with real scanners, then
// fix. Each function below pairs the vulnerable implementation with the correct
// one so the diff is the lesson. Same idea as OWASP Juice Shop, scoped to Daig.
//
// Every vulnerability is tagged with its CWE so that scanner output can be
// matched back to the source. Answers live in the private solutions repo.
'use strict';

const crypto = require('node:crypto');

function mountInsecureRoutes(app, deps) {
  const { q, log } = deps;

  if (process.env.NODE_ENV === 'production') {
    log.error({}, 'INSECURE_MODE requested in production - refusing');
    process.exit(78);
  }

  log.warn({}, 'INSECURE_MODE active - vulnerable endpoints mounted. Never in production.');

  // --------------------------------------------------------------------------
  // VULN 1 - SQL injection.  CWE-89
  //
  // The search term is concatenated into the SQL string. Semgrep and CodeQL
  // both catch this pattern; so does a careful reader.
  //
  // THE FIX is the commented block underneath: pass the value as a parameter
  // so the driver sends it separately from the statement. Note that the fix is
  // not "escape the input" or "reject apostrophes" - it is "never build SQL by
  // concatenation in the first place".
  // --------------------------------------------------------------------------
  app.get('/insecure/search', async (req, res) => {
    const term = req.query.q || '';
    try {
      const sql = `SELECT id, name, area FROM restaurants WHERE name LIKE '%${term}%'`;
      log.warn({ sql }, 'VULN-1 executing concatenated SQL');
      const { rows } = await q('vuln_search', sql);
      res.json({ results: rows, executed_sql: sql });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }

    // FIXED VERSION:
    // const { rows } = await q('search',
    //   'SELECT id, name, area FROM restaurants WHERE name ILIKE $1',
    //   [`%${term}%`]);
    // res.json({ results: rows });
  });

  // --------------------------------------------------------------------------
  // VULN 2 - Broken object-level authorisation (IDOR).  CWE-639
  //
  // Any caller can read any order by guessing or enumerating its id. There is
  // no check that the requester owns it.
  //
  // This is the vulnerability class scanners are WORST at finding, because the
  // code is not wrong in any local sense - the query is parameterised, there is
  // no injection, nothing is unsafe. What is missing is a business rule, and a
  // tool cannot know your business rules.
  //
  // Point that out explicitly: it is why code review still exists.
  // --------------------------------------------------------------------------
  app.get('/insecure/orders/:id', async (req, res) => {
    const { rows } = await q('vuln_get_order',
      'SELECT * FROM orders WHERE id = $1', [req.params.id]);
    if (!rows.length) return res.status(404).json({ error: 'not found' });
    res.json(rows[0]);

    // FIXED VERSION: scope the query to the authenticated caller.
    // const { rows } = await q('get_order',
    //   'SELECT * FROM orders WHERE id = $1 AND customer_id = $2',
    //   [req.params.id, req.user.id]);
  });

  // --------------------------------------------------------------------------
  // VULN 3 - Verbose error disclosure.  CWE-209
  //
  // The stack trace, the database host and the driver version all go back to
  // the caller. Free reconnaissance.
  // --------------------------------------------------------------------------
  app.get('/insecure/boom', async (_req, res) => {
    try {
      await q('vuln_boom', 'SELECT * FROM table_that_does_not_exist');
    } catch (err) {
      res.status(500).json({
        error: err.message,
        stack: err.stack,
        database: process.env.DATABASE_URL,   // catastrophic
        node: process.version
      });
    }

    // FIXED VERSION: log the detail, return an opaque reference.
    // const ref = crypto.randomUUID();
    // log.error({ err: err.message, stack: err.stack, ref }, 'query failed');
    // res.status(500).json({ error: 'internal error', reference: ref });
  });

  // --------------------------------------------------------------------------
  // VULN 4 - Weak hashing.  CWE-327 / CWE-916
  //
  // MD5, no salt, no work factor. Fast to compute is exactly the wrong
  // property for a password hash.
  // --------------------------------------------------------------------------
  app.post('/insecure/register', (req, res) => {
    const { username, password } = req.body || {};
    if (!username || !password) return res.status(400).json({ error: 'both required' });
    const hash = crypto.createHash('md5').update(password).digest('hex');
    res.json({ username, password_hash: hash, algorithm: 'md5' });

    // FIXED VERSION: argon2id, or bcrypt/scrypt with a sensible cost.
    // The point of a password hash is to be SLOW.
    // const hash = await argon2.hash(password, { type: argon2.argon2id });
  });

  // --------------------------------------------------------------------------
  // VULN 5 - No rate limiting.  CWE-770
  //
  // Unbounded order creation. Also the reason the iftar spike hurts: there is
  // no admission control anywhere in the request path.
  //
  // Security and reliability are the same problem here, which is worth saying
  // out loud - a missing rate limit is both a DoS vector and an availability bug.
  // --------------------------------------------------------------------------
  app.post('/insecure/bulk-order', async (req, res) => {
    const count = Number(req.body?.count || 1);   // unbounded
    res.json({
      requested: count,
      note: 'No limit, no auth, no cost check. This is VULN-5.'
    });

    // FIXED VERSION: express-rate-limit per IP and per account, a hard cap on
    // count, plus the load shedding that already exists in the main handler.
  });

  // --------------------------------------------------------------------------
  // VULN 6 - Server-side request forgery.  CWE-918
  //
  // Fetches a caller-supplied URL with no allowlist. On a cloud instance this
  // reaches the metadata endpoint and, from there, credentials.
  //
  // This is the one that turns "a bug in a webhook feature" into "the attacker
  // has our IAM role". Connect it to Tuesday's IMDS discussion.
  // --------------------------------------------------------------------------
  app.post('/insecure/fetch-menu', async (req, res) => {
    const { url } = req.body || {};
    if (!url) return res.status(400).json({ error: 'url required' });
    try {
      const r = await fetch(url);           // no allowlist, no scheme check
      res.json({ status: r.status, body: (await r.text()).slice(0, 500) });
    } catch (err) {
      res.status(502).json({ error: err.message });
    }

    // FIXED VERSION: allowlist of hostnames, https only, resolve the DNS name
    // and reject private/link-local ranges, and set a short timeout.
    // On AWS, require IMDSv2 so a plain GET cannot reach credentials at all.
  });

  return app;
}

module.exports = { mountInsecureRoutes };
