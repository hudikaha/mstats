#!/usr/bin/env node
'use strict';
// 日本語: 合成データで通常表示とiframe表示の描画・系列・操作欄を比較する。
// English: Compare rendering, series, and controls in normal and iframe views using synthetic data.
const fs = require('fs'), os = require('os'), path = require('path'), http = require('http');
const assert = require('assert/strict');
const {execFileSync} = require('child_process');
const target = path.resolve(process.argv[2] || path.join(__dirname, '../../web/morttr2.rb'));
const port = Number(process.env.CHROME_PORT || 9224);
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'morttr-iframe-'));
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
const rows = [], base = {loc:'jpn', area:'Japan', areaj:'日本', sex:'both', rate:'', algo:'', type:'cfm', src_url:['https://example.org/synthetic-test']};
for (let year = 2000; year <= 2026; year++) {
  rows.push({...base, year, category:'death', dcode:'allcause', age_all:10000 + (year - 2000) * 100});
  rows.push({...base, year, category:'pop', dcode:'', age_all:1000000});
}
for (let year = 2010; year <= 2026; year++) {
  const jan4 = new Date(Date.UTC(year, 0, 4));
  const monday = jan4.getTime() - ((jan4.getUTCDay() + 6) % 7) * 86400000;
  for (let week = 1; week <= 52; week++) {
    for (const rate of ['', 'crude']) rows.push({...base, year, week, type:'stmf', rate,
      yearweek:`${year}w${String(week).padStart(2, '0')}`,
      date:new Date(monday + ((week - 1) * 7 + 6) * 86400000).toISOString().slice(0, 10),
      category:'death', dcode:'allcause', age_all:(200 + week) * (rate ? 5.2 : 1)});
  }
}
const fixture = path.join(tmp, 'fixture.json');
fs.writeFileSync(fixture, JSON.stringify(rows));
let html;
const server = http.createServer((req, res) => {
  const name = new URL(req.url, 'http://localhost').pathname.slice(1);
  if (name === 'host') {
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.end('<!doctype html><iframe style="width:100%;height:900px;border:0" src="/' + new URL(req.url, 'http://localhost').search.replaceAll('&', '&amp;') + '"></iframe>'); return;
  }
  if (!name) { res.setHeader('Content-Type', 'text/html; charset=utf-8'); res.end(html); return; }
  if (!['morttr-calc.js', 'morttr-sim-worker.js', 'mfacts.css'].includes(name)) { res.writeHead(404); res.end(); return; }
  res.setHeader('Content-Type', name.endsWith('.js') ? 'text/javascript' : 'text/css');
  res.end(fs.readFileSync(path.join(path.dirname(target), name)));
});
async function chrome(method, route, json = true) {
  const response = await fetch(`http://127.0.0.1:${port}${route}`, {method});
  assert(response.ok, `Chrome HTTP ${response.status}`);
  return json ? response.json() : response.text();
}
async function inspect(url, embedded, dimensions = {}) {
  const tab = await chrome('PUT', `/json/new?${encodeURIComponent(url)}`);
  const socket = new WebSocket(tab.webSocketDebuggerUrl);
  try {
    await new Promise((resolve, reject) => { socket.onopen = resolve; socket.onerror = reject; });
    const pending = new Map(); let id = 0;
    socket.onmessage = event => {
      const reply = JSON.parse(event.data);
      if (pending.has(reply.id)) { pending.get(reply.id)(reply); pending.delete(reply.id); }
    };
    const send = (method, params) => new Promise(resolve => {
      pending.set(++id, resolve); socket.send(JSON.stringify({id, method, params}));
    });
    let state;
    for (let attempt = 0; attempt < 160; attempt++) {
      const reply = await send('Runtime.evaluate', {returnByValue:true, expression:`(() => {
        const frame = document.querySelector('iframe');
        const doc = frame ? frame.contentDocument : document;
        const win = frame ? frame.contentWindow : window;
        if (!doc) return null;
        const visible = node => !!node && !!node.getClientRects().length && win.getComputedStyle(node).visibility !== 'hidden';
        const panelSizes = [];
        const visit = node => { if (/^concat_\\d+_group$/.test(node.mark?.name)) panelSizes.push([node.width, node.height]); (node.items || []).forEach(visit); };
        if (win.mortyearView) visit(win.mortyearView.scenegraph().root);
        return {panelSizes, graphs:doc.querySelectorAll('#mortyear-vis canvas, #mortyear-vis svg').length,
          loading:visible(doc.getElementById('morttr-calculation-status')),
          controls:[...doc.querySelectorAll('.mortyear-form, #mortyear-controls, .mortyear-downloads, .mortyear-note, .mortyear-sources, .mortyear-coverage')].filter(visible).length,
          heights:win.mortyearView ? win.eval('spec.vconcat.map(panel => panel.height)') : [],
          containerWidth:doc.getElementById('mortyear-vis')?.getBoundingClientRect().width,
          parentWidth:doc.getElementById('mortyear-vis')?.parentElement.clientWidth,
          editableDimensions:[...doc.querySelectorAll('[name=height], [name=width]')].filter(node => node.type !== 'hidden').length,
          formDimensions:Object.fromEntries([...doc.querySelectorAll('[name=height], [name=width]')].map(node => [node.name,node.value])),
          menu:!!doc.querySelector('.site-menu'), values:win.mortyearView ? JSON.parse(JSON.stringify([win.mortyearView.data('morttr_values'), win.mortyearView.data('morttr_weekly_values')])) : null};
      })()`});
      state = reply.result?.result?.value;
      if (state?.graphs && !state.loading) break;
      await sleep(250);
    }
    assert(state?.graphs > 0 && !state.loading, 'Graph did not finish rendering');
    assert.equal(state.menu, !embedded);
    assert(embedded ? state.controls === 0 : state.controls > 0, 'Wrong control visibility');
    assert(state.panelSizes.length > 0, 'Missing rendered panels');
    assert.deepEqual(state.panelSizes.map(size => size[1]), state.heights, 'Rendered panel height differs from requested height');
    assert.equal(state.editableDimensions, 0, 'Dimensions must have no editable form controls');
    if (dimensions.height >= 50) {
      assert(state.heights.every((height, i) => height === (new URL(url).searchParams.get('period') === 'weekly' && i % 3 !== 0 ? Math.max(50, dimensions.height / 2) : dimensions.height)), 'Wrong panel height ratio');
      assert.equal(state.formDimensions.height, String(dimensions.height));
    } else {
      assert.equal(state.heights[0], 200);
      assert(state.heights.slice(1).every(height => height === 100));
      assert.equal(state.formDimensions.height, undefined);
    }
    if (dimensions.width) {
      const expected = dimensions.width.endsWith('%') ? state.parentWidth * parseFloat(dimensions.width) / 100 : parseFloat(dimensions.width);
      assert(Math.abs(state.containerWidth - expected) < 1, `Container width ${state.containerWidth}, expected ${expected}`);
      assert.equal(state.formDimensions.width, dimensions.width);
      assert(state.panelSizes.every(size => Math.abs(size[0] - Math.max(1, Math.round(state.containerWidth) - 168)) < 1), 'Rendered plot width differs from container width');
    } else assert.equal(state.formDimensions.width, undefined);
    if (dimensions.width?.endsWith('%')) {
      await send('Runtime.evaluate', {expression:"document.querySelector('iframe').style.width = '600px'"});
      await sleep(700);
      const reply = await send('Runtime.evaluate', {returnByValue:true, expression:`(() => {
        const vis = document.querySelector('iframe').contentDocument.getElementById('mortyear-vis');
        const widths = [];
        const visit = node => { if (/^concat_\\d+_group$/.test(node.mark?.name)) widths.push(node.width); (node.items || []).forEach(visit); };
        visit(document.querySelector('iframe').contentWindow.mortyearView.scenegraph().root);
        return [vis.clientWidth, vis.parentElement.clientWidth, widths];
      })()`});
      const [width, parent, plots] = reply.result.result.value;
      assert(Math.abs(width - parent * parseFloat(dimensions.width) / 100) < 1, 'Percentage width did not resize');
      assert(plots.length && plots.every(value => Math.abs(value - Math.max(1, width - 168)) < 1), 'Rendered plots did not resize');
    }
    return state.values;
  } finally { socket.close(); await chrome('GET', `/json/close/${tab.id}`, false); }
}
(async () => {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  for (const period of ['calendar', 'weekly']) {
    let baseline;
    const cases = ['', '1', 'on', 'true', 'ON', '0', 'off', 'false', 'other'].map(value => ({value, extra:'', dimensions:{}}));
    for (const value of ['', '1']) {
      for (const [extra, dimensions] of [
        ['&height=50&width=800', {height:50,width:'800px'}],
        ['&height=200&width=80%', {height:200,width:'80%'}],
        ['&height=201&width=650px', {height:201,width:'650px'}],
        ['&height=49&width=bad', {height:50}],
        ['&height=80', {height:80}],
        ['&height=0', {height:50}],
        ['&height=-10', {height:50}],
        ['&height=bad&width=0', {}]
      ]) cases.push({value,extra,dimensions});
    }
    for (const {value,extra,dimensions} of cases) {
      const query = `l=ja&c=jpn&metric=deaths&period=${period}&i=${value}${extra}`;
      const output = execFileSync('ruby', [target, '--fixture', fixture, '--cache-dir', tmp], {
        env:{...process.env, REQUEST_METHOD:'GET', QUERY_STRING:query}, maxBuffer:30 * 1024 * 1024
      }).toString();
      html = output.split(/\r?\n\r?\n/).slice(1).join('\n\n');
      const values = await inspect(`http://127.0.0.1:${server.address().port}/host?${query}`, ['1', 'on', 'true'].includes(value.toLowerCase()), dimensions);
      assert(values?.some(items => items.length), 'Missing observation data');
      if (!baseline) baseline = values;
      else assert.deepEqual(values, baseline, 'iframe changed graph data');
      console.log(`OK ${path.basename(target)} ${period} i=${value || '(empty)'}${extra}`);
    }
  }
})().catch(error => { console.error(error); process.exitCode = 1; }).finally(() => {
  server.close(); fs.rmSync(tmp, {recursive:true, force:true});
});
