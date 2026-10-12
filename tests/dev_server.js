#!/usr/bin/env node
/**
 * AwgIt Local Development & Mock Server
 * Pure Node.js (Zero dependencies)
 * Serves the web interface and mocks /cgi-bin/awg-api for instant local preview.
 *
 * Usage:
 *   node tests/dev_server.js [PORT]
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const url = require('url');

const PORT = parseInt(process.env.PORT || process.argv[2] || '8080', 10);
const SRC_DIR = path.resolve(__dirname, '../src');

// In-memory mock state
const state = {
  adminPassword: '',
  server: {
    interface: 'awg0',
    public_key: 'wpBj3ygxQ0I2lLE8q1DNaukExF4OzNNQ/OY2QpseLDs=',
    listen_port: 49155,
    endpoint: 'YOUR_SERVER_IP:49155',
    awg_params: {
      jc: 4, jmin: 40, jmax: 70,
      s1: 15, s2: 32,
      h1: 1, h2: 2, h3: 3, h4: 4
    }
  },
  categories: [
    { name: 'Family', icon: '🏠' },
    { name: 'Work', icon: '💼' }
  ],
  peers: [
    {
      section: 'cfg01',
      name: 'Phone-Alex',
      public_key: 'pQ7/s1GZk9bXxM8yKl2eRt0wQz3vBn7mLk8jFh5dAs=',
      allowed_ips: '10.9.0.2/32',
      latest_handshake: Math.floor(Date.now() / 1000) - 24,
      transfer_rx: 145892014,
      transfer_tx: 45892014,
      persistent_keepalive: 25,
      group: 'Family',
      notes: 'iPhone 15 Pro',
      disabled: 0,
      created_at: Math.floor(Date.now() / 1000) - 86400 * 5
    },
    {
      section: 'cfg02',
      name: 'Laptop-ThinkPad',
      public_key: 'xR8/t2Ha1lcYyN9zLm3fSu1xRa4wCo8nLk9kGi6eBt=',
      allowed_ips: '10.9.0.3/32',
      latest_handshake: Math.floor(Date.now() / 1000) - 120,
      transfer_rx: 894561230,
      transfer_tx: 124561230,
      persistent_keepalive: 25,
      group: 'Work',
      notes: 'Fedora Workstation',
      disabled: 0,
      created_at: Math.floor(Date.now() / 1000) - 86400 * 12
    },
    {
      section: 'cfg03',
      name: 'SmartTV-LivingRoom',
      public_key: 'zS9/u3Ib2mdZzO0aMn4gTv2ySb5xDp9oMl0lHj7fCu=',
      allowed_ips: '10.9.0.4/32',
      latest_handshake: 0,
      transfer_rx: 0,
      transfer_tx: 0,
      persistent_keepalive: 25,
      group: 'Family',
      notes: 'LG WebOS',
      disabled: 1,
      created_at: Math.floor(Date.now() / 1000) - 86400 * 20
    }
  ]
};

function generateClientConf(ip, privKey) {
  const s = state.server;
  const p = s.awg_params;
  return `[Interface]
Address = ${ip}/24
PrivateKey = ${privKey}
DNS = 10.9.0.1, 77.88.8.8
Jc = ${p.jc}
Jmin = ${p.jmin}
Jmax = ${p.jmax}
S1 = ${p.s1}
S2 = ${p.s2}
H1 = ${p.h1}
H2 = ${p.h2}
H3 = ${p.h3}
H4 = ${p.h4}

[Peer]
PublicKey = ${s.public_key}
Endpoint = ${s.endpoint}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
`;
}

function handleApi(req, res, query) {
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', 'no-cache, no-store');

  const action = query.action || 'status';

  // Auth check
  if (state.adminPassword) {
    const pass = query.password || req.headers['x-awgit-password'] || '';
    if (action === 'auth_check') {
      const ok = pass === state.adminPassword;
      return res.end(JSON.stringify({ status: ok ? 'ok' : 'error', authenticated: ok, auth_required: true }));
    }
    if (pass !== state.adminPassword) {
      return res.end(JSON.stringify({ status: 'error', code: 'unauthorized', auth_required: true, message: 'Admin password required' }));
    }
  } else if (action === 'auth_check') {
    return res.end(JSON.stringify({ status: 'ok', authenticated: true, auth_required: false }));
  }

  if (action === 'status' || action === 'list') {
    // Simulate live traffic increment
    state.peers.forEach(p => {
      if (!p.disabled && p.latest_handshake > 0) {
        p.transfer_rx += Math.floor(Math.random() * 50000 + 1000);
        p.transfer_tx += Math.floor(Math.random() * 20000 + 500);
        p.latest_handshake = Math.floor(Date.now() / 1000) - Math.floor(Math.random() * 30);
      }
    });

    return res.end(JSON.stringify({
      status: 'ok',
      server: state.server,
      auth_required: !!state.adminPassword,
      categories: state.categories,
      peers: state.peers
    }));
  }

  if (action === 'set_server_settings') {
    if (query.endpoint_host !== undefined) {
      const epHost = query.endpoint_host.trim() || 'YOUR_SERVER_IP';
      state.server.endpoint = `${epHost}:${state.server.listen_port}`;
    }
    let reloaded = false;
    if (query.listen_port) {
      const port = parseInt(query.listen_port, 10);
      if (port >= 1 && port <= 65535) {
        if (state.server.listen_port !== port) reloaded = true;
        state.server.listen_port = port;
        const host = state.server.endpoint.split(':')[0] || 'YOUR_SERVER_IP';
        state.server.endpoint = `${host}:${port}`;
      }
    }
    const awgKeys = ['jc', 'jmin', 'jmax', 's1', 's2', 'h1', 'h2', 'h3', 'h4'];
    awgKeys.forEach(k => {
      if (query[k] !== undefined) {
        const val = parseInt(query[k], 10);
        if (!isNaN(val)) {
          if (state.server.awg_params[k] !== val) reloaded = true;
          state.server.awg_params[k] = val;
        }
      }
    });
    return res.end(JSON.stringify({ status: 'ok', message: 'Server settings updated', reloaded }));
  }

  if (action === 'create') {
    const name = query.name || `Client-${Date.now()}`;
    const group = query.group || '';
    const notes = query.notes || '';
    const nextOctet = state.peers.length + 2;
    const clientIp = `10.9.0.${nextOctet}`;
    const fakePrivKey = 'aBCDeF1234567890/FakePrivKeyForTesting12345=';
    const fakePubKey = `pubKeyMock${nextOctet}1234567890ABCDEFabcdef123=`;

    const newPeer = {
      section: `cfg_${Date.now()}`,
      name,
      public_key: fakePubKey,
      allowed_ips: `${clientIp}/32`,
      latest_handshake: 0,
      transfer_rx: 0,
      transfer_tx: 0,
      persistent_keepalive: 25,
      group,
      notes,
      disabled: 0,
      created_at: Math.floor(Date.now() / 1000)
    };
    state.peers.push(newPeer);

    const conf = generateClientConf(clientIp, fakePrivKey);
    return res.end(JSON.stringify({
      status: 'ok',
      message: 'Peer created successfully',
      peer: {
        ...newPeer,
        server_public_key: state.server.public_key,
        config: conf
      }
    }));
  }

  if (action === 'client_config') {
    const pub = query.public_key;
    const peer = state.peers.find(p => p.public_key === pub);
    if (!peer) return res.end(JSON.stringify({ status: 'error', message: 'Peer not found' }));
    const ip = peer.allowed_ips.split('/')[0] || '10.9.0.2';
    const conf = generateClientConf(ip, 'yXZAaB1234567890/StoredPrivKeyExample12345=');
    return res.end(JSON.stringify({ status: 'ok', name: peer.name, config: conf }));
  }

  if (action === 'toggle') {
    const pub = query.public_key;
    const disabled = query.disabled === '1' ? 1 : 0;
    const peer = state.peers.find(p => p.public_key === pub);
    if (peer) peer.disabled = disabled;
    return res.end(JSON.stringify({ status: 'ok', message: 'Peer state updated' }));
  }

  if (action === 'delete') {
    const pub = query.public_key;
    state.peers = state.peers.filter(p => p.public_key !== pub);
    return res.end(JSON.stringify({ status: 'ok', message: 'Peer removed' }));
  }

  if (action === 'save_categories') {
    try {
      state.categories = JSON.parse(query.categories || '[]');
    } catch (e) {
      state.categories = [];
    }
    return res.end(JSON.stringify({ status: 'ok', message: 'Categories saved' }));
  }

  if (action === 'set_password') {
    state.adminPassword = query.new_password || '';
    return res.end(JSON.stringify({ status: 'ok', message: 'Password updated' }));
  }

  res.end(JSON.stringify({ status: 'ok', message: `Mock handled action: ${action}` }));
}

const server = http.createServer((req, res) => {
  const parsed = url.parse(req.url, true);
  const pathname = parsed.pathname;

  // Handle CGI API
  if (pathname === '/cgi-bin/awg-api') {
    if (req.method === 'POST') {
      let body = '';
      req.on('data', chunk => { body += chunk; });
      req.on('end', () => {
        let postQuery = {};
        if (body.startsWith('{')) {
          try { postQuery = JSON.parse(body); } catch (e) {}
        } else {
          postQuery = require('querystring').parse(body);
        }
        const mergedQuery = { ...parsed.query, ...postQuery };
        handleApi(req, res, mergedQuery);
      });
      return;
    }
    return handleApi(req, res, parsed.query);
  }

  // Handle SPA routing & static files
  let reqPath = pathname;
  if (reqPath === '/' || reqPath === '/awg') {
    res.writeHead(302, { Location: '/awg/' });
    return res.end();
  }

  if (reqPath.startsWith('/awg/')) {
    reqPath = reqPath.slice(5);
  }
  if (!reqPath || reqPath === '/') reqPath = 'index.html';

  const filePath = path.join(SRC_DIR, reqPath);
  fs.stat(filePath, (err, stats) => {
    if (err || !stats.isFile()) {
      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
      return res.end('404 Not Found');
    }

    const ext = path.extname(filePath).toLowerCase();
    const mimeTypes = {
      '.html': 'text/html; charset=utf-8',
      '.js': 'application/javascript; charset=utf-8',
      '.json': 'application/json; charset=utf-8',
      '.css': 'text/css; charset=utf-8',
      '.ico': 'image/x-icon',
      '.png': 'image/png',
      '.svg': 'image/svg+xml'
    };
    res.writeHead(200, { 'Content-Type': mimeTypes[ext] || 'application/octet-stream' });
    fs.createReadStream(filePath).pipe(res);
  });
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`\n==================================================`);
  console.log(`  AwgIt Local Dev & Mock Server Started!`);
  console.log(`  Access URL: http://127.0.0.1:${PORT}/awg/`);
  console.log(`==================================================\n`);
});
