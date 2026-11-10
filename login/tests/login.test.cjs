const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

// Removing the audience, changing the exchange body, or failing to replace the
// exported credential must break these tests. Only HTTP transport is simulated.
async function scenario(t, overrides = {}, replies) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'duplo-login-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const env = {
    DUPLO_HOST: 'https://helpdesk.example.com/',
    INPUT_TRUST_NAME: 'github-deploy',
    ACTIONS_ID_TOKEN_REQUEST_URL: 'https://github.example/token?existing=1',
    ACTIONS_ID_TOKEN_REQUEST_TOKEN: 'request-secret',
    GITHUB_ENV: path.join(dir, 'env'), GITHUB_OUTPUT: path.join(dir, 'output'),
    ...overrides,
  };
  const requests = [], logs = [];
  const fetch = async (url, options) => {
    requests.push({ url: String(url), ...options });
    const reply = replies?.shift() ?? (requests.length % 2 === 1
      ? { value: 'signed.jwt.secret' }
      : { access_token: `dahp_secret_${requests.length}`, token_type: 'Bearer',
          issued_token_type: 'urn:ietf:params:oauth:token-type:access_token', expires_in: 900 });
    if (reply instanceof Error) throw reply;
    return new Response(JSON.stringify(reply.body ?? reply), { status: reply.status ?? 200 });
  };
  const run = require('../index.cjs').run;
  return { env, requests, logs, run: () => run({ env, fetch, log: line => logs.push(line) }),
    read: key => fs.existsSync(env[key]) ? fs.readFileSync(env[key], 'utf8') : '' };
}

test('requests the default audience, exchanges the JWT, masks and exports the raw token', async t => {
  const s = await scenario(t);
  await s.run();
  assert.equal(s.requests[0].url, 'https://github.example/token?existing=1&audience=https%3A%2F%2Fhelpdesk.example.com');
  assert.equal(s.requests[0].headers.Authorization, 'Bearer request-secret');
  assert.equal(s.requests[1].url, 'https://helpdesk.example.com/v1/aiservicedesk/oidc/github-deploy/token');
  assert.deepEqual(JSON.parse(s.requests[1].body), {
    grant_type: 'urn:ietf:params:oauth:grant-type:token-exchange',
    subject_token_type: 'urn:ietf:params:oauth:token-type:jwt', subject_token: 'signed.jwt.secret',
  });
  assert.equal(s.requests[1].headers.Authorization, undefined);
  assert.equal(s.requests[1].redirect, 'error');
  assert.equal(s.read('GITHUB_ENV'), 'DUPLO_TOKEN=dahp_secret_2\n');
  assert.equal(s.read('GITHUB_OUTPUT'), 'expires_in=900\n');
  assert.ok(s.logs.includes('::add-mask::signed.jwt.secret'));
  assert.ok(s.logs.includes('::add-mask::dahp_secret_2'));
  assert.ok(s.logs.filter(x => !x.startsWith('::add-mask::')).every(x => !/secret/.test(x)));
});

test('honors an exact custom audience and requests fresh credentials on every invocation', async t => {
  const s = await scenario(t, { INPUT_AUDIENCE: 'api://custom/audience/' });
  await s.run(); await s.run();
  assert.equal(new URL(s.requests[0].url).searchParams.get('audience'), 'api://custom/audience/');
  assert.equal(s.requests.length, 4);
  assert.equal(s.read('GITHUB_ENV'), 'DUPLO_TOKEN=dahp_secret_2\nDUPLO_TOKEN=dahp_secret_4\n');
});

for (const [name, overrides] of [
  ['host', { DUPLO_HOST: '' }], ['trust name', { INPUT_TRUST_NAME: '' }],
  ['permission', { ACTIONS_ID_TOKEN_REQUEST_TOKEN: '' }],
  ['HTTPS', { DUPLO_HOST: 'http://helpdesk.example.com' }],
  ['host query', { DUPLO_HOST: 'https://helpdesk.example.com?secret=x' }],
  ['trust path injection', { INPUT_TRUST_NAME: '../other' }],
]) test(`rejects invalid ${name} before making requests`, async t => {
  const s = await scenario(t, overrides);
  await assert.rejects(s.run());
  assert.equal(s.requests.length, 0);
  assert.equal(s.read('GITHUB_ENV'), '');
});

for (const [name, replies] of [
  ['GitHub rejection', [{ status: 403, body: { error: 'request-secret' } }]],
  ['missing JWT', [{}]],
  ['exchange rejection', [{ value: 'signed.jwt.secret' }, { status: 400, body: { error: 'signed.jwt.secret' } }]],
  ['missing token', [{ value: 'signed.jwt.secret' }, { expires_in: 900, token_type: 'Bearer' }]],
  ['invalid lifetime', [{ value: 'signed.jwt.secret' }, { access_token: 'dahp_secret', expires_in: -1, token_type: 'Bearer' }]],
  ['environment injection', [{ value: 'signed.jwt.secret' }, { access_token: 'dahp_secret\nINJECTED=yes', expires_in: 900, token_type: 'Bearer' }]],
  ['transport failure', [new Error('request-secret')]],
]) test(`fails safely on ${name} without exporting credentials`, async t => {
  const s = await scenario(t, {}, replies);
  await assert.rejects(s.run(), error => !error.message.includes('secret'));
  assert.equal(s.read('GITHUB_ENV'), '');
  assert.equal(s.read('GITHUB_OUTPUT'), '');
});
