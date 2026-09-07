"use strict";

const {spawn} = require("child_process");
const fs = require("fs");
const os = require("os");
const path = require("path");

const url = process.argv[2];
if (!url) throw new Error("usage: node morttr-browser-calc-test.js URL");
const port = 9300 + Math.floor(Math.random() * 500);
const profile = fs.mkdtempSync(path.join(os.tmpdir(), "morttr-browser-test-"));
const chrome = spawn("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", [
  "--headless=new", "--disable-gpu", "--no-first-run", "--disable-component-update",
  `--remote-debugging-port=${port}`, `--user-data-dir=${profile}`, url
], {stdio:"ignore"});

const delay = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds));
const deadline = Date.now() + 180000;

async function target() {
  while (Date.now() < deadline) {
    try {
      const targets = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
      const page = targets.find(item => item.type === "page" && item.url.startsWith("https://medicalfacts.info/morttr2.rb"));
      if (page) return page;
    } catch (_error) {}
    await delay(250);
  }
  throw new Error("Chrome target timeout");
}

async function evaluate(socket, expression) {
  const id = Math.floor(Math.random() * 1e9);
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => reject(new Error("CDP evaluation timeout")), 10000);
    const listener = event => {
      const message = JSON.parse(event.data);
      if (message.id !== id) return;
      clearTimeout(timeout); socket.removeEventListener("message", listener);
      if (message.error) reject(new Error(message.error.message));
      else resolve(message.result.result.value);
    };
    socket.addEventListener("message", listener);
    socket.send(JSON.stringify({id, method:"Runtime.evaluate", params:{expression, returnByValue:true}}));
  });
}

(async () => {
  try {
    const page = await target();
    const socket = new WebSocket(page.webSocketDebuggerUrl);
    await new Promise((resolve, reject) => {
      socket.addEventListener("open", resolve, {once:true});
      socket.addEventListener("error", reject, {once:true});
    });
    let state;
    while (Date.now() < deadline) {
      state = await evaluate(socket, `(() => ({
        text:document.getElementById("morttr-calculation-status")?.textContent || "",
        comparison:window.morttrCalculationComparison || null,
        rendered:!!document.querySelector("#mortyear-vis canvas, #mortyear-vis svg")
      }))()`);
      if (state.text.includes("切り替えました") || state.text.includes("Switched to browser") || state.text.includes("Ruby計算結果")) break;
      await delay(500);
    }
    console.log(JSON.stringify(state));
    if (!state.rendered || !(state.text.includes("切り替えました") || state.text.includes("Switched to browser"))) process.exitCode = 1;
    if (state.comparison && state.comparison.mismatches) process.exitCode = 1;
    socket.close();
  } finally {
    chrome.kill("SIGTERM");
    await delay(500);
    try { fs.rmSync(profile, {recursive:true, force:true, maxRetries:5, retryDelay:200}); } catch (_error) {}
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
