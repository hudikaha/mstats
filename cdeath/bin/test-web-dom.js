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
const ids = option('--ids')?.split(',');
const screenshotDir = option('--screenshots');
const port = Number(option('--port') || 9224);
const formal = args.includes('--formal');
const cases = JSON.parse(fs.readFileSync(casesPath, 'utf8'))
  .filter(item => !ids || ids.includes(item.id))
  .map(item => formal ? {...item, url: item.url.replace(/^mortyear2\.rb/, 'mortyear.rb').replace(/^mort2\.rb/, 'mort.rb').replace(/^codtr2\.rb/, 'codtr.rb').replace(/^cod2\.rb/, 'cod.rb')} : item);

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
  return response.result?.result?.value;
}

async function waitForGraph(send, timeoutMs = 30000) {
  const started = Date.now();
  while (Date.now() - started < timeoutMs) {
    const state = await evaluate(send, `(() => ({
      ready: document.readyState,
      graphs: document.querySelectorAll('.vega-embed canvas, .vega-embed svg').length,
      loading: !!document.querySelector('.mortyear-loading, #blink1223'),
      text: document.body ? document.body.innerText : '',
      checked: [...document.querySelectorAll('input:checked')].map(input => [input.name, input.value]),
      controls: [...document.querySelectorAll('input')].map(input => [input.name, input.value, input.disabled, input.checked]),
      titles: [...document.querySelectorAll('h1, h2, h3')].map(node => node.innerText.trim()).filter(Boolean)
    }))()`);
    if (state?.ready === 'complete' && state.graphs > 0 && !state.loading) return state;
    await sleep(250);
  }
  return evaluate(send, `(() => ({
    ready: document.readyState,
    graphs: document.querySelectorAll('.vega-embed canvas, .vega-embed svg').length,
    loading: !!document.querySelector('.mortyear-loading, #blink1223'),
    text: document.body ? document.body.innerText : '',
    checked: [...document.querySelectorAll('input:checked')].map(input => [input.name, input.value]),
    controls: [...document.querySelectorAll('input')].map(input => [input.name, input.value, input.disabled, input.checked]),
    titles: [...document.querySelectorAll('h1, h2, h3')].map(node => node.innerText.trim()).filter(Boolean)
  }))()`);
}

(async () => {
  if (screenshotDir) fs.mkdirSync(screenshotDir, {recursive: true});
  const suiteStarted = performance.now();
  const failures = [];
  const timings = [];
  for (const [index, item] of cases.entries()) {
    const started = performance.now();
    const errors = [];
    let state = {graphs: 0, loading: true, text: ''};
    let client;
    try {
      client = await connect(new URL(item.url, base).href);
      await client.send('Page.enable');
      await client.send('Runtime.enable');
      await client.send('Page.setLifecycleEventsEnabled', {enabled: true});
      state = await waitForGraph(client.send);
      if (!state.graphs) errors.push('rendered graph missing');
      if (state.loading) errors.push('loading indicator remains');
      if (/Bad Gateway|Internal Server Error|Application error/i.test(state.text)) errors.push('error page');
      for (const expected of item.dom_expect || []) {
        if (!state.text.includes(expected)) errors.push(`missing ${JSON.stringify(expected)}`);
      }
      const checked = new Map();
      for (const [name, value] of state.checked || []) {
        if (!checked.has(name)) checked.set(name, []);
        checked.get(name).push(value);
      }
      for (const [name, values] of Object.entries(item.checked || {})) {
        for (const value of values) {
          if (!(checked.get(name) || []).includes(value)) errors.push(`unchecked ${name}=${value}`);
        }
      }
      if (screenshotDir) {
        const metrics = await client.send('Page.getLayoutMetrics');
        const size = metrics.result?.contentSize || {width: 1280, height: 900};
        await client.send('Emulation.setDeviceMetricsOverride', {
          width: Math.min(Math.ceil(size.width), 1600),
          height: Math.min(Math.ceil(size.height), 12000),
          deviceScaleFactor: 1,
          mobile: false
        });
        const shot = await client.send('Page.captureScreenshot', {format: 'png', captureBeyondViewport: true});
        fs.writeFileSync(path.join(screenshotDir, `${item.id}.png`), Buffer.from(shot.result.data, 'base64'));
      }
    } catch (error) {
      errors.push(`${error.name}: ${error.message}`);
    } finally {
      if (client) {
        await client.send('Page.close');
        client.socket.close();
      }
    }
    const elapsed = (performance.now() - started) / 1000;
    timings.push([item.id, elapsed]);
    const status = errors.length ? 'FAIL' : 'ok';
    process.stdout.write(`${String(index + 1).padStart(2, '0')}/${cases.length} ${item.id.padEnd(4)} ${status.padEnd(4)} graphs=${String(state.graphs).padStart(2)} ${elapsed.toFixed(2)}s ${item.summary}\n`);
    if (errors.length) failures.push([item.id, errors, {checked: state.checked, controls: state.controls, titles: state.titles}]);
  }
  const elapsed = (performance.now() - suiteStarted) / 1000;
  const slowest = timings.reduce((result, item) => !result || item[1] > result[1] ? item : result, null);
  process.stdout.write(`elapsed=${elapsed.toFixed(2)}s average=${(elapsed / cases.length).toFixed(2)}s slowest=${slowest?.[0] || '-'} ${(slowest?.[1] || 0).toFixed(2)}s\n`);
  for (const [id, errors, state] of failures) {
    const requested = Object.entries(cases.find(item => item.id === id)?.checked || {}).flatMap(([name, values]) =>
      (state.controls || []).filter(control => control[0] === name && values.includes(control[1])));
    process.stderr.write(`${id}: ${errors.join(', ')} checked=${JSON.stringify(state.checked)} requested=${JSON.stringify(requested)} titles=${JSON.stringify(state.titles)}\n`);
  }
  process.exit(failures.length ? 1 : 0);
})().catch(error => {
  console.error(error);
  process.exit(1);
});
