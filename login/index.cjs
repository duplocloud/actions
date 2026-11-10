'use strict';

const { appendFileSync } = require('node:fs');

const singleLine = value => typeof value === 'string' && value.length > 0 && !/[\s\x00-\x1f\x7f]/.test(value);
const mask = (value, log) => log(`::add-mask::${value.replaceAll('%', '%25').replaceAll('\r', '%0D').replaceAll('\n', '%0A')}`);

async function requestJson(fetch, url, options, label) {
  try {
    const response = await fetch(url, {
      ...options, redirect: 'error', signal: AbortSignal.timeout(30000),
    });
    if (!response.ok) throw new Error();
    return await response.json();
  } catch {
    // Neither response bodies nor transport errors are safe to log: they can
    // contain credentials or reflect the submitted JWT.
    throw new Error(`${label} failed. Check connectivity, permissions, and the configured OIDC trust.`);
  }
}

async function run({ env = process.env, fetch = globalThis.fetch, log = console.log } = {}) {
  const host = (env.DUPLO_HOST || '').trim().replace(/\/+$/, '');
  let parsedHost;
  try { parsedHost = new URL(host); } catch { throw new Error('DUPLO_HOST must be an absolute HTTPS URL.'); }
  if (parsedHost.protocol !== 'https:' || parsedHost.username || parsedHost.password || parsedHost.search || parsedHost.hash) {
    throw new Error('DUPLO_HOST must be an HTTPS URL without credentials, query parameters, or a fragment.');
  }
  const trust = (env.INPUT_TRUST_NAME || '').trim();
  if (!/^[A-Za-z0-9][A-Za-z0-9-]{1,62}$/.test(trust)) {
    throw new Error('trust_name must be the configured trust name (2–63 letters, digits, or hyphens, starting with a letter or digit).');
  }
  const audience = env.INPUT_AUDIENCE || host;
  if (!singleLine(audience)) throw new Error('audience must be a nonempty value without whitespace or control characters.');
  if (!env.ACTIONS_ID_TOKEN_REQUEST_URL || !env.ACTIONS_ID_TOKEN_REQUEST_TOKEN) {
    throw new Error('GitHub OIDC is unavailable. Add permissions: id-token: write to this job.');
  }
  if (!env.GITHUB_ENV || !env.GITHUB_OUTPUT) throw new Error('GitHub Actions environment files are unavailable.');
  let requestUrl;
  try { requestUrl = new URL(env.ACTIONS_ID_TOKEN_REQUEST_URL); } catch { throw new Error('Invalid GitHub OIDC request URL.'); }
  if (requestUrl.protocol !== 'https:' || requestUrl.username || requestUrl.password || requestUrl.hash) {
    throw new Error('GitHub OIDC request URL must use HTTPS without credentials or a fragment.');
  }
  requestUrl.searchParams.set('audience', audience);
  const jwt = await requestJson(fetch, requestUrl, {
    headers: { Authorization: `Bearer ${env.ACTIONS_ID_TOKEN_REQUEST_TOKEN}` },
  }, 'GitHub OIDC token request');
  if (!singleLine(jwt?.value)) throw new Error('GitHub returned an invalid OIDC token.');
  mask(jwt.value, log);

  const result = await requestJson(fetch, `${host}/v1/aiservicedesk/oidc/${trust}/token`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      grant_type: 'urn:ietf:params:oauth:grant-type:token-exchange',
      subject_token_type: 'urn:ietf:params:oauth:token-type:jwt',
      subject_token: jwt.value,
    }),
  }, 'HelpDesk OIDC token exchange');
  if (!singleLine(result?.access_token) || !result.access_token.startsWith('dahp_') ||
      result.token_type !== 'Bearer' || !Number.isSafeInteger(result.expires_in) || result.expires_in <= 0) {
    throw new Error('HelpDesk returned an invalid token exchange response.');
  }
  mask(result.access_token, log);
  appendFileSync(env.GITHUB_ENV, `DUPLO_TOKEN=${result.access_token}\n`, 'utf8');
  appendFileSync(env.GITHUB_OUTPUT, `expires_in=${result.expires_in}\n`, 'utf8');
  log(`Authenticated to HelpDesk; token expires in ${result.expires_in} seconds.`);
}

module.exports = { run };
if (require.main === module) {
  run().catch(error => {
    console.error(`::error::${error.message.replaceAll('%', '%25').replaceAll('\r', '%0D').replaceAll('\n', '%0A')}`);
    process.exitCode = 1;
  });
}
