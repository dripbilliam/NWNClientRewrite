import { runtimeDiagnostics as log, diagnosticJson } from './runtime_diagnostics.js';
let storedBrowserLogs = null;
function downloadLog(contents, filename) {
  const url = URL.createObjectURL(new Blob([contents], { type: 'application/x-ndjson' }));
  const link = document.createElement('a'); link.href = url; link.download = filename; link.click(); setTimeout(() => URL.revokeObjectURL(url), 1000);
}

export async function attachDiagnosticStorage(bridge = globalThis.runtimeLog, indexedDB = globalThis.indexedDB) {
  try {
    if (bridge) {
      const { path } = await bridge.location();
      await log.attach(records => bridge.append(records), path);
    } else {
      const db = await new Promise((resolve, reject) => {
        const request = indexedDB.open('nwn-runtime-diagnostics', 1);
        request.onupgradeneeded = () => request.result.createObjectStore('records', { keyPath: ['session', 'sequence'] });
        request.onsuccess = () => resolve(request.result); request.onerror = () => reject(request.error);
        request.onblocked = () => reject(new Error('Diagnostic database upgrade is blocked by another window'));
      });
      await log.attach(records => new Promise((resolve, reject) => {
        const transaction = db.transaction('records', 'readwrite');
        for (const record of records) transaction.objectStore('records').put(record);
        transaction.oncomplete = resolve; transaction.onerror = transaction.onabort = () => reject(transaction.error ?? new Error('Diagnostic transaction aborted'));
      }), 'Browser database · nwn-runtime-diagnostics');
      storedBrowserLogs = () => new Promise((resolve, reject) => {
        const transaction = db.transaction('records', 'readonly'), request = transaction.objectStore('records').getAll();
        request.onsuccess = () => resolve(request.result); request.onerror = () => reject(request.error);
      });
      const historyButton = document.querySelector('#diagnostic-history-export'); if (historyButton) historyButton.hidden = false;
    }
  } catch (error) { log.storageError = error.message; log.record('diagnostic.storage-unavailable', error.message, {}, 'error'); log.publish(); }
}

export function installDiagnosticReporting() {
  const original = { warn: console.warn.bind(console), error: console.error.bind(console), info: console.info.bind(console) };
  for (const level of ['warn', 'error', 'info']) console[level] = (...args) => {
    original[level](...args);
    const prefix = String(args[0]);
    // These domains already record the Error object with precise metadata.
    if (/^\[(NWScript|Audio|UI asset)\]/.test(prefix)) return;
    if (level === 'info' && !prefix.includes('placeholder')) return;
    const error = args.find(arg => arg instanceof Error);
    if (error) log.error(error, `console.${level}`, { source: prefix === String(error) ? undefined : prefix });
    else log.record(prefix.includes('placeholder') ? 'interaction.unimplemented' : `console.${level}`,
      args.map(arg => typeof arg === 'string' ? arg : diagnosticJson(arg)).join(' '),
      prefix.includes('placeholder') ? { request: args[1] } : {}, level === 'error' ? 'error' : 'warning');
  };
  window.addEventListener('error', event => log.error(event.error ?? event.message, 'runtime.uncaught', { source: event.filename, line: event.lineno, column: event.colno }));
  window.addEventListener('unhandledrejection', event => log.error(event.reason, 'runtime.unhandled-rejection'));
  // Main-process close waits for this hook before closing the window.
  window.flushRuntimeDiagnostics = () => log.flush();
  void attachDiagnosticStorage();
  const status = document.querySelector('#diagnostic-status');
  const recent = document.querySelector('#diagnostic-recent');
  log.subscribe(journal => {
    status.textContent = `${journal.records.length} recorded · ${journal.pending.length} pending\n${journal.location}${journal.storageError ? `\nSAVE FAILED: ${journal.storageError} · export preserves the session` : ''}`;
    status.dataset.count = String(journal.records.length); status.dataset.pending = String(journal.pending.length);
    status.dataset.path = journal.location; status.dataset.storageError = journal.storageError ?? '';
    recent.textContent = journal.records.slice(-6).reverse().map(r => `${r.code}: ${r.message}`).join('\n');
  });
  document.querySelector('#diagnostic-export').addEventListener('click', () => {
    downloadLog(log.jsonl(), `nwn-diagnostics-${log.session}.jsonl`);
  });
  document.querySelector('#diagnostic-history-export').addEventListener('click', async () => {
    try { await log.flush(); const records = await storedBrowserLogs(); downloadLog(records.map(record => JSON.stringify(record)).join('\n') + '\n', 'nwn-saved-diagnostics.jsonl'); }
    catch (error) { log.error(error, 'diagnostic.export-failed'); }
  });
  document.querySelector('#diagnostic-retry').addEventListener('click', () => { void (log.sink ? log.flush() : attachDiagnosticStorage()).catch(() => {}); });
}
