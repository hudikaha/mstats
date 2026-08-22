#!/usr/bin/env node
'use strict';

const fs = require('fs');
const http = require('http');
const path = require('path');

const args = process.argv.slice(2);
const option = name => {
  const index = args.indexOf(name);
  return index >= 0 ? args[index + 1] : null;
};
const casesPath = option('--cases') || path.resolve(__dirname, '../test/web-tests.json');
const base = option('--base') || 'https://medicalfacts.info/';
const port = Number(option('--port') || 9224);
const selectedIds = option('--ids')?.split(',');
const sourceCases = new Map(JSON.parse(fs.readFileSync(casesPath, 'utf8')).map(item => [item.id, item]));
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));

const requestJson = (method, requestPath) => new Promise((resolve, reject) => {
  const request = http.request({host: '127.0.0.1', port, path: requestPath, method}, response => {
    let body = '';
    response.on('data', chunk => { body += chunk; });
    response.on('end', () => {
      try { resolve(JSON.parse(body)); } catch (error) { reject(error); }
    });
  });
  request.on('error', reject);
  request.end();
});

async function connect(url) {
  const target = await requestJson('PUT', `/json/new?${encodeURIComponent(url)}`);
  const socket = new WebSocket(target.webSocketDebuggerUrl);
  const pending = new Map();
  let commandId = 0;
  socket.onmessage = event => {
    const message = JSON.parse(event.data);
    if (message.id && pending.has(message.id)) {
      pending.get(message.id)(message);
      pending.delete(message.id);
    }
  };
  await new Promise((resolve, reject) => {
    socket.onopen = resolve;
    socket.onerror = reject;
  });
  const send = (method, params = {}) => new Promise(resolve => {
    const id = ++commandId;
    pending.set(id, resolve);
    socket.send(JSON.stringify({id, method, params}));
  });
  return {socket, send};
}

async function evaluate(send, expression) {
  const response = await send('Runtime.evaluate', {expression, returnByValue: true, awaitPromise: true});
  if (response.result?.exceptionDetails) throw new Error(response.result.exceptionDetails.text || 'JavaScript evaluation failed');
  return response.result?.result?.value;
}

async function waitUntil(send, expression, timeoutMs = 30000) {
  const started = Date.now();
  while (Date.now() - started < timeoutMs) {
    const result = await evaluate(send, expression);
    if (result) return result;
    await sleep(250);
  }
  throw new Error(`timeout: ${expression}`);
}

async function waitForGraph(send) {
  return waitUntil(send, `(() => document.readyState === 'complete' &&
    document.querySelectorAll('.vega-embed canvas, .vega-embed svg').length > 0 &&
    !document.querySelector('.mortyear-loading, #blink1223'))()`);
}

