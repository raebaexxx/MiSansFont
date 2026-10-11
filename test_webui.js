#!/usr/bin/env node
// Runs webroot/index.html outside a WebView: stubs document and ksu, then
// presses the buttons the way a user would.
//
// `node --check` only catches syntax errors. This one catches the rest — a
// missing '+' once made `className = 'st' (...)` parse as a call on a string,
// which is valid syntax and fails only at runtime, so the save button threw
// "st is not a function" while the check passed.
//
// Usage:  node test_webui.js

const fs = require('fs');
const path = require('path');

const html = fs.readFileSync(
  path.join(__dirname, 'webroot', 'index.html'), 'utf8');
const js = html.match(/<script>([\s\S]*?)<\/script>/)[1];

const listeners = {};
function mkEl(id) {
  return {
    id, textContent: '', className: '', innerHTML: '', value: '0', disabled: false,
    style: { setProperty() {} }, dataset: {},
    addEventListener(ev, fn) { (listeners[id + ':' + ev] ||= []).push(fn); },
    set onclick(fn) { (listeners[id + ':click'] ||= []).push(fn); },
    get onclick() { return null; },
    classList: { contains: () => false },
  };
}
const els = {};
global.document = {
  getElementById(id) { return (els[id] ||= mkEl(id)); },
  querySelectorAll() { return []; },
};
global.window = global;

const calls = [];
const replies = {
  'cat /data/adb/misans/shift 2>/dev/null': '300\n',
  'cat /data/adb/misans/unify 2>/dev/null': '1\n',
};
global.ksu = {
  enableEdgeToEdge() {},
  toast(m) { calls.push(['toast', m]); },
  exec(cmd, opts, cbName) {
    calls.push(['exec', cmd]);
    setImmediate(() => {
      if (cmd in replies) return global[cbName](0, replies[cmd], '');
      if (/action\.sh/.test(cmd)) return global[cbName](0, 'ok\n', '');
      global[cbName](0, '', '');
    });
  },
};

let failed = false;
function check(name, ok, detail) {
  if (!ok) failed = true;
  console.log(`  ${ok ? 'ok  ' : 'FAIL'}  ${name}${detail ? ' — ' + detail : ''}`);
}

try {
  new Function(js)();
} catch (e) {
  console.log('  FAIL  threw during init:', e.message);
  process.exit(1);
}

const tick = () => new Promise(r => setTimeout(r, 20));
async function press(id) {
  for (const fn of (listeners[id + ':click'] || [])) fn({});
  await tick();
}
const text = id => els[id].textContent || '';
const failed1 = s => /Не удалось|Ошибка/.test(s);

(async () => {
  await tick();
  check('shift read back', String(els['sl'].value) === '300', els['sl'].value);
  check('weight table filled', els['rows'].innerHTML.length > 50);

  await press('apply');
  check('save reports success', /Сохранено/.test(text('st')), text('st'));
  check('save not flagged as error', !failed1(text('st')) && els['st'].className === 'st',
        els['st'].className);
  check('save ran action.sh',
        calls.some(c => c[1] === 'sh /data/adb/modules/misans/action.sh set 300'));

  calls.length = 0;
  await press('reboot');
  check('reboot path saves', /Перезагружаю/.test(text('st')), text('st'));
  check('reboot command sent', calls.some(c => /power reboot/.test(c[1] || '')));

  calls.length = 0;
  await press('unify');
  check('unify toggle state read', text('unifyState') === 'MiSans', text('unifyState'));
  check('unify toggle reports success', /Сохранено/.test(text('unifySt')), text('unifySt'));
  check('unify toggle sends command',
        calls.some(c => /action\.sh unify/.test(c[1] || '')),
        (calls.find(c => /unify/.test(c[1] || '')) || [])[1] || 'none');

  console.log(failed ? '\n  FAIL' : '\n  PASS');
  process.exit(failed ? 1 : 0);
})();
