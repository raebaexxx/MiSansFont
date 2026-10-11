#!/usr/bin/env node
// Прогон webroot/index.html без WebView: подменяем DOM и ksu,
// затем нажимаем кнопки как пользователь.
//
// node --check ловит только синтаксис. Ошибка вида
//     $('st').className = 'st' (...)   →  TypeError: "st" is not a function
// проходит его молча, потому что это корректный синтаксис: строка рядом
// с открытой скобкой разбирается как вызов. Поэтому нужен запуск.

const fs = require('fs');
const path = require('path');

const html = fs.readFileSync(
  path.join(__dirname, 'webroot', 'index.html'), 'utf8');
const js = html.match(/<script>([\s\S]*?)<\/script>/)[1];

// ---- заглушки DOM ----
const listeners = {};
function mkEl(id) {
  return {
    id, textContent: '', className: '', innerHTML: '', value: '0', disabled: false,
    style: { setProperty() {} },
    dataset: {},
    addEventListener(ev, fn) { (listeners[id + ':' + ev] ||= []).push(fn); },
    set onclick(fn) { (listeners[id + ':click'] ||= []).push(fn); },
    get onclick() { return null; },
    classList: { contains: () => false },
  };
}
const els = {};
const document = {
  getElementById(id) { return (els[id] ||= mkEl(id)); },
  querySelectorAll() { return []; },
};

global.document = document;
global.window = global;

// ---- заглушки ksu ----
const calls = [];
let execResults = { 'cat /data/adb/misans/shift 2>/dev/null': '300\n' };
global.ksu = {
  enableEdgeToEdge() {},
  toast(m) { calls.push(['toast', m]); },
  exec(cmd, opts, cbName) {
    calls.push(['exec', cmd]);
    setImmediate(() => {
      const out = execResults[cmd];
      if (out === undefined) {
        if (/action\.sh set/.test(cmd)) { global[cbName](0, 'сохранено\n', ''); return; }
        global[cbName](0, '', '');
        return;
      }
      global[cbName](0, out, '');
    });
  },
};

// ---- запуск ----
try {
  new Function(js)();
} catch (e) {
  console.log('  ОШИБКА ВО ВРЕМЯ ИНИЦИАЛИЗАЦИИ:', e.message);
  process.exit(1);
}

const tick = () => new Promise(r => setTimeout(r, 20));
const fire = async (id, ev = 'click') => {
  for (const fn of (listeners[id + ':' + ev] || [])) fn({ target: { dataset: {}, classList: { contains: () => true } } });
  await tick();
};

(async () => {
  console.log('  инициализация: ок');

  // значение подхватилось?
  await tick();
  console.log('  прочитан сдвиг из файла:', String(els['sl'].value) === '300' ? 'да, 300' : 'НЕТ (' + els['sl'].value + ')');
  console.log('  таблица весов заполнена:', els['rows'].innerHTML.length > 50 ? 'да' : 'НЕТ');
  console.log('  подпись версии:', els['ver'].textContent);

  // кнопка «Сохранить»
  await fire('apply');
  const st1 = els['st'].textContent;
  console.log('  Сохранить ->', JSON.stringify(st1));
  console.log('    className:', JSON.stringify(els['st'].className));
  const saved = calls.find(c => c[0] === 'exec' && /action\.sh set/.test(c[1]));
  console.log('    команда:', saved ? saved[1] : 'НЕ ВЫЗВАНА');
  console.log('    ошибка в статусе:', st1.includes('Не удалось') || st1.includes('Ошибка') ? 'ДА' : 'нет');

  // кнопка «Сохранить и перезагрузить»
  calls.length = 0;
  await fire('reboot');
  const st2 = els['st'].textContent;
  console.log('  Сохранить и перезагрузить ->', JSON.stringify(st2));
  console.log('    reboot вызван:', calls.some(c => c[1] && c[1].includes('reboot')) ? 'да' : 'нет');

  // «Прочитать текущее»
  calls.length = 0;
  await fire('reload');
  console.log('  Прочитать текущее -> прочитал:', els['sl'].value);

  const bad = st1.includes('Не удалось') || st1.includes('Ошибка') || st2.includes('Не удалось') || st2.includes('Ошибка');
  console.log(bad ? '\n  ПРОВАЛ: интерфейс сообщил об ошибке' : '\n  ПРОХОД: все кнопки отработали');
  process.exit(bad ? 1 : 0);
})();
