(() => {
  'use strict';

  const config = window.KCORG_CONFIG;
  const text = config.text;
  const cache = new Map();
  let currentData;
  let lastViewWidth = 0;
  let resizeTimer;

  const status = message => {
    const element = document.getElementById('kcor-status');
    element.textContent = message || '';
    element.hidden = !message;
  };

  const fetchJson = async body => {
    const response = await fetch(config.elasticsearch_url, {
      method: 'POST', cache: 'no-cache', headers: {'Content-Type': 'application/json'},
      body: JSON.stringify(body)
    });
    if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
    return response.json();
  };

  const compareAges = (a, b) => {
    if (a === 'all') return 1;
    if (b === 'all') return -1;
    return Number.parseInt(a, 10) - Number.parseInt(b, 10) || a.localeCompare(b);
  };

  const replaceOptions = (select, items, preferred) => {
    select.replaceChildren();
    for (const item of items) {
      const option = new Option(item.label ?? item.value, item.value);
      option.disabled = Boolean(item.disabled);
      select.add(option);
    }
    if (items.some(item => String(item.value) === String(preferred) && !item.disabled)) {
      select.value = preferred;
    } else {
      const first = items.find(item => !item.disabled);
      if (first) select.value = first.value;
    }
  };

  const groupKey = (area, age, dose) => `${area}\u0000${age}\u0000${dose}`;

  const rebuildControls = previous => {
    const area = document.getElementById('area');
    const age = document.getElementById('age');
    const c1 = document.getElementById('c1');
    const c2 = document.getElementById('c2');
    const areas = [...currentData.areas.values()]
      .sort((a, b) => a.areacode.localeCompare(b.areacode))
      .map(item => ({value: item.areacode, label: config.language === 'ja' ? item.areaj : item.area}));
    areas.push({value: 'jp271004', label: text.osaka_disabled, disabled: true});
    areas.sort((a, b) => a.value.localeCompare(b.value));
    replaceOptions(area, areas, previous.area || 'cze');

    const rebuildAgeAndDose = (preferredAge, preferredC1, preferredC2) => {
      const ages = [...new Set([...currentData.fits.values()]
        .filter(fit => fit.areacode === area.value)
        .map(fit => fit.age))].sort(compareAges);
      replaceOptions(age, ages.map(value => ({value, label: value})), preferredAge || 'all');
      const doses = [...new Set([...currentData.fits.values()]
        .filter(fit => fit.areacode === area.value && fit.age === age.value)
        .map(fit => fit.dose))].sort((a, b) => a - b);
      const doseItems = doses.map(value => ({value, label: String(value)}));
      replaceOptions(c1, doseItems, preferredC1 ?? 0);
      replaceOptions(c2, doseItems, preferredC2 ?? 1);
      if (c1.value === c2.value && doseItems.length > 1) c2.value = doseItems[1].value;
    };

    rebuildAgeAndDose(previous.age, previous.c1, previous.c2);
    area.onchange = () => { rebuildAgeAndDose('all', 0, 1); render(); };
    age.onchange = () => { rebuildAgeAndDose(age.value, c1.value, c2.value); render(); };
    c1.onchange = render;
    c2.onchange = render;
  };

  const loadCutoff = async cutoff => {
    const previous = {
      area: document.getElementById('area').value,
      age: document.getElementById('age').value,
      c1: document.getElementById('c1').value,
      c2: document.getElementById('c2').value
    };
    status(text.loading);
    try {
      if (!cache.has(cutoff)) {
        cache.set(cutoff, Promise.all([
          fetchJson({
            size: 1000000,
            _source: ['areacode', 'area', 'areaj', 'date', 'age', 'dose', 'at_risk', 'deaths_week'],
            query: {bool: {filter: [{term: {series: 'cumd_wk_g'}}, {term: {cutoff}}]}},
            sort: [{date: 'asc'}, {id: 'asc'}]
          }),
          fetchJson({
            size: 10000,
            _source: ['areacode', 'area', 'areaj', 'age', 'dose', 'theta', 'k', 'rmse', 'fit_status', 'quiet_start', 'quiet_end', 'points'],
            query: {bool: {filter: [{term: {series: 'gamma_params'}}, {term: {cutoff}}]}},
            sort: [{areacode: 'asc'}, {age: 'asc'}, {dose: 'asc'}]
          })
        ]).then(([seriesResult, fitResult]) => {
          const groups = new Map();
          const areas = new Map();
          for (const hit of seriesResult.hits.hits) {
            const row = hit._source;
            row.dose = Number(row.dose);
            row.at_risk = Number(row.at_risk);
            row.deaths_week = Number(row.deaths_week);
            const key = groupKey(row.areacode, row.age, row.dose);
            if (!groups.has(key)) groups.set(key, []);
            groups.get(key).push(row);
            areas.set(row.areacode, row);
          }
          const fits = new Map();
          for (const hit of fitResult.hits.hits) {
            const fit = hit._source;
            fit.dose = Number(fit.dose);
            fit.theta = Number(fit.theta);
            fit.k = Number(fit.k);
            fit.rmse = Number(fit.rmse);
            fit.points = Number(fit.points);
            fits.set(groupKey(fit.areacode, fit.age, fit.dose), fit);
          }
          return {groups, fits, areas};
        }));
      }
      currentData = await cache.get(cutoff);
      rebuildControls(previous);
      document.getElementById('kcor-controls').hidden = false;
      status('');
      render();
    } catch (error) {
      console.error(error);
      status(text.load_error);
    }
  };

  const adjustedSeries = (rows, fit) => {
    let observed = 0;
    return rows.map(row => {
      if (row.at_risk <= 0 || row.deaths_week < 0 || row.deaths_week >= row.at_risk) return null;
      observed += -Math.log1p(-row.deaths_week / row.at_risk);
      const adjusted = Math.abs(fit.theta) < 1.0e-12
        ? observed
        : Math.expm1(fit.theta * observed) / fit.theta;
      return {date: row.date, observed, adjusted};
    }).filter(Boolean);
  };

  const updateFitLabel = (id, fit) => {
    document.getElementById(id).textContent = fit
      ? `${text.theta}=${fit.theta.toPrecision(5)} / ${text.fit}=${fit.fit_status}`
      : text.no_fit;
  };

  const prepareWide = () => {
    const area = document.getElementById('area').value;
    const age = document.getElementById('age').value;
    const dose1 = Number(document.getElementById('c1').value);
    const dose2 = Number(document.getElementById('c2').value);
    const key1 = groupKey(area, age, dose1);
    const key2 = groupKey(area, age, dose2);
    const fit1 = currentData.fits.get(key1);
    const fit2 = currentData.fits.get(key2);
    updateFitLabel('c1fit', fit1);
    updateFitLabel('c2fit', fit2);
    if (!fit1 || !fit2) {
      status(text.no_fit);
      return [];
    }
    status('');
    const series1 = adjustedSeries(currentData.groups.get(key1) || [], fit1);
    const series2 = adjustedSeries(currentData.groups.get(key2) || [], fit2);
    const map1 = new Map(series1.map(row => [row.date, row]));
    const map2 = new Map(series2.map(row => [row.date, row]));
    const dates = [...new Set([...map1.keys(), ...map2.keys()])].sort();
    return dates.map(date => ({
      date,
      observed1: map1.get(date)?.observed ?? null,
      adjusted1: map1.get(date)?.adjusted ?? null,
      observed2: map2.get(date)?.observed ?? null,
      adjusted2: map2.get(date)?.adjusted ?? null
    }));
  };

  async function render() {
    if (!currentData) return;
    const wide = prepareWide();
    if (!wide.length) {
      document.getElementById('view').replaceChildren();
      return;
    }
    const viewWidth = document.getElementById('view').clientWidth || 1020;
    lastViewWidth = viewWidth;
    const chartWidth = Math.min(820, Math.max(180, viewWidth - 180));
    const commonX = {field: 'date', type: 'temporal', title: text.date, axis: {format: '%Y-%m', tickCount: {interval: 'month', step: 1}}};
    const line = (field, color, dash, title) => ({
      mark: {type: 'line', stroke: color, strokeWidth: dash ? 1.5 : 2.5, strokeDash: dash || undefined, opacity: dash ? 0.55 : 1},
      encoding: {
        x: commonX,
        y: {field, type: 'quantitative', title: text.cumulative_hazard, scale: {zero: true}},
        tooltip: [
          {field: 'date', type: 'temporal', title: text.date, format: '%Y-%m-%d'},
          {field, type: 'quantitative', title, format: '.6f'}
        ]
      }
    });
    const spec = {
      $schema: 'https://vega.github.io/schema/vega-lite/v5.json',
      config: {title: {fontSize: 16}, axis: {titleFontSize: 15, labelFontSize: 15}},
      vconcat: [
        {
          width: chartWidth, height: 230, data: {values: wide},
          layer: [
            line('observed1', 'blue', [5, 4], `${text.cohort1} ${text.observed}`),
            line('adjusted1', 'blue', null, `${text.cohort1} ${text.adjusted}`),
            line('observed2', 'red', [5, 4], `${text.cohort2} ${text.observed}`),
            line('adjusted2', 'red', null, `${text.cohort2} ${text.adjusted}`)
          ]
        },
        {
          width: chartWidth, height: 160, data: {values: wide},
          transform: [
            {calculate: 'datum.adjusted1 > 0 ? datum.adjusted2 / datum.adjusted1 : null', as: 'KCOR_G'}
          ],
          layer: [
            {
              mark: {type: 'line', stroke: '#111', strokeWidth: 2},
              encoding: {
                x: commonX,
                y: {field: 'KCOR_G', type: 'quantitative', title: text.ratio, scale: {zero: true}},
                tooltip: [
                  {field: 'date', type: 'temporal', title: text.date, format: '%Y-%m-%d'},
                  {field: 'KCOR_G', type: 'quantitative', title: 'KCOR-G', format: '.4f'}
                ]
              }
            },
            {mark: {type: 'rule', stroke: 'red', strokeWidth: 2}, encoding: {y: {datum: 1}}}
          ]
        }
      ]
    };
    try {
      await vegaEmbed('#view', spec, {actions: false});
    } catch (error) {
      console.error(error);
      status(text.load_error);
    }
  }

  const start = async () => {
    try {
      const metadata = await fetchJson({
        size: 0,
        query: {term: {series: 'gamma_params'}},
        aggs: {cutoffs: {terms: {field: 'cutoff', size: 100, order: {_key: 'asc'}}}}
      });
      const cutoffs = metadata.aggregations.cutoffs.buckets.map(bucket => bucket.key_as_string);
      const cutoff = document.createElement('select');
      cutoff.className = 'cutoff';
      for (const value of cutoffs) cutoff.add(new Option(value, value, false, value === '2021-09-05'));
      cutoff.onchange = () => loadCutoff(cutoff.value);
      document.getElementById('cutoff').append(cutoff);
      await loadCutoff(cutoff.value || cutoffs[0]);
      new ResizeObserver(entries => {
        const width = entries[0].contentRect.width;
        if (!currentData || Math.abs(width - lastViewWidth) < 2) return;
        clearTimeout(resizeTimer);
        resizeTimer = setTimeout(render, 120);
      }).observe(document.getElementById('view'));
    } catch (error) {
      console.error(error);
      status(text.load_error);
    }
  };

  start();
})();
