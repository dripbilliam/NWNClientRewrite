const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

// The renderer chooses neither a filesystem path nor arbitrary IPC commands.
function createRuntimeLog(directory) {
  fs.mkdirSync(directory, { recursive: true });
  const filename = path.join(directory, `runtime-${new Date().toISOString().replace(/[:.]/g, '-')}-${crypto.randomUUID()}.jsonl`);
  fs.writeFileSync(filename, '', { flag: 'wx' });
  const seen = new Set();
  return { path: filename, append(records) {
    if (!Array.isArray(records) || records.length > 200) throw new Error('Invalid diagnostic batch');
    const lines = [], keys = [];
    for (const record of records) {
      if (record?.version !== 1 || typeof record.session !== 'string' || !Number.isSafeInteger(record.sequence) || record.sequence < 1 || typeof record.code !== 'string' || typeof record.message !== 'string') throw new Error('Invalid diagnostic record');
      const key = `${record.session}:${record.sequence}`, line = JSON.stringify(record);
      if (line.length > 1_000_000) throw new Error('Diagnostic record exceeds size limit');
      if (!seen.has(key)) { lines.push(line); keys.push(key); }
    }
    if (lines.length) {
      const fd = fs.openSync(filename, 'a');
      try { fs.writeFileSync(fd, lines.join('\n') + '\n'); fs.fsyncSync(fd); }
      finally { fs.closeSync(fd); }
      keys.forEach(key => seen.add(key));
    }
    return { written: lines.length };
  } };
}
function registerRuntimeLog(ipcMain, directory) {
  let log;
  try { log = createRuntimeLog(directory); }
  catch (error) { log = { path: path.resolve(directory), append: () => { throw error; }, failure: error }; }
  const trusted = event => { if (!event.senderFrame || event.senderFrame !== event.sender.mainFrame || !event.sender.getURL().startsWith('file:')) throw new Error('Untrusted diagnostic sender'); };
  ipcMain.handle('runtime-log:location', event => { trusted(event); if (log.failure) throw log.failure; return { path: log.path }; });
  ipcMain.handle('runtime-log:append', (event, records) => { trusted(event); return log.append(records); });
  return log;
}
function observeWindow(window, log) {
  let sequence = 0;
  const session = `electron-${crypto.randomUUID()}`;
  const record = (code, message, context = {}) => {
    try { log.append([{ version: 1, session, sequence: ++sequence, timestamp: new Date().toISOString(), code, severity: 'error', message, context }]); }
    catch (error) { console.error('Native diagnostic save failed:', error.message); }
  };
  window.webContents.on('render-process-gone', (_event, details) => record('electron.renderer-gone', `Renderer process ended: ${details.reason}`, details));
  window.webContents.on('did-fail-load', (_event, errorCode, errorDescription, validatedURL, isMainFrame) => {
    if (errorCode !== -3) record('electron.load-failed', errorDescription, { errorCode, validatedURL, isMainFrame });
  });
  return record;
}
function flushOnClose(window, record = () => {}) {
  let flushed = false;
  window.on('close', event => {
    if (flushed || window.webContents.isDestroyed()) return;
    event.preventDefault();
    let timeout;
    Promise.race([window.webContents.executeJavaScript('window.flushRuntimeDiagnostics?.()'), new Promise((_resolve, reject) => { timeout = setTimeout(() => reject(new Error('Renderer diagnostic flush timed out')), 5000); })])
      .catch(error => { record('diagnostic.close-flush-failed', error.message); console.error('Diagnostic close flush failed:', error.message); })
      .finally(() => { clearTimeout(timeout); flushed = true; window.close(); });
  });
}
module.exports = { createRuntimeLog, registerRuntimeLog, observeWindow, flushOnClose };
