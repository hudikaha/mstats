(() => {
  'use strict';

  const config = window.KCORG_CONFIG;
  const text = config.text;
  const cache = new Map();
  let currentData;
  let gammaMode = false;
  let currentView;
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
    const selected = items.find(item => String(item.value) === String(preferred) && !item.disabled)
      || items.find(item => !item.disabled);
    if (selected) select.value = selected.value;
  };

  const groupKey = (area, age, dose) => `${area}\u0000${age}\u0000${dose}`;

  const selected = className => new Set(
    [...document.querySelectorAll(`input.${className}:checked`)].map(input => input.value)
  );

  const buildCheckboxes = (containerId, items, className, defaults) => {
    const container = document.getElementById(containerId);
    container.replaceChildren();
    for (const item of items) {
      const label = document.createElement('label');
      label.className = 'inline';
      const checkbox = document.createElement('input');
      checkbox.type = 'checkbox';
      checkbox.value = item.value;
      checkbox.className = className;
      checkbox.checked = defaults.has(String(item.value));
      checkbox.disabled = Boolean(item.disabled);
      label.append(checkbox, document.createTextNode(item.label));
      container.append(label);
    }
  };

  const selectedRows = () => {
    const areas = selected('area');
    const ages = selected('age');
    const dose1 = Number(document.getElementById('c1').value);
    const dose2 = Number(document.getElementById('c2').value);
    const aggregate = dose => {
      const groups = [];
      for (const area of areas) {
        for (const age of ages) {
          const rows = currentData.groups.get(groupKey(area, age, dose));
          if (rows?.length) groups.push(rows);
        }
      }
      if (!groups.length) return [];
      const firstDate = groups.map(rows => rows[0].date).sort().at(-1);
      const lastDate = groups.map(rows => rows.at(-1).date).sort()[0];
      const totals = new Map();
      for (const rows of groups) {
        for (const row of rows) {
          if (row.date < firstDate || row.date > lastDate) continue;
          if (!totals.has(row.date)) totals.set(row.date, {date: row.date, at_risk: 0, deaths_week: 0});
          const total = totals.get(row.date);
          total.at_risk += row.at_risk;
          total.deaths_week += row.deaths_week;
        }
      }
      return [...totals.values()].sort((a, b) => a.date.localeCompare(b.date));
    };
    return [aggregate(dose1), aggregate(dose2)];
  };

  const resetGamma = () => {
    gammaMode = false;
    document.getElementById('gamma-toggle').textContent = text.gamma_apply;
    document.getElementById('gamma-factor').textContent = '';
  };

  const configureQuietSlider = () => {
    const [rows1, rows2] = selectedRows();
    const maximum = Math.min(rows1.length, rows2.length);
    const slider = document.getElementById('quiet-end');
    slider.max = maximum;
    slider.value = 0;
  };

  const rebuildControls = previous => {
    const c1 = document.getElementById('c1');
    const c2 = document.getElementById('c2');
    const areas = [...currentData.areas.values()]
      .sort((a, b) => a.areacode.localeCompare(b.areacode))
      .map(item => ({value: item.areacode, label: config.language === 'ja' ? item.areaj : item.area}));
    areas.push({value: 'jp271004', label: text.osaka_disabled, disabled: true});
    areas.sort((a, b) => a.value.localeCompare(b.value));
    const ages = [...new Set([...currentData.groups.values()].map(rows => rows[0].age))].sort(compareAges);
    const areaDefaults = previous.areas?.size ? previous.areas : new Set(areas.filter(item => !item.disabled).map(item => item.value));
    const ageDefaults = previous.ages?.size ? previous.ages : new Set(ages.includes('all') ? ['all'] : ages);
    buildCheckboxes('area', areas, 'area', areaDefaults);
    buildCheckboxes('age', ages.map(value => ({value, label: value})), 'age', ageDefaults);
    const doses = [...new Set([...currentData.groups.values()].map(rows => rows[0].dose))].sort((a, b) => a - b);
    const doseItems = doses.map(value => ({value, label: String(value)}));
    replaceOptions(c1, doseItems, previous.c1 ?? 0);
    replaceOptions(c2, doseItems, previous.c2 ?? 1);
    if (c1.value === c2.value && doseItems.length > 1) c2.value = doseItems[1].value;

    const resetAndRender = () => { resetGamma(); configureQuietSlider(); updateQuietLabel(); render(); };
    document.querySelectorAll('input.area, input.age').forEach(element => {
      element.oninput = () => {
        if (element.classList.contains('age') && element.value === 'all' && element.checked) {
          document.querySelectorAll('input.age').forEach(input => { if (input !== element) input.checked = false; });
        } else if (element.classList.contains('age') && element.checked) {
          const all = document.querySelector('input.age[value="all"]');
          if (all) all.checked = false;
        }
        resetAndRender();
      };
    });
    configureQuietSlider();
    updateQuietLabel();
    c1.onchange = resetAndRender;
    c2.onchange = resetAndRender;
  };

  const loadCutoff = async cutoff => {
    const previous = {
      areas: currentData ? selected('area') : new Set(),
      ages: currentData ? selected('age') : new Set(),
      c1: document.getElementById('c1').value,
      c2: document.getElementById('c2').value
    };
    status(text.loading);
    try {
      if (!cache.has(cutoff)) {
        cache.set(cutoff, fetchJson({
          size: 1000000,
          _source: ['areacode', 'area', 'areaj', 'date', 'age', 'dose', 'at_risk', 'deaths_week'],
          query: {bool: {filter: [{term: {series: 'cumd_wk_g'}}, {term: {cutoff}}]}},
          sort: [{date: 'asc'}, {id: 'asc'}]
        }).then(result => {
          const groups = new Map();
          const areas = new Map();
          for (const hit of result.hits.hits) {
            const row = hit._source;
            row.dose = Number(row.dose);
            row.at_risk = Number(row.at_risk);
            row.deaths_week = Number(row.deaths_week);
            const key = groupKey(row.areacode, row.age, row.dose);
            if (!groups.has(key)) groups.set(key, []);
            groups.get(key).push(row);
            areas.set(row.areacode, row);
          }
          return {groups, areas};
        }));
      }
      currentData = await cache.get(cutoff);
      resetGamma();
      rebuildControls(previous);
      document.getElementById('kcor-controls').hidden = false;
      document.getElementById('quiet-row').hidden = false;
      status('');
      render();
    } catch (error) {
      console.error(error);
      status(text.load_error);
    }
  };

  const observedSeries = rows => {
    let observed = 0;
    return rows.map((row, index) => {
      if (row.at_risk <= 0 || row.deaths_week < 0 || row.deaths_week >= row.at_risk) return null;
      observed += -Math.log1p(-row.deaths_week / row.at_risk);
      return {date: row.date, time: index + 1, observed};
    }).filter(Boolean);
  };

  const modelHazard = (time, theta, k) => Math.abs(theta) < 1.0e-12
    ? k * time
    : Math.log1p(theta * k * time) / theta;

  const profiledK = (points, theta) => {
    let numerator = 0;
    let denominator = 0;
    for (const point of points) {
      const neutralized = Math.abs(theta) < 1.0e-12
        ? point.observed
        : Math.expm1(theta * point.observed) / theta;
      numerator += point.time * neutralized;
      denominator += point.time * point.time;
    }
    return numerator / denominator;
  };

  const profileError = (points, theta) => {
    const k = profiledK(points, theta);
    const error = points.reduce((sum, point) => {
      const difference = point.observed - modelHazard(point.time, theta, k);
      return sum + difference * difference;
    }, 0);
    return {k, error};
  };

  const goldenMin = (left, right, callback, iterations = 48) => {
    const ratio = (Math.sqrt(5) - 1) / 2;
    let x1 = right - ratio * (right - left);
    let x2 = left + ratio * (right - left);
    let y1 = callback(x1);
    let y2 = callback(x2);
    for (let index = 0; index < iterations; index += 1) {
      if (y1 <= y2) {
        right = x2; x2 = x1; y2 = y1;
        x1 = right - ratio * (right - left); y1 = callback(x1);
      } else {
        left = x1; x1 = x2; y1 = y2;
        x2 = left + ratio * (right - left); y2 = callback(x2);
      }
    }
    return y1 <= y2 ? x1 : x2;
  };

  // 日本語: cutoffから選択終了週までの累積hazardへ単純Gamma modelをfitする。
  // English: Fit the simple gamma model to cumulative hazards from cutoff through the selected end week.
  const fitGamma = (series, endWeeks) => {
    const points = series.filter(point => point.time <= endWeeks);
    if (points.length < 12 || points.at(-1).observed <= points[0].observed) return null;
    const thetaMax = 100;
    const grid = Array.from({length: 51}, (_, index) => {
      const theta = thetaMax * index / 50;
      return {theta, ...profileError(points, theta)};
    });
    const best = grid.reduce((a, b) => a.error <= b.error ? a : b);
    const bestIndex = grid.indexOf(best);
    const left = grid[Math.max(0, bestIndex - 1)].theta;
    const right = grid[Math.min(grid.length - 1, bestIndex + 1)].theta;
    const theta = left === right ? best.theta : goldenMin(left, right, value => profileError(points, value).error);
    const {k, error} = profileError(points, theta);
    const fitStatus = theta <= thetaMax * 1.0e-6 ? 'theta_zero'
      : theta >= thetaMax * (1 - 1.0e-6) ? 'theta_upper_bound' : 'ok';
    return {theta, k, rmse: Math.sqrt(error / points.length), points: points.length, fitStatus};
  };

  const adjustedSeries = (series, fit) => series.map(row => ({
    ...row,
    adjusted: Math.abs(fit.theta) < 1.0e-12
      ? row.observed
      : Math.expm1(fit.theta * row.observed) / fit.theta
  }));

  const fitLabel = fit => fit
    ? `${text.theta}=${fit.theta.toPrecision(5)} / k=${fit.k.toPrecision(5)} / RMSE=${fit.rmse.toPrecision(3)} / n=${fit.points} / ${fit.fitStatus}`
    : text.no_fit;

  const prepareWide = () => {
    const [rows1, rows2] = selectedRows();
    let series1 = observedSeries(rows1);
    let series2 = observedSeries(rows2);
    let fit1 = null;
    let fit2 = null;
    let factor = 1;
    if (gammaMode) {
      const endWeeks = Number(document.getElementById('quiet-end').value);
      fit1 = fitGamma(series1, endWeeks);
      fit2 = fitGamma(series2, endWeeks);
      document.getElementById('c1fit').textContent = fitLabel(fit1);
      document.getElementById('c2fit').textContent = fitLabel(fit2);
      if (fit1 && fit2 && fit1.k > 0 && fit2.k > 0) {
        factor = fit2.k / fit1.k;
        series1 = adjustedSeries(series1, fit1);
        series2 = adjustedSeries(series2, fit2);
      } else {
        factor = null;
      }
    } else {
      document.getElementById('c1fit').textContent = '';
      document.getElementById('c2fit').textContent = '';
    }
    const map1 = new Map(series1.map(row => [row.date, row]));
    const map2 = new Map(series2.map(row => [row.date, row]));
    const dates = [...new Set([...map1.keys(), ...map2.keys()])].sort();
    return {factor, wide: dates.map(date => ({
      date,
      observed1: map1.get(date)?.observed ?? null,
      observed2: map2.get(date)?.observed ?? null,
      adjusted1: map1.get(date)?.adjusted ?? null,
      adjusted2: map2.get(date)?.adjusted ?? null
    }))};
  };

  async function render() {
    if (!currentData) return;
    const {wide, factor} = prepareWide();
    if (!wide.length) {
      document.getElementById('view').replaceChildren();
      status(text.no_fit);
      return;
    }
    status('');
    document.getElementById('gamma-factor').textContent = gammaMode && factor
      ? text.gamma_factor.replace('%{factor}', factor.toFixed(4)) : '';
    const adjustedMode = gammaMode && factor;
    const displayFactor = adjustedMode ? factor : 1;
    const viewWidth = document.getElementById('view').clientWidth || 1020;
    lastViewWidth = viewWidth;
    const chartWidth = Math.min(820, Math.max(180, viewWidth - 180));
    document.getElementById('quiet-row').style.width = `${chartWidth}px`;
    const commonX = {field: 'date', type: 'temporal', title: text.date, axis: {format: '%Y-%m', tickCount: {interval: 'month', step: 1}}};
    const line = (field, color, width, opacity, title, scale = 1) => ({
      transform: scale === 1 ? [] : [{calculate: `datum.${field} * ${scale}`, as: `${field}_display`}],
      mark: {type: 'line', stroke: color, strokeWidth: width, opacity},
      encoding: {
        x: commonX,
        y: {field: scale === 1 ? field : `${field}_display`, type: 'quantitative', title: text.cumulative_hazard, scale: {zero: true}},
        tooltip: [
          {field: 'date', type: 'temporal', title: text.date, format: '%Y-%m-%d'},
          {field: scale === 1 ? field : `${field}_display`, type: 'quantitative', title, format: '.6f'}
        ]
      }
    });
    const topLayers = adjustedMode
      ? [
          line('observed1', 'blue', 1.2, 0.4, `${text.cohort1} ${text.observed}`),
          line('observed2', 'red', 1.2, 0.4, `${text.cohort2} ${text.observed}`),
          line('adjusted1', 'blue', 3.2, 1, `${text.cohort1} ${text.adjusted}`, factor),
          line('adjusted2', 'red', 3.2, 1, `${text.cohort2} ${text.adjusted}`)
        ]
      : [
          line('observed1', 'blue', 2.4, 1, `${text.cohort1} ${text.observed}`),
          line('observed2', 'red', 2.4, 1, `${text.cohort2} ${text.observed}`)
        ];
    const numerator = adjustedMode ? 'datum.adjusted2' : 'datum.observed2';
    const denominator = adjustedMode ? 'datum.adjusted1' : 'datum.observed1';
    const quietDate = document.getElementById('quiet-end-value').textContent;
    topLayers.push({
      data: {name: 'quietMarker', values: [{date: quietDate}]},
      mark: {type: 'rule', stroke: '#087f5b', strokeWidth: 3},
      encoding: {
        x: {field: 'date', type: 'temporal'},
        tooltip: [{field: 'date', type: 'temporal', title: text.quiet_end, format: '%Y-%m-%d'}]
      }
    });
    const spec = {
      $schema: 'https://vega.github.io/schema/vega-lite/v5.json',
      config: {title: {fontSize: 16}, axis: {titleFontSize: 15, labelFontSize: 15}},
      vconcat: [
        {width: chartWidth, height: 230, data: {values: wide}, layer: topLayers},
        {
          width: chartWidth, height: 160, data: {values: wide},
          transform: [{calculate: `${denominator} > 0 ? ${numerator} / (${denominator} * ${displayFactor}) : null`, as: 'KCOR_G'}],
          layer: [
            {
              mark: {type: 'line', stroke: '#111', strokeWidth: 2},
              encoding: {
                x: commonX,
                y: {field: 'KCOR_G', type: 'quantitative', title: text.ratio, scale: {zero: true}},
                tooltip: [
                  {field: 'date', type: 'temporal', title: text.date, format: '%Y-%m-%d'},
                  {field: 'KCOR_G', type: 'quantitative', title: adjustedMode ? 'KCOR-G' : 'KCOR', format: '.4f'}
                ]
              }
            },
            {mark: {type: 'rule', stroke: 'red', strokeWidth: 2}, encoding: {y: {datum: 1}}}
          ]
        }
      ]
    };
    try {
      const result = await vegaEmbed('#view', spec, {actions: false});
      currentView = result.view;
    } catch (error) {
      console.error(error);
      status(text.load_error);
    }
  }

  const updateQuietLabel = () => {
    const [rows] = selectedRows();
    const weeks = Number(document.getElementById('quiet-end').value);
    const cutoff = document.querySelector('#cutoff select')?.value || '';
    document.getElementById('quiet-end-value').textContent = weeks === 0 ? cutoff : (rows[weeks - 1]?.date || cutoff);
  };

  const moveQuietMarker = () => {
    if (!currentView || typeof vega === 'undefined') return;
    const date = document.getElementById('quiet-end-value').textContent;
    if (!date) return;
    const changes = vega.changeset().remove(() => true).insert([{date}]);
    currentView.change('quietMarker', changes).runAsync();
  };

  const start = async () => {
    try {
      const quietEnd = document.getElementById('quiet-end');
      quietEnd.oninput = () => {
        updateQuietLabel();
        moveQuietMarker();
        if (gammaMode && Number(quietEnd.value) >= 12) {
          document.getElementById('gamma-factor').textContent = text.fitting;
        }
        clearTimeout(resizeTimer);
        if (gammaMode) resizeTimer = setTimeout(render, 80);
      };
      quietEnd.onchange = quietEnd.oninput;
      document.getElementById('gamma-toggle').onclick = () => {
        gammaMode = !gammaMode;
        document.getElementById('gamma-toggle').textContent = gammaMode ? text.gamma_remove : text.gamma_apply;
        render();
      };
      const metadata = await fetchJson({
        size: 0,
        query: {term: {series: 'cumd_wk_g'}},
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
