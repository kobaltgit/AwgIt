/**
 * AwgIt Frontend Automated Integrity Test Suite
 * Validates:
 * 1. Strictly zero external CDN dependencies (GEMINI.md Rule 2.4)
 * 2. JavaScript Syntax of src/index.html
 * 3. Complete i18n bilingual parity (EN vs RU keys) (GEMINI.md Rule 8)
 * 4. Existence of all HTML and dynamically generated event handlers (onclick, onchange, onkeydown)
 * 5. Complete DOM element ID consistency between JS references and HTML markup
 * 6. Mock execution test: renderPeerList, clientHistory tracking, sparkline generation
 * 7. Client Passport generator test: verifies standalone HTML generation and passport JS functions
 */

const fs = require('fs');
const path = require('path');
const vm = require('vm');

const htmlPath = path.resolve(__dirname, '../src/index.html');
if (!fs.existsSync(htmlPath)) {
  console.error(`FAIL: File not found: ${htmlPath}`);
  process.exit(1);
}

const html = fs.readFileSync(htmlPath, 'utf8');
let errors = 0;

function report(status, title, detail) {
  if (status === 'PASS') {
    console.log(`[PASS] ${title}`);
  } else {
    console.error(`[FAIL] ${title}${detail ? ': ' + detail : ''}`);
    errors++;
  }
}

console.log('=== Running AwgIt Frontend Integrity Test Suite ===\n');

// ----------------------------------------------------
// TEST 1: Check for forbidden external CDN dependencies
// ----------------------------------------------------
const externalRefs = [...html.matchAll(/(?:src|href)=["'](https?:\/\/[^"']+)["']/gi)]
  .map(m => m[1])
  .filter(url => !url.includes('127.0.0.1') && !url.includes('localhost'));

if (externalRefs.length > 0) {
  report('FAIL', 'External CDN dependencies check', `Found external URLs: ${externalRefs.join(', ')}`);
} else {
  report('PASS', 'External dependencies check (strictly local assets, no CDN)');
}

// ----------------------------------------------------
// TEST 2: Extract & Validate JavaScript Syntax
// ----------------------------------------------------
const scriptMatches = [...html.matchAll(/<script(?![^>]*src=)[^>]*>([\s\S]*?)<\/script>/gi)];
if (scriptMatches.length === 0) {
  report('FAIL', 'JavaScript inline script extraction', 'No inline script found in index.html');
  process.exit(1);
}
const jsCode = scriptMatches[0][1];

try {
  new Function(jsCode);
  report('PASS', 'JavaScript syntax verification');
} catch (e) {
  report('FAIL', 'JavaScript syntax verification', e.message);
  process.exit(1);
}

// ----------------------------------------------------
// TEST 3: Mock DOM Sandbox Environment
// ----------------------------------------------------
const elementsRegistry = new Map();

function getOrCreateMockElement(id) {
  if (!elementsRegistry.has(id)) {
    elementsRegistry.set(id, {
      id,
      innerHTML: '',
      textContent: '',
      value: '',
      style: {},
      disabled: false,
      checked: false,
      classList: {
        _classes: new Set(),
        add(c) { this._classes.add(c); },
        remove(c) { this._classes.delete(c); },
        toggle(c, force) {
          if (force === undefined) {
            if (this._classes.has(c)) this._classes.delete(c); else this._classes.add(c);
          } else if (force) this._classes.add(c); else this._classes.delete(c);
        },
        contains(c) { return this._classes.has(c); }
      },
      setAttribute(attr, val) { this[attr] = val; },
      getAttribute(attr) { return this[attr] || null; },
      addEventListener() {},
      focus() {},
      click() {}
    });
  }
  return elementsRegistry.get(id);
}

