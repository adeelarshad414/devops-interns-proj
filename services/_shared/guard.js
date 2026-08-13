// Startup guard. Runs before any port is opened.
// Registered dummies are listed in DUMMY-VALUES.md.
'use strict';

const DUMMY = 'CHANGE_ME_DEV_ONLY';
const EX_CONFIG = 78; // sysexits.h

/**
 * Require an env var. Exits 78 with a message a human can act on.
 * This is the function the kickoff exercise depends on: run the container
 * without DATABASE_URL and this is the log the interns read.
 */
function required(key, hint) {
  const v = process.env[key];
  if (!v || v.trim() === '') {
    console.error(JSON.stringify({
      level: 'fatal',
      msg: `Missing required configuration: ${key}`,
      hint: hint || `Set ${key} and restart.`,
      exit_code: EX_CONFIG,
      time: new Date().toISOString()
    }));
    process.exit(EX_CONFIG);
  }
  return v;
}

/** Refuse to run in production with a registered dummy value. */
function refuseDummiesInProd(keys) {
  if (process.env.NODE_ENV !== 'production') return;
  const offenders = keys.filter(k => (process.env[k] || '').includes(DUMMY));
  if (offenders.length) {
    console.error(JSON.stringify({
      level: 'fatal',
      msg: 'Registered dummy values present while NODE_ENV=production',
      keys: offenders,
      remedy: 'See DUMMY-VALUES.md. Supply real secrets from the secret store.',
      exit_code: EX_CONFIG,
      time: new Date().toISOString()
    }));
    process.exit(EX_CONFIG);
  }
}

module.exports = { required, refuseDummiesInProd, DUMMY, EX_CONFIG };
