'use strict';
const https = require('https');
const crypto = require('crypto');

// Injected by Terraform at deploy time
const CONFIG = {
  userPoolId:    '${user_pool_id}',
  region:        '${user_pool_region}',
  clientId:      '${client_id}',
  cognitoDomain: '${cognito_domain}',
  callbackUrl:   '${callback_url}',
  scheduleUrl:   '${schedule_url}',
};

const JWKS_URL = 'https://cognito-idp.' + CONFIG.region + '.amazonaws.com/' + CONFIG.userPoolId + '/.well-known/jwks.json';
const TOKEN_URL = CONFIG.cognitoDomain + '/oauth2/token';
const ISSUER    = 'https://cognito-idp.' + CONFIG.region + '.amazonaws.com/' + CONFIG.userPoolId;

// Module-level cache — survives across warm Lambda invocations
let cachedJwks = null;

exports.handler = async (event) => {
  const request = event.Records[0].cf.request;
  const uri     = request.uri;

  if (uri === '/logout') {
    return redirect(
      CONFIG.cognitoDomain + '/logout?client_id=' + CONFIG.clientId + '&logout_uri=' + encodeURIComponent(CONFIG.scheduleUrl),
      [clearCookie('session'), clearCookie('pkce_verifier'), clearCookie('pkce_state')]
    );
  }

  if (uri.startsWith('/callback')) {
    return handleCallback(request);
  }

  const cookies = parseCookies(request);
  if (cookies.session && await verifyToken(cookies.session)) {
    return request; // Authenticated — pass through to S3
  }

  // Not authenticated — kick off PKCE flow
  const verifier   = crypto.randomBytes(32).toString('base64url');
  const challenge  = crypto.createHash('sha256').update(verifier).digest('base64url');
  const state      = crypto.randomBytes(16).toString('hex');
  const loginUrl   = CONFIG.cognitoDomain + '/oauth2/authorize'
    + '?client_id='              + CONFIG.clientId
    + '&response_type=code'
    + '&scope=openid+email+profile'
    + '&redirect_uri='           + encodeURIComponent(CONFIG.callbackUrl)
    + '&code_challenge='         + challenge
    + '&code_challenge_method=S256'
    + '&state='                  + state;

  return redirect(loginUrl, [
    setCookie('pkce_verifier', verifier, { maxAge: 300, path: '/' }),
    setCookie('pkce_state',    state,    { maxAge: 300, path: '/' }),
  ]);
};

async function handleCallback(request) {
  const params  = new URLSearchParams(request.querystring || '');
  const code    = params.get('code');
  const state   = params.get('state');
  const cookies = parseCookies(request);

  if (!code || !state || state !== cookies.pkce_state || !cookies.pkce_verifier) {
    return redirect(CONFIG.scheduleUrl, []);
  }

  try {
    const body = new URLSearchParams({
      grant_type:    'authorization_code',
      client_id:     CONFIG.clientId,
      code:          code,
      redirect_uri:  CONFIG.callbackUrl,
      code_verifier: cookies.pkce_verifier,
    }).toString();

    const response = await httpPost(TOKEN_URL, body, { 'Content-Type': 'application/x-www-form-urlencoded' });
    const tokens   = JSON.parse(response);
    if (!tokens.id_token) throw new Error('No id_token in Cognito response');

    return redirect(CONFIG.scheduleUrl, [
      setCookie('session', tokens.id_token, { maxAge: 3600, path: '/', httpOnly: true, secure: true, sameSite: 'Lax' }),
      clearCookie('pkce_verifier'),
      clearCookie('pkce_state'),
    ]);
  } catch (err) {
    console.error('Token exchange failed:', err.message);
    return redirect(CONFIG.scheduleUrl, [clearCookie('pkce_verifier'), clearCookie('pkce_state')]);
  }
}

async function verifyToken(token) {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return false;

    const header  = JSON.parse(Buffer.from(parts[0], 'base64url').toString());
    const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString());

    if (payload.exp < Math.floor(Date.now() / 1000)) return false;
    if (payload.iss !== ISSUER)                       return false;
    if (payload.aud !== CONFIG.clientId)              return false;

    const keys = await getJwks();
    const jwk  = keys.find(k => k.kid === header.kid);
    if (!jwk) return false;

    const publicKey     = crypto.createPublicKey({ key: jwk, format: 'jwk' });
    const signingInput  = parts[0] + '.' + parts[1];
    const signature     = Buffer.from(parts[2], 'base64url');

    return crypto.verify('SHA256', Buffer.from(signingInput), publicKey, signature);
  } catch (err) {
    console.error('Token verification error:', err.message);
    return false;
  }
}

async function getJwks() {
  if (!cachedJwks) {
    const data  = await httpGet(JWKS_URL);
    cachedJwks  = JSON.parse(data).keys;
  }
  return cachedJwks;
}

// ── Helpers ──────────────────────────────────────────────────────────────────

function parseCookies(request) {
  const cookies = {};
  (request.headers.cookie || []).forEach(h => {
    h.value.split(';').forEach(part => {
      const [k, ...v] = part.trim().split('=');
      if (k) cookies[k.trim()] = v.join('=');
    });
  });
  return cookies;
}

function setCookie(name, value, opts = {}) {
  let c = name + '=' + value;
  if (opts.maxAge  !== undefined) c += '; Max-Age=' + opts.maxAge;
  if (opts.path)                  c += '; Path=' + opts.path;
  if (opts.httpOnly)              c += '; HttpOnly';
  if (opts.secure)                c += '; Secure';
  if (opts.sameSite)              c += '; SameSite=' + opts.sameSite;
  return { key: 'Set-Cookie', value: c };
}

function clearCookie(name) {
  return setCookie(name, '', { maxAge: 0, path: '/' });
}

function redirect(url, cookies) {
  return {
    status:            '302',
    statusDescription: 'Found',
    headers: {
      location:        [{ key: 'Location', value: url }],
      'set-cookie':    cookies,
      'cache-control': [{ key: 'Cache-Control', value: 'no-store' }],
    },
  };
}

function httpGet(url) {
  return new Promise((resolve, reject) => {
    https.get(url, res => {
      let data = '';
      res.on('data', chunk => { data += chunk; });
      res.on('end',  () => resolve(data));
    }).on('error', reject);
  });
}

function httpPost(url, body, headers) {
  return new Promise((resolve, reject) => {
    const u   = new URL(url);
    const req = https.request({
      hostname: u.hostname,
      path:     u.pathname,
      method:   'POST',
      headers:  { ...headers, 'Content-Length': Buffer.byteLength(body) },
    }, res => {
      let data = '';
      res.on('data', chunk => { data += chunk; });
      res.on('end',  () => resolve(data));
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}