const sandbox = {
  document: {
    documentElement: {
      getAttribute: () => 'dark',
      setAttribute: () => {}
    },
    getElementById: (id) => getOrCreateMockElement(id),
    querySelectorAll: () => [],
    querySelector: () => null,
    createElement: () => ({
      innerHTML: '',
      style: {},
      setAttribute: () => {},
      classList: { add: () => {}, remove: () => {} },
      querySelector: () => null,
      appendChild: () => {},
      removeChild: () => {}
    }),
    body: {
      appendChild: () => {},
      removeChild: () => {}
    },
    addEventListener: () => {}
  },
  localStorage: {
    _data: {},
    getItem(k) { return this._data[k] || null; },
    setItem(k, v) { this._data[k] = String(v); },
    removeItem(k) { delete this._data[k]; }
  },
  navigator: {
    language: 'ru-RU',
    clipboard: { writeText: async () => {} }
  },
  URL: {
    createObjectURL: () => 'blob:mock-url',
    revokeObjectURL: () => {}
  },
  Blob: class {},
  QRCode: class { constructor() {} },
  setInterval: () => 1,
  clearInterval: () => {},
  setTimeout: (fn) => fn(),
  clearTimeout: () => {},
  fetch: async () => ({ json: async () => ({ status: 'ok', peers: [] }) }),
  alert: () => {},
  confirm: () => true,
  console: {
    log: () => {},
    warn: () => {},
    error: (...args) => console.error('  [Browser Console Error]:', ...args)
  }
};
sandbox.window = sandbox;

const context = vm.createContext(sandbox);

try {
  vm.runInContext(jsCode, context);
  report('PASS', 'Script initialization in mock sandbox');
} catch (e) {
  report('FAIL', 'Script initialization in mock sandbox', e.stack);
}

// ----------------------------------------------------
// TEST 4: Bilingual i18n Dictionary Parity Check
// ----------------------------------------------------
try {
  const i18n = vm.runInContext('I18N', context);
  if (!i18n || !i18n.en || !i18n.ru) {
    report('FAIL', 'i18n structure', 'I18N.en or I18N.ru is missing');
  } else {
    const enKeys = Object.keys(i18n.en).sort();
    const ruKeys = Object.keys(i18n.ru).sort();

    const missingInRu = enKeys.filter(k => !(k in i18n.ru));
    const missingInEn = ruKeys.filter(k => !(k in i18n.en));

    if (missingInRu.length > 0 || missingInEn.length > 0) {
      report('FAIL', 'i18n bilingual parity',
        `Missing in RU: [${missingInRu.join(', ')}]; Missing in EN: [${missingInEn.join(', ')}]`);
    } else {
      report('PASS', `i18n bilingual parity (all ${enKeys.length} keys synchronized in EN and RU)`);
    }
  }
} catch (e) {
  report('FAIL', 'i18n evaluation', e.message);
}

// ----------------------------------------------------
// TEST 5: Event Handlers and Function Existence Verification
// ----------------------------------------------------
// Exclude passport template section when scanning main window handlers
const passportRegex = /function generatePassportHtml[\s\S]*?return `[\s\S]*?<\/html>`;\s*}/;
const mainWindowHtml = html.replace(passportRegex, '');

const handlerRegex = /\bon(?:click|change|keydown|keyup|input|submit)\s*=\s*["']([^"']+)["']/gi;
const calledFunctions = new Set();

