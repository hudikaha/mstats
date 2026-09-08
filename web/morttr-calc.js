/* morttr browser-side calculator. Keep results schema-compatible with morttr.rb. */
(() => {
  "use strict";

  const root = typeof window === "undefined" ? globalThis : window;

  const Z95 = 1.959963984540054;
  const Z99 = 2.5758293035489004;
  const DAYS_PER_YEAR = 365.2425;
  const MIN_TRAINING_YEARS = 4;

  const inverse = matrix => {
    const n = matrix.length;
    const work = matrix.map((row, i) => [...row, ...Array.from({length:n}, (_, j) => i === j ? 1 : 0)]);
    for (let col = 0; col < n; col += 1) {
      let pivot = col;
      for (let row = col + 1; row < n; row += 1) {
        if (Math.abs(work[row][col]) > Math.abs(work[pivot][col])) pivot = row;
      }
      if (Math.abs(work[pivot][col]) < 1e-12) throw new Error("singular regression matrix");
      [work[col], work[pivot]] = [work[pivot], work[col]];
      const divisor = work[col][col];
      work[col] = work[col].map(value => value / divisor);
      for (let row = 0; row < n; row += 1) {
        if (row === col) continue;
        const factor = work[row][col];
        work[row] = work[row].map((value, j) => value - factor * work[col][j]);
      }
    }
    return work.map(row => row.slice(n));
  };

  const mv = (matrix, vector) => matrix.map(row => row.reduce((sum, value, i) => sum + value * vector[i], 0));
  const dot = (left, right) => left.reduce((sum, value, i) => sum + value * right[i], 0);

  const interceptFit = (rows, center) => {
    const deaths = rows.reduce((sum, row) => sum + Number(row.deaths), 0);
    const population = rows.reduce((sum, row) => sum + Number(row.population), 0);
    const rate = deaths / population;
    const pearson = rows.reduce((sum, row) => {
      const mu = rate * Number(row.population);
      return sum + (mu > 0 ? (Number(row.deaths) - mu) ** 2 / mu : 0);
    }, 0);
    return {beta:[Math.log(rate), 0], covariance:[[1 / deaths, 0], [0, 0]], center,
      dispersion:rows.length > 1 ? pearson / (rows.length - 1) : null};
  };

  const poissonFit = rows => {
    const center = rows.reduce((sum, row) => sum + Number(row.year), 0) / rows.length;
    const totalDeaths = rows.reduce((sum, row) => sum + Number(row.deaths), 0);
    if (totalDeaths === 0) return {beta:[-Infinity, 0], covariance:[[0,0],[0,0]], center, dispersion:0, zero:true};
    if (rows.filter(row => Number(row.deaths) > 0).length < 2) return interceptFit(rows, center);
    let beta = [Math.log(totalDeaths / rows.reduce((sum, row) => sum + Number(row.population), 0)), 0];
    let covariance;
    for (let iteration = 0; iteration < 100; iteration += 1) {
      const xtwx = [[0,0],[0,0]], xtwz = [0,0];
      rows.forEach(row => {
        const x = [1, Number(row.year) - center];
        const population = Number(row.population);
        const eta = beta[0] + beta[1] * x[1] + Math.log(population);
        const mu = Math.exp(eta);
        const z = eta + (Number(row.deaths) - mu) / mu - Math.log(population);
        for (let i = 0; i < 2; i += 1) {
          xtwz[i] += x[i] * mu * z;
          for (let j = 0; j < 2; j += 1) xtwx[i][j] += x[i] * mu * x[j];
        }
      });
      try { covariance = inverse(xtwx); } catch (_error) { return interceptFit(rows, center); }
      const updated = mv(covariance, xtwz);
      const difference = Math.max(...updated.map((value, i) => Math.abs(value - beta[i])));
      beta = updated;
      if (difference < 1e-10) break;
    }
    const pearson = rows.reduce((sum, row) => {
      const mu = Math.exp(beta[0] + beta[1] * (Number(row.year) - center)) * Number(row.population);
      return sum + (Number(row.deaths) - mu) ** 2 / mu;
    }, 0);
    return {beta, covariance, center, dispersion:rows.length > 2 ? pearson / (rows.length - 2) : null};
  };

  const prediction = (row, fit, varianceScale, include99) => {
    const x = [1, Number(row.year) - fit.center];
    const eta = fit.beta[0] + fit.beta[1] * x[1];
    const scale = Number(row.unit_scale || 100000);
    const population = Number(row.population);
    const expected = Math.exp(eta) * scale;
    const mu = Math.exp(eta) * population;
    const varEta = dot(x, mv(fit.covariance, x));
    const se = Math.sqrt(varianceScale * mu + mu * mu * varianceScale * varEta);
    return {expected, lower:Math.max(0, mu - Z95 * se) / population * scale,
      upper:(mu + Z95 * se) / population * scale,
      lower99:include99 ? Math.max(0, mu - Z99 * se) / population * scale : null,
      upper99:include99 ? (mu + Z99 * se) / population * scale : null};
  };

  const cutoffs = (rows, trainingStart) => {
    const last = Math.max(...rows.map(row => Number(row.year)));
    const result = [];
    for (let cutoff = 2015; cutoff <= last - 2; cutoff += 1) {
      if (rows.filter(row => Number(row.year) >= trainingStart && Number(row.year) <= cutoff).length >= MIN_TRAINING_YEARS) result.push(cutoff);
    }
    return result;
  };

  const displayRow = (row, predictionValue, fit, series, label, model, cutoff) => ({
    series, label, model, train_to:cutoff, year:Number(row.year), season:row.season,
    observed:Number(row.observed), expected:predictionValue.expected,
    pi_lower:predictionValue.lower, pi_upper:predictionValue.upper,
    pi99_lower:model === "quasi_poisson" ? predictionValue.lower99 : null,
    pi99_upper:model === "quasi_poisson" ? predictionValue.upper99 : null,
    outside_pi:Number(row.observed) < predictionValue.lower || Number(row.observed) > predictionValue.upper,
    period:Number(row.year) >= root.morttrCalc.trainingStart && Number(row.year) <= cutoff ? "training" :
      Number(row.year) < root.morttrCalc.trainingStart ? "historical" : "prediction",
    dispersion:fit.dispersion == null ? null : Number(fit.dispersion.toFixed(4)),
    deaths:Number(Number(row.deaths).toFixed(2)), population:Math.round(Number(row.population)),
    src_url:row.src_url, interval_method:"analytic",
    interval_style:model === "quasi_poisson" ? "quasi_poisson" : "poisson",
    interval_label:model === "quasi_poisson" ? root.morttrCalc.quasiLabel : root.morttrCalc.poissonLabel,
    auto_selected:true
  });

  const scalarScenarios = (rows, series, label) => cutoffs(rows, root.morttrCalc.trainingStart).flatMap(cutoff => {
    const training = rows.filter(row => Number(row.year) >= root.morttrCalc.trainingStart && Number(row.year) <= cutoff);
    const fit = poissonFit(training);
    return ["poisson", "quasi_poisson"].flatMap(model => {
      const varianceScale = model === "quasi_poisson" ? Math.max(Number(fit.dispersion || 0), 1) : 1;
      return rows.map(row => displayRow(row, prediction(row, fit, varianceScale, model === "quasi_poisson"), fit,
        series, label, model, cutoff));
    });
  });

  const stratifiedScenarios = (rows, series, label) => {
    const ages = [...new Set(rows.flatMap(row => row.strata.map(item => item.age)))];
    return cutoffs(rows, root.morttrCalc.trainingStart).flatMap(cutoff => {
      const training = rows.filter(row => Number(row.year) >= root.morttrCalc.trainingStart && Number(row.year) <= cutoff);
      if (!ages.every(age => training.filter(row => row.strata.some(item => item.age === age)).length >= MIN_TRAINING_YEARS)) return [];
      const fits = Object.fromEntries(ages.map(age => [age, poissonFit(training.map(row => {
        const item = row.strata.find(stratum => stratum.age === age);
        return {year:row.year, deaths:item.deaths, population:item.population};
      }))]));
      const dfs = Object.fromEntries(ages.map(age => [age, Math.max(training.length - 2, 0)]));
      const totalDf = Object.values(dfs).reduce((sum, value) => sum + value, 0);
      const dispersion = totalDf > 0 ? ages.reduce((sum, age) => sum + Number(fits[age].dispersion || 0) * dfs[age], 0) / totalDf : null;
      return ["poisson", "quasi_poisson"].flatMap(model => rows.map(row => {
        let expected = 0, poissonVariance = 0;
        row.strata.forEach(item => {
          const fit = fits[item.age], x = [1, Number(row.year) - fit.center];
          const population = Number(item.population), weight = Number(item.weight);
          const mu = Math.exp(fit.beta[0] + fit.beta[1] * x[1]) * population;
          expected += weight * mu / population * 100000;
          poissonVariance += weight * weight * (mu + mu * mu * dot(x, mv(fit.covariance, x))) /
            (population * population) * 100000 ** 2;
        });
        const factor = model === "quasi_poisson" ? Math.max(Number(dispersion || 0), 1) : 1;
        const se = Math.sqrt(factor * poissonVariance);
        const calculated = {expected, lower:Math.max(0, expected - Z95 * se), upper:expected + Z95 * se,
          lower99:model === "quasi_poisson" ? Math.max(0, expected - Z99 * se) : null,
          upper99:model === "quasi_poisson" ? expected + Z99 * se : null};
        return displayRow(row, calculated, {dispersion}, series, label, model, cutoff);
      }));
    });
  };

  const stringSeed = value => {
    let hash = 2166136261;
    for (let index = 0; index < value.length; index += 1) {
      hash ^= value.charCodeAt(index);
      hash = Math.imul(hash, 16777619);
    }
    return hash >>> 0;
  };

  const randomGenerator = seed => {
    let state = seed || 0x6d2b79f5;
    return () => {
      state += 0x6d2b79f5;
      let value = state;
      value = Math.imul(value ^ value >>> 15, value | 1);
      value ^= value + Math.imul(value ^ value >>> 7, value | 61);
      return ((value ^ value >>> 14) >>> 0) / 4294967296;
    };
  };

  const logGamma = value => {
    const coefficients = [0.9999999999998099, 676.5203681218851, -1259.1392167224028,
      771.3234287776531, -176.6150291621406, 12.507343278686905,
      -0.13857109526572012, 9.984369578019572e-6, 1.5056327351493116e-7];
    if (value < 0.5) return Math.log(Math.PI) - Math.log(Math.sin(Math.PI * value)) - logGamma(1 - value);
    const shifted = value - 1;
    let sum = coefficients[0];
    for (let index = 1; index < coefficients.length; index += 1) sum += coefficients[index] / (shifted + index);
    const base = shifted + 7.5;
    return 0.5 * Math.log(2 * Math.PI) + (shifted + 0.5) * Math.log(base) - base + Math.log(sum);
  };

  const poissonRandom = (random, lambda) => {
    if (lambda < 30) {
      const limit = Math.exp(-lambda);
      let product = 1, count = 0;
      do { count += 1; product *= random(); } while (product > limit);
      return count - 1;
    }
    const rootValue = Math.sqrt(lambda), logLambda = Math.log(lambda);
    const b = 0.931 + 2.53 * rootValue, a = -0.059 + 0.02483 * b;
    const inverseAlpha = 1.1239 + 1.1328 / (b - 3.4), vr = 0.9277 - 3.6224 / (b - 2);
    for (;;) {
      const u = random() - 0.5, v = random(), us = 0.5 - Math.abs(u);
      const count = Math.floor((2 * a / us + b) * u + lambda + 0.43);
      if (us >= 0.07 && v <= vr) return count;
      if (count < 0 || (us < 0.013 && v > us)) continue;
      if (Math.log(v * inverseAlpha / (a / (us * us) + b)) <=
          -lambda + count * logLambda - logGamma(count + 1)) return count;
    }
  };

  const coefficientDraws = (fit, count, random) => {
    if (fit.zero) return Array.from({length:count}, () => [...fit.beta]);
    const l00 = Math.sqrt(Math.max(Number(fit.covariance[0][0]), 0));
    const l10 = l00 ? Number(fit.covariance[1][0]) / l00 : 0;
    const l11 = Math.sqrt(Math.max(Number(fit.covariance[1][1]) - l10 * l10, 0));
    return Array.from({length:count}, () => {
      const radius = Math.sqrt(-2 * Math.log(Math.max(random(), Number.MIN_VALUE)));
      const angle = 2 * Math.PI * random(), z0 = radius * Math.cos(angle), z1 = radius * Math.sin(angle);
      return [fit.beta[0] + l00 * z0, fit.beta[1] + l10 * z0 + l11 * z1];
    });
  };

  const simulationDisplayRow = (row, analytic, lower, upper, input) => ({
    ...analytic, ...input.metadata,
    pi_lower:lower, pi_upper:upper, pi99_lower:null, pi99_upper:null,
    outside_pi:Number(row.observed) < lower || Number(row.observed) > upper,
    dispersion:null, interval_method:"simulation", interval_style:"simulation",
    interval_label:root.morttrCalc.simulationLabel, auto_selected:true,
    plot_date:input.period === "calendar" ? `${row.year}-01-01` : `${Number(row.year) + 1}-01-01`
  });

  const simulateInput = (input, cutoff, count) => {
    const rows = input.rows, training = rows.filter(row => Number(row.year) >= root.morttrCalc.trainingStart && Number(row.year) <= cutoff);
    if (training.length < MIN_TRAINING_YEARS) return [];
    const analytic = (rows[0]?.strata ? stratifiedScenarios(rows, input.series, input.label) : scalarScenarios(rows, input.series, input.label)).
      filter(row => row.model === "poisson" && row.train_to === cutoff);
    const analyticByYear = new Map(analytic.map(row => [Number(row.year), row]));
    const random = randomGenerator(stringSeed(`${JSON.stringify(rows)}:${rows[0]?.strata ? "asr:" : ""}${cutoff}:${count}`));
    if (!rows[0]?.strata) {
      const fit = poissonFit(training), draws = coefficientDraws(fit, count, random);
      return rows.map(row => {
        const x = Number(row.year) - fit.center, population = Number(row.population), scale = Number(row.unit_scale || 100000);
        const values = draws.map(beta => poissonRandom(random, Math.exp(beta[0] + beta[1] * x) * population) / population * scale).sort((a,b) => a-b);
        return simulationDisplayRow(row, analyticByYear.get(Number(row.year)), values[Math.floor(count * 0.025)],
          values[Math.floor(count * 0.975) - 1], input);
      });
    }
    const ages = [...new Set(rows.flatMap(row => row.strata.map(item => item.age)))];
    const fits = Object.fromEntries(ages.map(age => [age, poissonFit(training.map(row => {
      const item = row.strata.find(stratum => stratum.age === age);
      return {year:row.year, deaths:item.deaths, population:item.population};
    }))]));
    const draws = Object.fromEntries(ages.map(age => [age, coefficientDraws(fits[age], count, random)]));
    return rows.map(row => {
      const values = Array(count).fill(0);
      row.strata.forEach(stratum => {
        const fit = fits[stratum.age], x = Number(row.year) - fit.center;
        draws[stratum.age].forEach((beta, index) => {
          const mu = Math.exp(beta[0] + beta[1] * x) * Number(stratum.population);
          values[index] += Number(stratum.weight) * poissonRandom(random, mu) / Number(stratum.population) * 100000;
        });
      });
      values.sort((a,b) => a-b);
      return simulationDisplayRow(row, analyticByYear.get(Number(row.year)), values[Math.floor(count * 0.025)],
        values[Math.floor(count * 0.975) - 1], input);
    });
  };

  root.morttrCalc = {
    trainingStart:2000,
    quasiLabel:"Quasi-Poisson approximation",
    poissonLabel:"Poisson approximation",
    missingLabel:"Missing",
    simulationLabel:"Simulation",
    calculateAnnual(inputs, options = {}) {
      this.trainingStart = Number(options.trainingStart || 2000);
      this.quasiLabel = options.quasiLabel || this.quasiLabel;
      this.poissonLabel = options.poissonLabel || this.poissonLabel;
      this.missingLabel = options.missingLabel || this.missingLabel;
      return inputs.flatMap(input => (input.rows[0] && input.rows[0].strata ? stratifiedScenarios : scalarScenarios)(input.rows, input.series, input.label).map(row => ({
        ...row, ...input.metadata,
        plot_date:input.period === "calendar" ? `${row.year}-01-01` : `${row.year + 1}-01-01`,
        season:row.season || (input.period === "calendar" ? null : `${row.year}/${String((row.year + 1) % 100).padStart(2, "0")}`)
      })));
    },

    calculateAnnualSimulation(inputs, options = {}) {
      this.trainingStart = Number(options.trainingStart || this.trainingStart || 2000);
      this.simulationLabel = options.simulationLabel || this.simulationLabel;
      const cutoff = Number(options.cutoff), count = Number(options.simulations || 10000);
      return inputs.flatMap(input => simulateInput(input, cutoff, count));
    },

    calculateWeekly(rows, combinations, metric) {
      const isoParts = value => {
        const date = new Date(`${value}T00:00:00Z`);
        const thursday = new Date(date);
        thursday.setUTCDate(date.getUTCDate() + 4 - (date.getUTCDay() || 7));
        const yearStart = new Date(Date.UTC(thursday.getUTCFullYear(), 0, 1));
        return {date, year:thursday.getUTCFullYear(), week:Math.ceil((((thursday - yearStart) / 86400000) + 1) / 7)};
      };
      const fitWeekly = (samples, robust) => {
        if (samples.length < 4) return null;
        let active = samples, fit = null;
        for (let pass = 0; pass < (robust ? 2 : 1); pass += 1) {
          const p = active[0].features.length;
          let beta = Array(p).fill(0), covariance;
          for (let iteration = 0; iteration < 40; iteration += 1) {
            const xtwx = Array.from({length:p}, () => Array(p).fill(0));
            const xtwz = Array(p).fill(0);
            active.forEach(sample => {
              const offset = Math.log(Math.max(Number(sample.exposure), 1e-12));
              const eta = Math.max(-20, Math.min(20, offset + dot(sample.features, beta)));
              const mu = Math.exp(eta);
              const z = eta + (Number(sample.deaths) - mu) / mu;
              for (let i = 0; i < p; i += 1) {
                xtwz[i] += sample.features[i] * mu * (z - offset);
                for (let j = 0; j < p; j += 1) xtwx[i][j] += sample.features[i] * mu * sample.features[j];
              }
            });
            try { covariance = inverse(xtwx); } catch (_error) { return null; }
            const updated = mv(covariance, xtwz);
            const difference = Math.sqrt(updated.reduce((sum, value, i) => sum + (value - beta[i]) ** 2, 0));
            beta = updated;
            if (difference < 1e-8) break;
          }
          const mus = active.map(sample => Math.exp(Math.log(Math.max(Number(sample.exposure), 1e-12)) + dot(sample.features, beta)));
          const pearson = active.reduce((sum, sample, i) => sum + (Number(sample.deaths) - mus[i]) ** 2 / Math.max(mus[i], 1e-12), 0);
          const phi = Math.max(pearson / Math.max(active.length - p, 1), 1);
          const xtwx = Array.from({length:p}, () => Array(p).fill(0));
          active.forEach((sample, index) => {
            for (let i = 0; i < p; i += 1) for (let j = 0; j < p; j += 1) {
              xtwx[i][j] += sample.features[i] * mus[index] * sample.features[j];
            }
          });
          try { covariance = inverse(xtwx).map(row => row.map(value => value * phi)); } catch (_error) { return null; }
          fit = {beta, covariance, dispersion:phi};
          if (!robust) break;
          const filtered = active.filter((sample, index) =>
            Math.abs((Number(sample.deaths) - mus[index]) / Math.sqrt(Math.max(phi * mus[index], 1e-12))) <= 2.58);
          if (filtered.length < Math.max(p + 2, 4) || filtered.length === active.length) break;
          active = filtered;
        }
        return fit;
      };
      const referenceYears = (targetYear, baseline) => baseline === "fixed_2015_2019" ? [2015,2016,2017,2018,2019] :
        baseline === "fixed_2016_2020" ? [2016,2017,2018,2019,2020] : Array.from({length:5}, (_, i) => targetYear - 5 + i);
      const circularDistance = (left, right) => Math.min(Math.abs(left-right), 52-Math.abs(left-right), 53-Math.abs(left-right));
      const bySeries = new Map();
      rows.forEach(row => {
        if (!row.model_strata || !row.date) return;
        if (!bySeries.has(row.series)) bySeries.set(row.series, []);
        bySeries.get(row.series).push(row);
      });
      const output = [];
      combinations.forEach(([method, baseline]) => bySeries.forEach((seriesRows, series) => {
        const usable = [...seriesRows].sort((a,b) => a.date.localeCompare(b.date));
        const byAge = new Map(), fitCache = new Map();
        usable.forEach(row => {
          const parts = isoParts(row.date);
          row.model_strata.forEach(stratum => {
            if (!byAge.has(stratum.age)) byAge.set(stratum.age, []);
            byAge.get(stratum.age).push({...stratum, ...parts});
          });
        });
        usable.forEach(row => {
          const targetParts = isoParts(row.date), fixedEnd = {fixed_2015_2019:2019,fixed_2016_2020:2020}[baseline];
          const combinedSeries = `${series}--${method}--${baseline}`;
          if (fixedEnd && targetParts.year <= fixedEnd) { output.push({...row, series:combinedSeries, model_strata:undefined}); return; }
          const years = referenceYears(targetParts.year, baseline);
          const estimates = [];
          for (const target of row.model_strata) {
            const history = (byAge.get(target.age) || []).filter(item => years.includes(item.year));
            if (!history.length) break;
            const exposure = metric === "deaths" ? 1 : Number(target.population) * 7 / DAYS_PER_YEAR;
            if (method === "five_year") {
              const refs = history.filter(item => item.week === targetParts.week);
              if (refs.length !== years.length) break;
              const vals = refs.map(item => Number(item.deaths));
              estimates.push({...target, expected:vals.reduce((a,b)=>a+b,0)/vals.length, variance:null,
                lower:Math.min(...vals), upper:Math.max(...vals)});
              continue;
            }
            const samples = method === "farrington" ? history.filter(item => circularDistance(item.week, targetParts.week) <= 3) :
              history.filter(item => (item.week >= 16 && item.week <= 25) || (item.week >= 37 && item.week <= 44));
            if (samples.length < 10) break;
            const cacheKey = [target.age, method, years.join(","), method === "farrington" ? targetParts.week : ""].join("|");
            let cached = fitCache.get(cacheKey);
            const origin = cached ? cached.origin : new Date(Math.min(...samples.map(item => item.date.getTime())));
            const features = item => {
              const trend = (item.date - origin) / 86400000 / DAYS_PER_YEAR;
              if (method !== "euromomo") return [1, trend];
              const angle = 2 * Math.PI * item.week / 52.1775;
              return [1, trend, Math.sin(angle), Math.cos(angle)];
            };
            if (!cached) {
              const fit = fitWeekly(samples.map(item => ({deaths:item.deaths,
                exposure:metric === "deaths" ? 1 : Number(item.population) * 7 / DAYS_PER_YEAR, features:features(item)})), method === "farrington");
              if (!fit) break;
              cached = {fit, origin}; fitCache.set(cacheKey, cached);
            }
            const x = features({...targetParts}), mu = Math.exp(Math.log(Math.max(exposure,1e-12)) + dot(x,cached.fit.beta));
            const variance = cached.fit.dispersion * mu + mu * mu * Math.max(dot(x,mv(cached.fit.covariance,x)),0);
            estimates.push({...target, expected:mu, variance});
          }
          if (estimates.length !== row.model_strata.length) { output.push({...row, series:combinedSeries, model_strata:undefined}); return; }
          let expected, variance, lower, upper;
          if (metric === "deaths") {
            expected = estimates.reduce((s,i)=>s+i.expected,0);
            variance = estimates.some(i=>i.variance==null) ? null : estimates.reduce((s,i)=>s+i.variance,0);
            lower = estimates.reduce((s,i)=>s+Number(i.lower||0),0); upper = estimates.reduce((s,i)=>s+Number(i.upper||0),0);
          } else if (metric === "crude_rate") {
            const population = estimates.reduce((s,i)=>s+Number(i.population),0), factor=DAYS_PER_YEAR*100000/(7*population);
            expected=estimates.reduce((s,i)=>s+i.expected,0)*factor;
            variance=estimates.some(i=>i.variance==null)?null:estimates.reduce((s,i)=>s+i.variance,0)*factor**2;
            lower=estimates.reduce((s,i)=>s+Number(i.lower||0),0)*factor; upper=estimates.reduce((s,i)=>s+Number(i.upper||0),0)*factor;
          } else {
            expected=estimates.reduce((s,i)=>s+i.expected*DAYS_PER_YEAR*100000/(7*Number(i.population))*Number(i.weight),0);
            variance=estimates.some(i=>i.variance==null)?null:estimates.reduce((s,i)=>{const f=DAYS_PER_YEAR*100000/(7*Number(i.population))*Number(i.weight);return s+i.variance*f*f;},0);
            lower=estimates.reduce((s,i)=>s+Number(i.lower||0)*DAYS_PER_YEAR*100000/(7*Number(i.population))*Number(i.weight),0);
            upper=estimates.reduce((s,i)=>s+Number(i.upper||0)*DAYS_PER_YEAR*100000/(7*Number(i.population))*Number(i.weight),0);
          }
          let lower99=null, upper99=null;
          if (variance != null) { const se=Math.sqrt(Math.max(variance,0)); lower=Math.max(expected-Z95*se,0); upper=expected+Z95*se; lower99=Math.max(expected-Z99*se,0); upper99=expected+Z99*se; }
          const observed=Number(row.observed), outside=observed>upper?observed-upper:observed<lower?observed-lower:0;
          output.push({...row, series:combinedSeries, model_strata:undefined, expected, lower, upper, lower99, upper99,
            excess:observed-expected, outside_deviation:outside, excess_lower:Math.max(observed-upper,0),
            excess_upper:Math.max(observed-expected,0), method, baseline});
        });
      }));
      const withGaps = [];
      const outputBySeries = new Map();
      output.forEach(row => {
        if (!outputBySeries.has(row.series)) outputBySeries.set(row.series, []);
        outputBySeries.get(row.series).push(row);
      });
      outputBySeries.forEach(seriesRows => {
        const sorted = seriesRows.sort((left, right) => left.date.localeCompare(right.date));
        sorted.forEach((row, index) => {
          withGaps.push(row);
          const following = sorted[index + 1];
          if (!following) return;
          const days = (new Date(`${following.date}T00:00:00Z`) - new Date(`${row.date}T00:00:00Z`)) / 86400000;
          if (days > 10) {
            const gapDate = new Date(`${row.date}T00:00:00Z`);
            gapDate.setUTCDate(gapDate.getUTCDate() + 1);
            withGaps.push({...row, date:gapDate.toISOString().slice(0,10), observed:null,
              detail_period:root.morttrCalc.missingLabel});
          }
        });
      });
      return withGaps;
    }
  };
})();
