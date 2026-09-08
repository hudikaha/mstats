"use strict";

importScripts("morttr-calc.js");

self.addEventListener("message", event => {
  try {
    const {inputs, options} = event.data;
    const values = self.morttrCalc.calculateAnnualSimulation(inputs, options);
    self.postMessage({values, cutoff:options.cutoff});
  } catch (error) {
    self.postMessage({error:String(error?.stack || error), cutoff:event.data?.options?.cutoff});
  }
});
