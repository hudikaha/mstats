#!/usr/bin/env node
'use strict';
// 日本語: 検証版の実data・描画・複数地域選択と、org/anon間のチェコ系列一致を確認する。
// English: Check trial-page data, rendering, multi-area selection, and Czech parity across sources.
const assert = require('assert/strict');
const base = process.env.VDEATH2_BASE || 'https://medicalfacts.info/vdeath2.rb';
const port = Number(process.env.CHROME_PORT || 9224);
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
async function chrome(method, route, json = true) {
  const response = await fetch(`http://127.0.0.1:${port}${route}`, {method});
  assert(response.ok, `Chrome HTTP ${response.status}`);
  return json ? response.json() : response.text();
}
async function check(src, locations) {
  const url = `${base}?l=ja&c=${locations.join('~')}&src=${src}&ages=all&stacks=deaths&lines=&bars=&doses=0~1~2`;
  const tab = await chrome('PUT', `/json/new?${encodeURIComponent(url)}`);
  const ws = new WebSocket(tab.webSocketDebuggerUrl);
  try {
    await new Promise((resolve, reject) => { ws.onopen = resolve; ws.onerror = reject; });
    const pending = new Map(), errors = []; let id = 0;
    ws.onmessage = event => {
      const reply = JSON.parse(event.data);
      if (pending.has(reply.id)) { pending.get(reply.id)(reply); pending.delete(reply.id); }
      if (reply.method === 'Runtime.exceptionThrown') errors.push(reply.params.exceptionDetails.text);
    };
    const send = (method, params = {}) => new Promise(resolve => {
      pending.set(++id, resolve); ws.send(JSON.stringify({id, method, params}));
    });
    await send('Runtime.enable');
    const evaluate = async expression => {
      const reply = await send('Runtime.evaluate', {expression, returnByValue:true});
      assert(!reply.result?.exceptionDetails, JSON.stringify(reply.result?.exceptionDetails));
      return reply.result?.result?.value;
    };
    let state;
    for (let n = 0; n < 180; n++) {
      state = await evaluate(`({ready:document.readyState,
        graph:!!window.vdeathView && !!document.querySelector('#vis canvas,#vis svg'),
        locations:[...document.querySelectorAll('input[name=c]:checked')].map(n=>n.value),
        src:document.querySelector('input[name=src]:checked')?.value})`);
      if (state?.ready === 'complete' && state.graph) break;
      await sleep(500);
    }
    assert(state?.graph, `No rendered graph: ${url}`);
    assert.deepEqual(state.locations.sort(), [...locations].sort());
    assert.equal(state.src, src);
    assert.deepEqual(errors, []);
    const data = await evaluate('vlSpec.data.values');
    assert(data.length > 0);
    const expected = new Map();
    for (const row of data.filter(r => r.loc !== 'all')) {
      assert(locations.includes(row.loc), `Unselected area ${row.loc}`);
      const key = [row.step, row.period, row.age, row.dose].join('|');
      const sums = expected.get(key) || {deaths:0,persondays:0,lives:0};
      for (const field of Object.keys(sums)) sums[field] += row[field];
      expected.set(key, sums);
    }
    const totals = data.filter(r => r.loc === 'all');
    assert.equal(totals.length, expected.size);
    for (const row of totals) {
      const sums = expected.get([row.step,row.period,row.age,row.dose].join('|'));
      for (const field of Object.keys(sums)) assert.equal(row[field], sums[field], `${src} ${row.doc_id} ${field}`);
      const reference = expected.get([row.step,row.period,row.age,'0'].join('|'));
      if (row.persondays && reference?.persondays && reference.deaths && row.deaths) {
        const rr = Number(((row.deaths / row.persondays) / (reference.deaths / reference.persondays)).toFixed(4));
        assert(Math.abs(row.rr0 - rr) < 0.00011, 'Incorrect pooled risk ratio');
      }
    }
    // チェコと日本を交互に選んでも既存選択とdata源を解除しない。
    // Toggling Czech/Japanese areas must retain the other selections and source.
    await evaluate(`(() => {for (const loc of ['cze','jp13210']) {
      const box=document.querySelector('input[name=c][value="'+loc+'"]');
      if(box.checked) box.click(); box.click();
    }})()`);
    const selection = await evaluate(`({areas:[...document.querySelectorAll('input[name=c]:checked')].map(n=>n.value),src:document.querySelector('input[name=src]:checked').value})`);
    assert(selection.areas.includes('cze') && selection.areas.includes('jp13210'));
    assert.equal(selection.src, src);
    const formUrl = await evaluate(`(() => {let url; const assign=submitForm.toString().replace('window.location.href = queryString;', 'return queryString;'); return eval('('+assign+')')();})()`);
    const params = new URL(formUrl, base).searchParams;
    assert(params.get('c').split('~').includes('cze') && params.get('c').split('~').includes('jp13210'));
    assert.equal(params.get('src'), src);
    console.log(`OK ${src} ${locations.join('~')}: ${data.length} records, ${totals.length} pooled groups`);
    return data;
  } finally { ws.close(); await chrome('GET', `/json/close/${tab.id}`, false); }
}
(async () => {
  for (const locations of [['all','cze'], ['all','cze','jp13210']]) {
    const org = await check('org', locations);
    const anon = await check('anon', locations);
    assert.deepEqual(org.filter(r=>r.loc==='cze'), anon.filter(r=>r.loc==='cze'), 'Czech source differs');
  }
  await check('org', ['all','jp13210']);
})().catch(error => { console.error(error); process.exitCode = 1; });
