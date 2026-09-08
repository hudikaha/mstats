"use strict";

const fs = require("fs");
global.window = global;
require("../../web/morttr-calc.js");

const close = (actual, expected, tolerance = 1e-7) => {
  if (!Number.isFinite(actual) || Math.abs(actual - expected) > tolerance * Math.max(1, Math.abs(expected))) {
    throw new Error(`expected ${expected}, got ${actual}`);
  }
};

const annualRows = Array.from({length:21}, (_, index) => {
  const year = 2000 + index;
  return {year, deaths:1000 + index * 10, population:100000 + index * 1000,
    observed:1000, unit_scale:100000, src_url:["test"]};
});
const annual = morttrCalc.calculateAnnual([{series:"test",label:"Test",period:"calendar",
  rows:annualRows,metadata:{loc:"test",category:"death",dcode:"allcause",sex:"both",ages:"age_all"}}],
  {trainingStart:2000});
if (!annual.length) throw new Error("annual result is empty");
annual.filter(row => row.model === "quasi_poisson").forEach(row => {
  close(row.expected, 1000);
  if (!(row.pi99_lower <= row.pi_lower && row.pi99_upper >= row.pi_upper)) throw new Error("invalid 99% interval");
});

const simulated = morttrCalc.calculateAnnualSimulation([{series:"test",label:"Test",period:"calendar",
  rows:annualRows,metadata:{loc:"test",category:"death",dcode:"allcause",sex:"both",ages:"age_all"}}],
  {trainingStart:2000, cutoff:2018, simulations:200, simulationLabel:"Simulation"});
if (simulated.length !== annualRows.length || simulated.some(row => row.interval_method !== "simulation" ||
  row.model !== "poisson" || !(row.pi_lower <= row.pi_upper))) throw new Error("invalid scalar simulation result");

const weeklyRows = [];
for (let year = 2015; year <= 2021; year += 1) {
  for (let week = 1; week <= 52; week += 1) {
    const date = new Date(Date.UTC(year, 0, 4 + (week - 1) * 7));
    const day = date.getUTCDay() || 7;
    date.setUTCDate(date.getUTCDate() + 7 - day);
    weeklyRows.push({series:"test",date:date.toISOString().slice(0,10),observed:100,
      model_strata:[{age:"combined",deaths:100,population:1,weight:1}],detail_period:"Week"});
  }
}
const weekly = morttrCalc.calculateWeekly(weeklyRows,
  [["five_year","fixed_2015_2019"],["farrington","fixed_2015_2019"],["euromomo","fixed_2015_2019"]], "deaths");
for (const method of ["five_year", "farrington", "euromomo"]) {
  const result = weekly.find(row => row.series === `test--${method}--fixed_2015_2019` && row.expected != null);
  if (!result) throw new Error(`${method} result is empty`);
  close(result.expected, 100, 1e-5);
}

if (process.argv[2]) {
  const html = fs.readFileSync(process.argv[2], "utf8");
  const extract = (left, right) => {
    const start = html.indexOf(left);
    const end = html.indexOf(right, start + left.length);
    if (start < 0 || end < 0) throw new Error(`cannot find ${left}`);
    return JSON.parse(html.slice(start + left.length, end).trim().replace(/;$/, ""));
  };
  const rubyValues = extract("const rubyValues = ", "\n  const calculationInputs");
  const inputs = extract("const calculationInputs = ", "\n  const calculationEngine");
  const weeklySource = extract("const weeklyCalculationInputs = ", "\n  const weeklyCalculationCombinations");
  const combinations = extract("const weeklyCalculationCombinations = ", "\n  const overlayValues");
  const weeklyMode = /const primaryWeekly = true;/.test(html);
  const actual = weeklyMode ? morttrCalc.calculateWeekly(weeklySource, combinations,
    JSON.parse(html.match(/calculateWeekly\(weeklyCalculationInputs, weeklyCalculationCombinations, ("[^"]+")\)/)[1])) :
    morttrCalc.calculateAnnual(inputs, {trainingStart:Number(html.match(/trainingStart: (\d+)/)[1])});
  const reference = weeklyMode ? extract("let weeklyValues = ", "\n  const weeklyCalculationInputs") :
    rubyValues.filter(row => row.interval_method === "analytic");
  const fields = weeklyMode ? ["observed","expected","lower","upper","lower99","upper99","excess","outside_deviation","excess_lower","excess_upper"] :
    ["observed","expected","pi_lower","pi_upper","pi99_lower","pi99_upper","dispersion"];
  const key = weeklyMode ? row => `${row.series}|${row.date}` : row => `${row.series}|${row.model}|${row.train_to}|${row.year}|${row.interval_method}`;
  const referenceByKey = new Map(reference.map(row => [key(row), row]));
  let compared = 0, mismatches = 0, maxDifference = 0;
  actual.forEach(row => {
    const expected = referenceByKey.get(key(row));
    if (!expected) { mismatches += 1; return; }
    compared += 1;
    fields.forEach(field => {
      if (row[field] == null && expected[field] == null) return;
      const difference = Math.abs(Number(row[field]) - Number(expected[field]));
      maxDifference = Math.max(maxDifference, difference);
      if (!Number.isFinite(difference) || difference > 1e-7 * Math.max(1, Math.abs(Number(expected[field])))) mismatches += 1;
    });
  });
  console.log(JSON.stringify({weeklyMode, compared, mismatches, maxDifference}));
  if (!compared || mismatches) process.exitCode = 1;
}

console.log("morttr-calc-test: OK");