const tests = [
  {
    id: 'MY03', summary: '20-24歳を再読込みしても保持',
    action: `document.querySelector('.mortyear-form').requestSubmit(); true`,
    expect: `(() => location.search.includes('ages=20_24') && document.querySelector('.age-option[value="age_20_24"]')?.checked)()`
  },
  {
    id: 'MY08', summary: 'flu27から暦年へ切替え、学習終了年とENG/GBRを変換',
    action: `(() => { const input = document.querySelector('.period-option[value="calendar"]'); input.click(); return true; })()`,
    expect: `(() => location.search.includes('period=calendar') && location.search.includes('train_to=2019') && location.search.includes('gbr') && !location.search.includes('eng'))()`
  },
  {
    id: 'MY10', summary: '週次・月次表示checkboxを切替可能',
    action: `(() => { const input = document.querySelector('#weekly-view-checkbox'); input.click(); return input.checked; })()`,
    noNavigation: true,
    expect: `document.querySelector('#weekly-view-checkbox')?.checked === true`
  },
  {
    id: 'MY11', summary: '出生関連死亡率では年齢選択を隠す',
    noAction: true,
    expect: `(() => getComputedStyle(document.querySelector('#age-fieldset')).display === 'none' && document.querySelector('.cause-option[value="infant"]')?.checked)()`
  },
  {
    id: 'MY15', summary: '罹患も表示を解除してURLへ反映',
    action: `(() => { const input = document.querySelector('#include-incidence'); input.checked = false; document.querySelector('.mortyear-form').requestSubmit(); return true; })()`,
    expect: `!new URL(location.href).searchParams.has('include_incidence') && !document.querySelector('#include-incidence')?.checked`
  },
  {
    id: 'MY18', summary: '75歳以上の詳細範囲をcanonical URLへ保持',
    action: `document.querySelector('.mortyear-form').requestSubmit(); true`,
    expect: `(() => location.search.includes('ages=75-100plus') && ['age_75_79','age_80_84','age_85_89','age_90_94','age_95_99','age_100plus'].every(value => document.querySelector('.age-option[value="' + value + '"]')?.checked))()`
  },
  {
    id: 'MY19', summary: '準PoissonとPoissonでsimulation controlを切替',
    action: `(() => { const quasi = document.querySelector('.model-option[value="quasi_poisson"]'); quasi.click(); const hidden = getComputedStyle(document.querySelector('#simulation-interval-control')).display === 'none'; const poisson = document.querySelector('.model-option[value="poisson"]'); poisson.click(); document.querySelector('#simulation-interval-checkbox').click(); return hidden && getComputedStyle(document.querySelector('#simulation-interval-control')).display !== 'none'; })()`,
    noNavigation: true,
    expect: `document.querySelector('.model-option[value="poisson"]')?.checked && new URL(location.href).searchParams.get('chart_model') === 'poisson' && new URL(location.href).searchParams.get('interval') === 'auto' && getComputedStyle(document.querySelector('#simulation-interval-control')).display !== 'none'`
  },
  {
    id: 'MY20', summary: '言語buttonで日本語URLへ切替',
    action: `document.querySelector('.language-button[data-language="ja"]').click(); true`,
    expect: `new URL(location.href).searchParams.get('l') === 'ja' && document.body.innerText.includes('各国・各地域の死亡数・死亡率と予測区間')`
  },
  {
    id: 'MY31', summary: '表示開始年と新型コロナ死亡・ワクチン全体接種を保持',
    action: `(() => { const url = new URL(location.href); url.searchParams.set('start_year', '2019'); history.replaceState(null, '', url); const slider = document.querySelector('#start-year-slider'); slider.value = '2020'; slider.dispatchEvent(new Event('input', {bubbles:true})); document.querySelector('#zero-base-checkbox').click(); const deficit = document.querySelector('#deficit-checkbox'); if (deficit.checked) deficit.click(); deficit.click(); document.querySelector('#covid-overlay-checkbox').click(); document.querySelector('#vaxx-overlay-checkbox').click(); location.reload(); return true; })()`,
    expect: `(() => new URL(location.href).searchParams.get('start_year') === '2020' && ['zero_base','include_deficit','covid_overlay','vaxx_overlay'].every(name => new URL(location.href).searchParams.get(name) === '1') && document.querySelector('#start-year-hidden')?.value === '2020' && document.querySelector('#start-year-slider')?.max === '2020' && document.querySelector('#start-year-slider')?.value === '2020' && document.querySelector('#zero-base-checkbox')?.checked && document.querySelector('#deficit-checkbox')?.checked && document.querySelector('#covid-overlay-checkbox')?.checked && document.querySelector('#vaxx-overlay-checkbox')?.checked && weeklyValues.some(item => item.excess < 0) && window.mortyearView?.signal('zero_base') === true && window.mortyearView?.signal('include_deficit') === true && window.mortyearView?.signal('show_covid_overlay') === true && window.mortyearView?.signal('show_vaxx_overlay') === true)()`
  }
].filter(test => !selectedIds || selectedIds.includes(test.id));

(async () => {
  const suiteStarted = performance.now();
  const failures = [];
  const timings = [];
  for (const [index, test] of tests.entries()) {
    const started = performance.now();
    const errors = [];
    let client;
    try {
      const item = sourceCases.get(test.id);
      client = await connect('about:blank');
      await client.send('Page.enable');
      await client.send('Runtime.enable');
      await client.send('Security.enable');
      await client.send('Security.setIgnoreCertificateErrors', {ignore: true});
      await client.send('Page.navigate', {url: new URL(item.url, base).href});
      await waitForGraph(client.send);
      if (!test.noAction) await evaluate(client.send, test.action);
      else if (test.action) await evaluate(client.send, test.action);
      if (!test.noNavigation && !test.noAction) {
        await sleep(500);
        await waitForGraph(client.send);
      }
      await waitUntil(client.send, test.expect);
    } catch (error) {
      let state = null;
      try {
        state = client && await evaluate(client.send, `({url: location.href, checked: [...document.querySelectorAll('input:checked')].map(input => [input.name, input.value]), deficitSignal: window.mortyearView?.signal('include_deficit'), negativeWeeks: typeof weeklyValues === 'undefined' ? null : weeklyValues.filter(item => item.excess < 0).length, graphText: document.querySelector('#mortyear-vis')?.textContent.slice(-300)})`);
      } catch (_error) {}
      errors.push(`${error.name}: ${error.message} state=${JSON.stringify(state)}`);
    } finally {
      if (client) {
        await client.send('Page.close');
        client.socket.close();
      }
    }
    const elapsed = (performance.now() - started) / 1000;
    timings.push([test.id, elapsed]);
    process.stdout.write(`${String(index + 1).padStart(2, '0')}/${tests.length} ${test.id} ${errors.length ? 'FAIL' : 'ok  '} ${elapsed.toFixed(2)}s ${test.summary}\n`);
    if (errors.length) failures.push([test.id, errors]);
  }
  const elapsed = (performance.now() - suiteStarted) / 1000;
  const slowest = timings.reduce((result, item) => !result || item[1] > result[1] ? item : result, null);
  process.stdout.write(`elapsed=${elapsed.toFixed(2)}s average=${(elapsed / tests.length).toFixed(2)}s slowest=${slowest?.[0] || '-'} ${(slowest?.[1] || 0).toFixed(2)}s\n`);
  failures.forEach(([id, errors]) => process.stderr.write(`${id}: ${errors.join(', ')}\n`));
  process.exit(failures.length ? 1 : 0);
})().catch(error => {
  console.error(error);
  process.exit(1);
});
