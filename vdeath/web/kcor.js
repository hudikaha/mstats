(() => {
  'use strict';

  const config = window.KCOR_CONFIG;
  const text = config.text;
  const cache = new Map();
  let manifest;
  let currentData;
  let renderSerial = 0;
  let lastViewWidth = 0;
  let resizeTimer;

  const status = message => {
    const element = document.getElementById('kcor-status');
    element.textContent = message || '';
    element.hidden = !message;
  };

  const fetchJson = async (url, body) => {
    const response = await fetch(url, body ? {
      method: 'POST', cache: 'no-cache', headers: {'Content-Type': 'application/json'},
      body: JSON.stringify(body)
    } : {cache: 'no-cache'});
    if (!response.ok) throw new Error(`${response.status} ${response.statusText}: ${url}`);
    return response.json();
  };

  const buildCheckboxes = (containerId, items, className, defaults) => {
    const container = document.getElementById(containerId);
    container.replaceChildren();
    for (const item of items) {
      const value = typeof item === 'object' ? item.value : item;
      const labelText = typeof item === 'object' ? item.label : item;
      const label = document.createElement('label');
      label.className = 'inline';
      const checkbox = document.createElement('input');
      checkbox.type = 'checkbox';
      checkbox.value = value;
      checkbox.className = className;
      checkbox.checked = defaults.has(String(value));
      label.append(checkbox, document.createTextNode(String(labelText)));
      container.append(label);
    }
  };

  const selected = className => new Set(
    [...document.querySelectorAll(`input.${className}:checked`)].map(input => input.value)
  );

  const rebuildSliceControls = (data, previous = {}) => {
    const areaItems = data.areas.map(area => ({
      value: area[0],
      label: config.language === 'ja' ? area[2] : area[1]
    }));
    const areaDefaults = previous.areas?.size ? previous.areas : new Set(areaItems.map(item => item.value));
    const ageDefaults = previous.ages?.size ? previous.ages : new Set(data.ages);
    buildCheckboxes('area', areaItems, 'area', areaDefaults);
    buildCheckboxes('age', data.ages, 'age', ageDefaults);
    document.querySelectorAll('input.area, input.age').forEach(element => element.addEventListener('input', render));
  };

  const loadCutoff = async cutoff => {
    const previous = currentData ? {areas: selected('area'), ages: selected('age')} : {};
    status(text.loading);
    try {
      if (!cache.has(cutoff)) {
        cache.set(cutoff, fetchJson(config.elasticsearch_url, {
          size: 1000000,
          _source: ['areacode', 'area', 'areaj', 'date', 'age', 'dose', 'deaths'],
          query: {term: {cutoff}},
          sort: [{date: 'asc'}, {id: 'asc'}]
        }).then(result => {
          const records = result.hits.hits.map(hit => hit._source);
          const areaMap = new Map();
          records.forEach(row => areaMap.set(row.areacode, [row.areacode, row.area, row.areaj]));
          const areas = [...areaMap.values()].sort((a, b) => a[0].localeCompare(b[0]));
          const dates = [...new Set(records.map(row => row.date))].sort();
          const ages = [...new Set(records.map(row => row.age))].sort();
          const areaIndex = new Map(areas.map((area, index) => [area[0], index]));
          const dateIndex = new Map(dates.map((date, index) => [date, index]));
          const ageIndex = new Map(ages.map((age, index) => [age, index]));
          return {
            areas, dates, ages,
            rows: records.map(row => [areaIndex.get(row.areacode), dateIndex.get(row.date), ageIndex.get(row.age), row.dose, row.deaths])
          };
        }));
      }
      currentData = await cache.get(cutoff);
      rebuildSliceControls(currentData, previous);
      document.getElementById('kcor-controls').hidden = false;
      status('');
      render();
    } catch (error) {
      console.error(error);
      status(text.load_error);
    }
  };

  const prepareWide = () => {
    const areaSet = selected('area');
    const ageSet = selected('age');
    const cohort1 = new Set([...selected('c1')].map(Number));
    const cohort2 = new Set([...selected('c2')].map(Number));
    if (!areaSet.size) {
      status(text.no_area);
      return [];
    }
    status('');

    const areaIndexes = new Set(currentData.areas
      .map((area, index) => areaSet.has(area[0]) ? index : -1)
      .filter(index => index >= 0));
    const ageIndexes = new Set(currentData.ages
      .map((age, index) => ageSet.has(age) ? index : -1)
      .filter(index => index >= 0));
    const availability = new Map();
    for (const row of currentData.rows) {
      const dateIndex = row[1];
      if (!availability.has(dateIndex)) availability.set(dateIndex, new Set());
      availability.get(dateIndex).add(row[0]);
    }

    const validDates = new Set();
    for (const [dateIndex, areas] of availability) {
      const date = currentData.dates[dateIndex];
      if (date <= manifest.anchor_date || [...areaIndexes].every(area => areas.has(area))) validDates.add(dateIndex);
    }

    const byDate = new Map([...validDates].map(dateIndex => [dateIndex, {cohort1: 0, cohort2: 0}]));
    for (const row of currentData.rows) {
      const [areaIndex, dateIndex, ageIndex, dose, deaths] = row;
      if (!validDates.has(dateIndex) || !areaIndexes.has(areaIndex) || !ageIndexes.has(ageIndex)) continue;
      const totals = byDate.get(dateIndex);
      if (cohort1.has(dose)) totals.cohort1 += deaths;
      if (cohort2.has(dose)) totals.cohort2 += deaths;
    }
    return [...byDate.entries()]
      .sort((a, b) => a[0] - b[0])
      .map(([dateIndex, totals]) => ({date: currentData.dates[dateIndex], ...totals}));
  };

  const updateDbLabel = () => {
    const input = document.querySelector('#s2 input[type="range"]');
    if (!input) return;
    const update = () => {
      const db = Number(input.value);
      document.getElementById('s2val').textContent = `×${Math.pow(10, db / 10).toFixed(2)} (dB=${db.toFixed(1)})`;
    };
    input.oninput = update;
    update();
  };

  const render = async () => {
    if (!currentData) return;
    const serial = ++renderSerial;
    const wide = prepareWide();
    const currentDb = Number(document.querySelector('#s2 input[type="range"]')?.value || 0);
    const viewWidth = document.getElementById('view').clientWidth || 1020;
    lastViewWidth = viewWidth;
    const chartWidth = Math.min(820, Math.max(180, viewWidth - 180));
    const spec = {
      $schema: 'https://vega.github.io/schema/vega-lite/v5.json',
      config: {
        title: {fontSize: 16},
        axis: {titleFontSize: 15, labelFontSize: 15},
        legend: {titleFontSize: 15, labelFontSize: 15}
      },
      params: [{
        name: 'slope_dB', value: Number.isNaN(currentDb) ? 0 : currentDb,
        bind: {input: 'range', min: -20, max: 20, step: 0.1, element: '#s2'}
      }],
      vconcat: [
        {
          width: chartWidth, height: 200, data: {values: wide},
          layer: [
            {
              transform: [
                {calculate: 'pow(10, slope_dB/10)', as: 'db_factor'},
                {calculate: 'datum.cohort1 * datum.db_factor', as: 'c1_scaled'}
              ],
              mark: {type: 'line', stroke: 'blue', strokeWidth: 2},
              encoding: {
                x: {field: 'date', type: 'temporal', title: text.date, axis: {format: '%Y-%m', tickCount: {interval: 'month', step: 1}}},
                y: {field: 'c1_scaled', type: 'quantitative', title: text.cumulative_deaths, scale: {zero: true}}
              }
            },
            {
              mark: {type: 'line', stroke: 'red', strokeWidth: 2},
              encoding: {
                x: {field: 'date', type: 'temporal', title: text.date, axis: {format: '%Y-%m', tickCount: {interval: 'month', step: 1}}},
                y: {field: 'cohort2', type: 'quantitative', title: text.cumulative_deaths, scale: {zero: true}}
              }
            },
            {
              transform: [
                {calculate: 'pow(10, slope_dB/10)', as: 'db_factor'},
                {calculate: 'max(datum.cohort2, datum.cohort1 * datum.db_factor) * 1.1', as: 'y_up'},
                {aggregate: [{op: 'max', field: 'y_up', as: 'ymax'}]}
              ],
              mark: {type: 'rule', opacity: 0.0001},
              encoding: {y: {field: 'ymax', type: 'quantitative', scale: {zero: true}}}
            },
            {
              mark: {type: 'point', strokeWidth: 24, opacity: 0},
              params: [{name: 'hoverTop', select: {type: 'point', encodings: ['x'], nearest: true, on: 'mousemove, touchstart, touchmove', clear: 'mouseout, touchend', empty: 'none'}}],
              encoding: {x: {field: 'date', type: 'temporal'}}
            },
            {
              transform: [
                {filter: {param: 'hoverTop', empty: false}},
                {calculate: 'pow(10, slope_dB/10)', as: 'db_factor'},
                {calculate: 'datum.cohort1 * datum.db_factor', as: 'c1_scaled'},
                {calculate: 'datum.c1_scaled > 0 ? datum.cohort2 / datum.c1_scaled : null', as: 'RR'},
                {calculate: "format(datum.c1_scaled, ',.0f') + ' (' + format(datum.cohort1, ',.0f') + '×' + format(datum.db_factor, '.2f') + ')'", as: 'c1_show'}
              ],
              mark: {type: 'rule', strokeWidth: 8, opacity: 0.1},
              encoding: {
                x: {field: 'date', type: 'temporal'},
                tooltip: [
                  {field: 'date', type: 'temporal', title: text.date, format: '%Y-%m-%d'},
                  {field: 'cohort2', type: 'quantitative', title: text.cohort2, format: ',.0f'},
                  {field: 'c1_show', type: 'nominal', title: text.cohort1},
                  {field: 'RR', type: 'quantitative', title: 'RR', format: ',.3f'}
                ]
              }
            }
          ]
        },
        {
          width: chartWidth, height: 150,
          layer: [
            {
              data: {values: wide},
              transform: [
                {calculate: 'pow(10, slope_dB/10)', as: 'db_factor'},
                {calculate: 'datum.cohort1 * datum.db_factor', as: 'c1_scaled'},
                {calculate: 'datum.c1_scaled > 0 ? datum.cohort2 / datum.c1_scaled : null', as: 'RR'}
              ],
              mark: {type: 'line', stroke: '#111', strokeWidth: 2},
              encoding: {
                x: {field: 'date', type: 'temporal', title: text.date, axis: {format: '%Y-%m', tickCount: {interval: 'month', step: 1}}},
                y: {field: 'RR', type: 'quantitative', title: text.ratio, scale: {zero: true}}
              }
            },
            {mark: {type: 'rule', stroke: 'red', strokeWidth: 2, opacity: 0.9}, encoding: {y: {datum: 1}}},
            {
              data: {values: wide},
              transform: [
                {calculate: 'pow(10, slope_dB/10)', as: 'db_factor'},
                {calculate: 'datum.cohort1 * datum.db_factor', as: 'c1_scaled'},
                {calculate: 'datum.c1_scaled > 0 ? datum.cohort2 / datum.c1_scaled : null', as: 'RR'},
                {calculate: 'datum.RR != null ? datum.RR * 1.1 : 0', as: 'rr_up'},
                {aggregate: [{op: 'max', field: 'rr_up', as: 'rrmax'}]}
              ],
              mark: {type: 'rule', opacity: 0.0001},
              encoding: {y: {field: 'rrmax', type: 'quantitative', scale: {zero: true}}}
            }
          ]
        }
      ]
    };
    try {
      await vegaEmbed('#view', spec, {actions: false});
      if (serial === renderSerial) updateDbLabel();
    } catch (error) {
      console.error(error);
    }
  };

  const start = async () => {
    try {
      const metadata = await fetchJson(config.elasticsearch_url, {
        size: 0,
        aggs: {cutoffs: {terms: {field: 'cutoff', size: 100, order: {_key: 'asc'}}}}
      });
      manifest = {
        anchor_date: '2024-03-03',
        default_cutoff: '2021-09-05',
        cutoffs: metadata.aggregations.cutoffs.buckets.map(bucket => ({cutoff: bucket.key_as_string}))
      };
      const cutoff = document.createElement('select');
      cutoff.className = 'cutoff';
      for (const item of manifest.cutoffs) {
        const option = new Option(item.cutoff, item.cutoff, false, item.cutoff === manifest.default_cutoff);
        cutoff.add(option);
      }
      cutoff.addEventListener('change', () => loadCutoff(cutoff.value));
      document.getElementById('cutoff').append(cutoff);
      buildCheckboxes('c1', [0, 1, 2, 3, 4, 5, 6, 7], 'c1', new Set(['0']));
      buildCheckboxes('c2', [0, 1, 2, 3, 4, 5, 6, 7], 'c2', new Set(['1', '2']));
      document.querySelectorAll('input.c1, input.c2').forEach(element => element.addEventListener('input', render));
      await loadCutoff(cutoff.value || manifest.default_cutoff);
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