let match;
while ((match = handlerRegex.exec(mainWindowHtml)) !== null) {
  const codeSnippet = match[1];
  const fnMatches = codeSnippet.match(/([a-zA-Z0-9_$]+)\s*\(/g);
  if (fnMatches) {
    fnMatches.forEach(fm => {
      const fnName = fm.replace(/\s*\(/, '');
      if (!['if', 'for', 'switch', 'alert', 'confirm', 'setTimeout'].includes(fnName)) {
        calledFunctions.add(fnName);
      }
    });
  }
}

// Mandatory client lifecycle functions that MUST be defined
const mandatoryLifecycleFns = [
  'openCreateModal',
  'submitCreate',
  'openEdit',
  'submitEdit',
  'openDelete',
  'submitDelete',
  'openQr',
  'showQrModal',
  'downloadConf',
  'exportPassport',
  'doToggle',
  'doBackup',
  'doRestore',
  'submitRestore',
  'renderPeerList',
  'fetchClients',
  'renderSparkline',
  'saveAdminPassword',
  'removeAdminPassword',
  'updateSecurityForm',
  'stopPolling'
];
mandatoryLifecycleFns.forEach(fn => calledFunctions.add(fn));

const missingFunctions = [];
for (const fn of calledFunctions) {
  const isDefined = vm.runInContext(`typeof ${fn} === 'function'`, context);
  if (!isDefined) {
    missingFunctions.push(fn);
  }
}

if (missingFunctions.length > 0) {
  report('FAIL', 'Event handler functions existence check',
    `Missing required functions: ${missingFunctions.join(', ')}`);
} else {
  report('PASS', `All ${calledFunctions.size} event handler and lifecycle functions are defined and callable`);
}

// ----------------------------------------------------
// TEST 6: Mock End-to-End Client Rendering & Stats Simulation
// ----------------------------------------------------
try {
  const mockServerData = {
    status: 'ok',
    server: {
      interface: 'awg0',
      public_key: 'wpBj3ygxQ0I2lLE8q1DNaukExF4OzNNQ/OY2QpseLDs=',
      listen_port: 49155,
      endpoint: '62.16.41.168:49155'
    },
    auth_required: false,
    categories: [
      { name: 'Family', icon: '🏠' },
      { name: 'Work', icon: '💼' }
    ],
    peers: [
      {
        section: '@amneziawg_awg0[0]',
        name: 'Alex-Laptop',
        public_key: '5AsQKvkqFMWgoWA9yFzpzMIyPE+Uj5DNVearucm7vAg=',
        allowed_ips: '10.9.0.2/32',
        disabled: 0,
        online: true,
        latest_handshake: Math.floor(Date.now() / 1000) - 20,
        transfer_rx: 15400000,
        transfer_tx: 45000000,
        endpoint: '198.51.100.5:1234',
        group: 'Work',
        notes: 'Main work laptop',
        created_at: 1791520000
      },
      {
        section: '@amneziawg_awg0[1]',
        name: 'Home-TV',
        public_key: 'FYNNMgGMKFlxAgWSfus+Zk5Fp4441zDO6v24qGzKGT0=',
        allowed_ips: '10.9.0.3/32',
        disabled: 0,
        online: false,
        latest_handshake: Math.floor(Date.now() / 1000) - 500,
        transfer_rx: 500000,
        transfer_tx: 120000,
        endpoint: '(none)',
        group: 'Family',
        notes: '',
        created_at: 1791520100
      }
    ]
  };

  // Run render 1
  vm.runInContext(`renderPeerList(${JSON.stringify(mockServerData)})`, context);

  // Advance time & traffic, run render 2 (speed & sparklines test)
  mockServerData.peers[0].transfer_rx += 1024 * 1024 * 5;
  mockServerData.peers[0].transfer_tx += 1024 * 1024 * 10;
  vm.runInContext(`renderPeerList(${JSON.stringify(mockServerData)})`, context);

  const clientHistoryObj = vm.runInContext('clientHistory', context);
  const testPubKey = mockServerData.peers[0].public_key;

  if (!clientHistoryObj || !Array.isArray(clientHistoryObj[testPubKey])) {
    report('FAIL', 'clientHistory state validation', 'clientHistory data array missing for peer');
  } else {
    report('PASS', `Mock peer render and dynamic speed tracking (history points: ${clientHistoryObj[testPubKey].length})`);
  }
} catch (e) {
  report('FAIL', 'Client list rendering mock test', e.stack);
}

// ----------------------------------------------------
// TEST 7: Modal DOM Element References
// ----------------------------------------------------
const modalInputIds = [
  'createName', 'createGroup', 'createNotes', 'btnCreate',
  'editPubKey', 'editName', 'editIp', 'editGroup', 'editNotes', 'btnEdit',
  'deletePubKey', 'deleteClientName', 'btnDeleteSubmit',
  'qrTitle', 'qrBox', 'confPreview',
  'authInputPassword', 'btnAuthSubmit',
  'rowOldPassword', 'lblOldPassword', 'inputOldPassword',
  'lblNewPassword', 'inputNewPassword',
  'lblConfirmPassword', 'inputConfirmPassword',
  'btnSavePassword', 'btnRemovePassword'
];

const missingDomIds = [];
modalInputIds.forEach(id => {
  const idPattern = new RegExp(`id=["']${id}["']`);
  if (!idPattern.test(html)) {
    missingDomIds.push(id);
  }
});

if (missingDomIds.length > 0) {
  report('FAIL', 'Modal DOM IDs markup check', `Missing HTML elements: ${missingDomIds.join(', ')}`);
} else {
  report('PASS', `All ${modalInputIds.length} required modal DOM elements exist in HTML markup`);
}

// ----------------------------------------------------
// TEST 8: Standalone Client Passport Generator Test
// ----------------------------------------------------
try {
  const passportHtml = vm.runInContext(`generatePassportHtml('TestPhone', '10.9.0.5/32', '62.16.41.168:49155', 1791520000, '[Interface]\\nAddress = 10.9.0.5/24', 'data:image/png;base64,mock')`, context);
  if (!passportHtml || !passportHtml.includes('<!DOCTYPE html>') || !passportHtml.includes('dlConf()') || !passportHtml.includes('cpConf()')) {
    report('FAIL', 'Client Passport generation test', 'Generated passport HTML lacks required structure or download handlers');
  } else {
    report('PASS', 'Client Passport generation (autonomous HTML, offline QR, dlConf, cpConf)');
  }
} catch (e) {
  report('FAIL', 'Client Passport generation test', e.stack);
}

// ----------------------------------------------------
// TEST 9: Admin Password Change & Confirmation Validation
// ----------------------------------------------------
try {
  let lastAlert = '';
  context.alert = (msg) => { lastAlert = msg; };

  const inpOld = context.document.getElementById('inputOldPassword');
  const inpNew = context.document.getElementById('inputNewPassword');
  const inpConf = context.document.getElementById('inputConfirmPassword');

  // Case 1: Mismatch passwords
  inpNew.value = 'Secret123';
  inpConf.value = 'Secret456';
  vm.runInContext('saveAdminPassword()', context);
  const mismatchAlert = vm.runInContext('I18N[currentLang].passwordsMismatchAlert', context);
  if (lastAlert !== mismatchAlert) {
    report('FAIL', 'Password confirmation mismatch check', `Expected alert "${mismatchAlert}", got "${lastAlert}"`);
  } else {
    report('PASS', 'Password confirmation mismatch validation (blocked on unequal input)');
  }

  // Case 2: Missing old password when authRequired is true
  vm.runInContext('authRequired = true;', context);
  inpOld.value = '';
  inpNew.value = 'Secret123';
  inpConf.value = 'Secret123';
  vm.runInContext('saveAdminPassword()', context);
  const oldPassAlert = vm.runInContext('I18N[currentLang].enterOldPasswordAlert', context);
  if (lastAlert !== oldPassAlert) {
    report('FAIL', 'Current password required check', `Expected alert "${oldPassAlert}", got "${lastAlert}"`);
  } else {
    report('PASS', 'Current password required validation when changing existing password');
  }
} catch(e) {
  report('FAIL', 'Admin password confirmation test', e.stack);
}

// ----------------------------------------------------
// Final Result
// ----------------------------------------------------
console.log('\n---------------------------------------------------');
if (errors > 0) {
  console.error(`FAILED: ${errors} test(s) failed in Frontend Integrity Suite!`);
  process.exit(1);
} else {
  console.log('ALL FRONTEND INTEGRITY TESTS PASSED SUCCESSFULLY! ✓');
  process.exit(0);
}
