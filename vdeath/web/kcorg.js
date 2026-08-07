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
  let quietDragging = false;
  let osakaCheckedBeforeGamma = false;

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
    const doses1 = new Set([...selected('c1')].map(Number));
    const doses2 = new Set([...selected('c2')].map(Number));
    const aggregate = doses => {
      const groups = [];
      for (const area of areas) {
        for (const age of ages) {
          for (const dose of doses) {
            const rows = currentData.groups.get(groupKey(area, age, dose));
            if (rows?.length) groups.push(rows);
          }
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
    return [aggregate(doses1), aggregate(doses2)];
  };

  const resetGamma = () => {
    gammaMode = false;
    const osaka = document.querySelector('input.area[value="jp271004"]');
    if (osaka) {
      osaka.disabled = false;
      if (osakaCheckedBeforeGamma) osaka.checked = true;
    }
    osakaCheckedBeforeGamma = false;
    document.getElementById('gamma-toggle').textContent = text.gamma_apply;
    document.getElementById('osaka-gamma-note').hidden = true;
    document.getElementById('gamma-window-controls').hidden = true;
    document.getElementById('gamma-factor').textContent = '—';
  };

  const configureSliders = () => {
    const [rows1, rows2] = selectedRows();
    const weeks = Math.min(rows1.length, rows2.length);
    const quietStart = document.getElementById('quiet-start');
    const quietEnd = document.getElementById('quiet-end');
    const fitEnd = document.getElementById('fit-end');
    for (const slider of [quietStart, quietEnd, fitEnd]) slider.max = weeks;
    quietStart.value = Math.min(4, weeks);
    quietEnd.value = Math.min(8, weeks);
    fitEnd.value = 0;
  };

  const rebuildControls = previous => {
    const compareAreas = (a, b) => Number(a.areacode === 'cze') - Number(b.areacode === 'cze') ||
      a.areacode.localeCompare(b.areacode);
    const areas = [...currentData.areas.values()]
      .sort(compareAreas)
      .map(item => ({value: item.areacode, label: config.language === 'ja' ? item.areaj : item.area}));
    areas.sort((a, b) => Number(a.value === 'cze') - Number(b.value === 'cze') || a.value.localeCompare(b.value));
    const ages = [...new Set([...currentData.groups.values()].map(rows => rows[0].age))].sort(compareAges);
    const areaDefaults = previous.areas?.size ? previous.areas : new Set(
      areas.filter(item => item.value !== 'cze').map(item => item.value)
    );
    const ageDefaults = previous.ages?.size ? previous.ages : new Set(ages.includes('all') ? ['all'] : ages);
    buildCheckboxes('area', areas, 'area', areaDefaults);
    buildCheckboxes('age', ages.map(value => ({value, label: value})), 'age', ageDefaults);
    const doses = [0, 1, 2, 3, 4, 5, 6, 7];
    const doseItems = doses.map(value => ({value, label: String(value)}));
    const c1Defaults = previous.c1?.size ? previous.c1 : new Set(['0']);
    const c2Defaults = previous.c2?.size ? previous.c2 : new Set(['1', '2']);
    buildCheckboxes('c1', doseItems, 'c1', c1Defaults);
    buildCheckboxes('c2', doseItems, 'c2', c2Defaults);

    const resetAndRender = () => { resetGamma(); configureSliders(); updateSliderLabels(); render(); };
    document.querySelectorAll('input.area, input.age, input.c1, input.c2').forEach(element => {
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
    configureSliders();
    updateSliderLabels();
  };

  const loadCutoff = async cutoff => {
    const previous = {
      areas: currentData ? selected('area') : new Set(),
      ages: currentData ? selected('age') : new Set(),
      c1: currentData ? selected('c1') : new Set(),
      c2: currentData ? selected('c2') : new Set()
    };
    status(text.loading);
    try {
      if (!cache.has(cutoff)) {
        cache.set(cutoff, fetchJson({
          size: 1000000,
          _source: ['areacode', 'area', 'areaj', 'date', 'age', 'dose', 'at_risk', 'deaths_week', 'deaths'],
          query: {bool: {filter: [{term: {cutoff}}, {exists: {field: 'date'}}]}},
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
          // 大阪のCUMD-WKはrisk人数を持たないため、累積死亡数から週死亡数だけを復元する。
          // Osaka CUMD-WK lacks risk counts, so recover weekly deaths from cumulative deaths only.
          for (const rows of groups.values()) {
            rows.sort((a, b) => a.date.localeCompare(b.date));
            if (rows.every(row => Number.isFinite(row.at_risk) && Number.isFinite(row.deaths_week))) continue;
            let previousDeaths = 0;
            for (const row of rows) {
              const deaths = Number(row.deaths) || 0;
              row.deaths_week = Math.max(0, deaths - previousDeaths);
              row.at_risk = 0;
              previousDeaths = deaths;
            }
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
    let deaths = 0;
    return rows.map((row, index) => {
      if (row.at_risk <= 0 || row.deaths_week < 0 || row.deaths_week >= row.at_risk) return null;
      deaths += row.deaths_week;
      observed += -Math.log1p(-row.deaths_week / row.at_risk);
      return {date: row.date, time: index + 1, deaths, observed, atRisk: row.at_risk};
    }).filter(Boolean);
  };

  const cumulativeDeathsSeries = rows => {
    let deaths = 0;
    return rows.map(row => {
      deaths += row.deaths_week;
      return {date: row.date, deaths};
    });
  };

  const dateForWeek = week => {
    const [rows] = selectedRows();
    const cutoff = document.querySelector('#cutoff select')?.value || '';
    return Number(week) === 0 ? cutoff : (rows[Number(week) - 1]?.date || cutoff);
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
  const fitGamma = (series, startWeek, endWeek) => {
    const points = series.filter(point => point.time >= startWeek && point.time <= endWeek);
    if (points.length < 4 || points.at(-1).observed <= points[0].observed) return null;
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
    adjusted: !fit || Math.abs(fit.theta) < 1.0e-12
      ? row.observed
      : Math.expm1(fit.theta * row.observed) / fit.theta
  }));

  const fitLabel = fit => fit
    ? `${text.theta}=${fit.theta.toPrecision(5)} / k=${fit.k.toPrecision(5)} / RMSE=${fit.rmse.toPrecision(3)} / n=${fit.points} / ${fit.fitStatus}`
    : text.no_fit;

  const prepareWide = () => {
    document.getElementById('fit-results').classList.toggle('gamma-active', gammaMode);
    const [rows1, rows2] = selectedRows();
    const deaths1 = cumulativeDeathsSeries(rows1);
    const deaths2 = cumulativeDeathsSeries(rows2);
    let series1 = observedSeries(rows1);
    let series2 = observedSeries(rows2);
    const quietStart = Number(document.getElementById('quiet-start').value);
    const quietEnd = Number(document.getElementById('quiet-end').value);
    const fitEnd = Number(document.getElementById('fit-end').value);
    const gammaEligible = !selected('area').has('jp271004');
    const fit1 = gammaEligible ? fitGamma(series1, quietStart, quietEnd) : null;
    const fit2 = gammaEligible ? fitGamma(series2, quietStart, quietEnd) : null;
    const quietPoints = quietEnd - quietStart + 1;
    const fit1Text = quietPoints < 4 ? text.fit_wait : fitLabel(fit1);
    const fit2Text = quietPoints < 4 ? text.fit_wait : fitLabel(fit2);
    document.getElementById('c1fit').textContent = gammaMode && fit1Text ? fit1Text : '—';
    document.getElementById('c2fit').textContent = gammaMode && fit2Text ? fit2Text : '—';
    const gammaReady = gammaMode && quietPoints >= 4 && fit1 && fit2;
    if (gammaReady) {
      // quiet windowからthetaを推定できたときだけGamma補正値を作る。
      // Build gamma-adjusted values only when theta was estimated from the quiet window.
      series1 = adjustedSeries(series1, fit1);
      series2 = adjustedSeries(series2, fit2);
    }
    const map1 = new Map(series1.map(row => [row.date, row]));
    const map2 = new Map(series2.map(row => [row.date, row]));
    const deathsMap1 = new Map(deaths1.map(row => [row.date, row.deaths]));
    const deathsMap2 = new Map(deaths2.map(row => [row.date, row.deaths]));
    const dates = [...new Set([...deathsMap1.keys(), ...deathsMap2.keys()])].sort();
    const wide = dates.map(date => ({
      date,
      observed1: map1.get(date)?.observed ?? null,
      observed2: map2.get(date)?.observed ?? null,
      deaths1: deathsMap1.get(date) ?? null,
      deaths2: deathsMap2.get(date) ?? null,
      adjusted1: map1.get(date)?.adjusted ?? null,
      adjusted2: map2.get(date)?.adjusted ?? null
    }));
    // 累積開始後の第4週を基準にKCORを1へ正規化する。
    // Normalize KCOR to 1 at the fourth accumulated week.
    const anchor = fitEnd >= 4 ? wide[fitEnd - 1] : null;
    const factorNumerator = gammaReady ? anchor?.adjusted2 : anchor?.deaths2;
    const factorDenominator = gammaReady ? anchor?.adjusted1 : anchor?.deaths1;
    const fitFactor = Number.isFinite(factorNumerator) && Number.isFinite(factorDenominator) && factorDenominator > 0
      ? factorNumerator / factorDenominator : null;
    return {fitFactor, gammaReady, wide};
  };

  async function render() {
    if (!currentData) return;
    const {wide, fitFactor, gammaReady} = prepareWide();
    if (!wide.length) {
      document.getElementById('view').replaceChildren();
      status(text.no_fit);
      return;
    }
    status('');
    const availableFactor = gammaMode ? (gammaReady ? fitFactor : null) : fitFactor;
    document.getElementById('gamma-factor').textContent = availableFactor
      ? (gammaMode ? text.gamma_factor : text.baseline_factor).replace('%{factor}', availableFactor.toFixed(4)) : '—';
    const adjustedMode = gammaMode;
    const displayFactor = availableFactor || 1;
    const viewWidth = document.getElementById('view').clientWidth || 1020;
    lastViewWidth = viewWidth;
    const chartWidth = Math.min(820, Math.max(180, viewWidth - 180));
    const quietRow = document.getElementById('quiet-row');
    const quietSlider = document.getElementById('quiet-slider');
    const fitSlider = document.getElementById('fit-slider');
    quietRow.style.width = `${viewWidth}px`;
    const xDomain = [document.querySelector('#cutoff select').value, wide.at(-1).date];
    const commonX = {field: 'date', type: 'temporal', title: text.date, scale: {domain: xDomain}, axis: {format: '%Y-%m', tickCount: {interval: 'month', step: 1}}};
    const line = (field, color, width, opacity, title, scale = 1, strokeDash = null) => ({
      transform: scale === 1 ? [] : [{calculate: `datum.${field} * ${scale}`, as: `${field}_display`}],
      mark: {type: 'line', stroke: color, strokeWidth: width, opacity, ...(strokeDash ? {strokeDash} : {})},
      encoding: {
        x: commonX,
        y: {field: scale === 1 ? field : `${field}_display`, type: 'quantitative', title: adjustedMode ? text.cumulative_hazard : text.cumulative_deaths, scale: {zero: true}},
        tooltip: [
          {field: 'date', type: 'temporal', title: text.date, format: '%Y-%m-%d'},
          {field: scale === 1 ? field : `${field}_display`, type: 'quantitative', title, format: adjustedMode ? '.6f' : ',.0f'}
        ]
      }
    });
    const gammaScale = availableFactor || 1;
    const topLayers = adjustedMode
      ? [
          line('observed1', 'blue', 2.4, 1, `${text.cohort1} ${text.observed}`),
          line('observed2', 'red', 2.4, 1, `${text.cohort2} ${text.observed}`),
          ...(gammaReady ? [
            line('adjusted1', 'blue', 4.2, 1, `${text.cohort1} ${text.adjusted}`, gammaScale, [16, 3]),
            line('adjusted2', 'red', 4.2, 1, `${text.cohort2} ${text.adjusted}`, 1, [16, 3])
          ] : [])
        ]
      : [
          line('deaths1', 'blue', 2.4, 1, `${text.cohort1}`, displayFactor),
          line('deaths2', 'red', 2.4, 1, `${text.cohort2}`)
        ];
    const numerator = gammaReady ? 'datum.adjusted2' : (adjustedMode ? 'datum.observed2' : 'datum.deaths2');
    const denominator = gammaReady ? 'datum.adjusted1' : (adjustedMode ? 'datum.observed1' : 'datum.deaths1');
    const quietStartDate = document.getElementById('quiet-start-value').textContent;
    const quietEndDate = document.getElementById('quiet-end-value').textContent;
    const fitEndDate = document.getElementById('fit-end-value').textContent;
    topLayers.push({
      data: {values: [{date: xDomain[0]}]},
      mark: {type: 'rule', stroke: '#010101', opacity: 0},
      encoding: {x: {field: 'date', type: 'temporal', scale: {domain: xDomain}}}
    });
    topLayers.push({
      data: {values: [{date: xDomain[1]}]},
      mark: {type: 'rule', stroke: '#020202', opacity: 0},
      encoding: {x: {field: 'date', type: 'temporal', scale: {domain: xDomain}}}
    });
    if (gammaMode) {
      topLayers.push({
        data: {name: 'quietStartMarker', values: [{date: quietStartDate}]},
        mark: {type: 'rule', stroke: '#087f5b', strokeWidth: 2},
        encoding: {x: {field: 'date', type: 'temporal', scale: {domain: xDomain}}, tooltip: [{field: 'date', type: 'temporal', title: text.quiet_start, format: '%Y-%m-%d'}]}
      }, {
        data: {name: 'quietEndMarker', values: [{date: quietEndDate}]},
        mark: {type: 'rule', stroke: '#087f5b', strokeWidth: 2},
        encoding: {x: {field: 'date', type: 'temporal', scale: {domain: xDomain}}, tooltip: [{field: 'date', type: 'temporal', title: text.quiet_end, format: '%Y-%m-%d'}]}
      });
    }
    topLayers.push({
      data: {name: 'fitMarker', values: [{date: fitEndDate}]},
      mark: {type: 'rule', stroke: '#6f42c1', strokeWidth: 2},
      encoding: {x: {field: 'date', type: 'temporal', scale: {domain: xDomain}}, tooltip: [{field: 'date', type: 'temporal', title: text.fit_end, format: '%Y-%m-%d'}]}
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
                y: {field: 'KCOR_G', type: 'quantitative', title: adjustedMode ? text.ratio : text.death_ratio, scale: {zero: true}},
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
      const result = await vegaEmbed('#view', spec, {actions: false, renderer: 'svg'});
      currentView = result.view;
      const markerX = color => {
        const marker = [...document.querySelectorAll('#view svg *')]
          .find(element => getComputedStyle(element).stroke === color);
        const bounds = marker?.getBoundingClientRect();
        return bounds ? bounds.left + bounds.width / 2 : null;
      };
      await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
      const firstX = markerX('rgb(1, 1, 1)');
      const lastX = markerX('rgb(2, 2, 2)');
      if (Number.isFinite(firstX) && Number.isFinite(lastX) && lastX > firstX) {
        const rowLeft = quietRow.getBoundingClientRect().left;
        for (const slider of [quietSlider, fitSlider]) {
          slider.style.marginLeft = `${firstX - rowLeft}px`;
          slider.style.width = `${lastX - firstX}px`;
          slider.dataset.firstDate = document.querySelector('#cutoff select').value;
          slider.dataset.lastDate = wide.at(-1).date;
        }
        updateSliderThumbs();
      }
    } catch (error) {
      console.error(error);
      status(text.load_error);
    }
  }

  const placeThumb = (sliderId, inputId, thumbId) => {
    const slider = document.getElementById(sliderId);
    const input = document.getElementById(inputId);
    const selected = Date.parse(dateForWeek(input.value));
    const first = Date.parse(slider.dataset.firstDate || '');
    const last = Date.parse(slider.dataset.lastDate || '');
    const fraction = Number.isFinite(selected) && Number.isFinite(first) && last > first
      ? Math.max(0, Math.min(1, (selected - first) / (last - first))) : 0;
    document.getElementById(thumbId).style.left = `${fraction * 100}%`;
  };

  const updateSliderThumbs = () => {
    placeThumb('quiet-slider', 'quiet-start', 'quiet-start-thumb');
    placeThumb('quiet-slider', 'quiet-end', 'quiet-end-thumb');
    placeThumb('fit-slider', 'fit-end', 'fit-thumb');
  };

  const updateSliderLabels = () => {
    const [rows] = selectedRows();
    const cutoff = document.querySelector('#cutoff select')?.value || '';
    const dateAt = id => {
      const week = Number(document.getElementById(id).value);
      return week === 0 ? cutoff : (rows[week - 1]?.date || cutoff);
    };
    document.getElementById('quiet-start-value').textContent = dateAt('quiet-start');
    document.getElementById('quiet-end-value').textContent = dateAt('quiet-end');
    document.getElementById('fit-end-value').textContent = dateAt('fit-end');
    updateSliderThumbs();
  };

  const moveMarker = (name, date) => {
    if (!currentView || typeof vega === 'undefined') return;
    if (!date) return;
    const changes = vega.changeset().remove(() => true).insert([{date}]);
    try { currentView.change(name, changes).runAsync(); } catch (_) { /* marker is absent in this mode */ }
  };

  const start = async () => {
    try {
      const quietStart = document.getElementById('quiet-start');
      const quietEnd = document.getElementById('quiet-end');
      const fitEnd = document.getElementById('fit-end');
      const scheduleRender = delay => {
        clearTimeout(resizeTimer);
        resizeTimer = setTimeout(render, delay);
      };
      const finishQuietDrag = () => {
        if (!quietDragging) return;
        quietDragging = false;
        scheduleRender(0);
      };
      const quietInput = changed => {
        if (changed === quietStart) quietStart.value = Math.min(Number(quietStart.value), Number(quietEnd.value) - 4);
        if (changed === quietEnd) quietEnd.value = Math.max(Number(quietEnd.value), Number(quietStart.value) + 4);
        updateSliderLabels();
        moveMarker('quietStartMarker', document.getElementById('quiet-start-value').textContent);
        moveMarker('quietEndMarker', document.getElementById('quiet-end-value').textContent);
        document.getElementById('c1fit').textContent = text.fitting;
        document.getElementById('c2fit').textContent = text.fitting;
        document.getElementById('gamma-factor').textContent = '—';
        if (!quietDragging) scheduleRender(80);
      };
      quietStart.oninput = () => quietInput(quietStart);
      quietEnd.oninput = () => quietInput(quietEnd);
      quietStart.onchange = quietEnd.onchange = () => scheduleRender(0);
      fitEnd.oninput = () => {
        updateSliderLabels();
        moveMarker('fitMarker', document.getElementById('fit-end-value').textContent);
        document.getElementById('gamma-factor').textContent = '—';
        if (!quietDragging) scheduleRender(80);
      };
      fitEnd.onchange = () => scheduleRender(0);
      // 日本語: 重なったnative rangeではなくtrack自身で近いthumbを選び、dragを一貫して処理する。
      // English: Let the track select and drag the nearest thumb instead of stacking interactive native ranges.
      const attachTrackDrag = (container, chooseInput, applyValue) => {
        let activeInput = null;
        const pointerValue = event => {
          const bounds = container.getBoundingClientRect();
          const fraction = Math.max(0, Math.min(1, (event.clientX - bounds.left) / bounds.width));
          const first = Date.parse(container.dataset.firstDate || '');
          const last = Date.parse(container.dataset.lastDate || '');
          const target = first + fraction * (last - first);
          const maximum = Number(chooseInput(0).max);
          let nearest = 0;
          let distance = Number.POSITIVE_INFINITY;
          for (let week = 0; week <= maximum; week += 1) {
            const candidate = Math.abs(Date.parse(dateForWeek(week)) - target);
            if (candidate < distance) { nearest = week; distance = candidate; }
          }
          return nearest;
        };
        const move = event => {
          if (!activeInput) return;
          event.preventDefault();
          applyValue(activeInput, pointerValue(event));
        };
        container.onpointerdown = event => {
          event.preventDefault();
          quietDragging = true;
          clearTimeout(resizeTimer);
          const value = pointerValue(event);
          activeInput = chooseInput(value);
          container.setPointerCapture(event.pointerId);
          move(event);
        };
        container.ondragstart = event => event.preventDefault();
        container.onpointermove = move;
        container.onpointerup = event => {
          if (!activeInput) return;
          move(event);
          activeInput = null;
          container.releasePointerCapture(event.pointerId);
          finishQuietDrag();
        };
        container.onpointercancel = () => { activeInput = null; finishQuietDrag(); };
      };
      attachTrackDrag(
        document.getElementById('quiet-slider'),
        value => Math.abs(value - Number(quietStart.value)) <= Math.abs(value - Number(quietEnd.value)) ? quietStart : quietEnd,
        (input, value) => {
          input.value = input === quietStart
            ? Math.min(value, Number(quietEnd.value) - 4)
            : Math.max(value, Number(quietStart.value) + 4);
          quietInput(input);
        }
      );
      attachTrackDrag(
        document.getElementById('fit-slider'),
        () => fitEnd,
        (input, value) => { input.value = value; input.oninput(); }
      );
      document.getElementById('gamma-toggle').onclick = () => {
        if (gammaMode) {
          resetGamma();
        } else {
          gammaMode = true;
          const osaka = document.querySelector('input.area[value="jp271004"]');
          if (osaka) {
            osakaCheckedBeforeGamma = osaka.checked;
            osaka.checked = false;
            osaka.disabled = true;
          }
        }
        fitEnd.value = 0;
        updateSliderLabels();
        document.getElementById('gamma-toggle').textContent = gammaMode ? text.gamma_remove : text.gamma_apply;
        document.getElementById('osaka-gamma-note').hidden = !gammaMode;
        document.getElementById('gamma-window-controls').hidden = !gammaMode;
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
