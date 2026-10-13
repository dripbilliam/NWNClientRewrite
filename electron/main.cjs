const path = require('node:path');
const { app, BrowserWindow, ipcMain } = require('electron');
const { registerRuntimeLog, observeWindow, flushOnClose } = require('./runtime_log.cjs');
let runtimeLog;

function createWindow() {
  const window = new BrowserWindow({
    width: 1440,
    height: 960,
    x: 100,
    y: 80,
    minWidth: 960,
    minHeight: 680,
    backgroundColor: '#e9ece5',
    show: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.cjs'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true
    }
  });

  window.setMenuBarVisibility(false);
  flushOnClose(window, observeWindow(window, runtimeLog));
  window.once('ready-to-show', () => window.show());
  window.loadFile(path.join(__dirname, '..', 'dist', 'index.html'));
}

app.whenReady().then(() => {
  runtimeLog = registerRuntimeLog(ipcMain, path.join(__dirname, '..', 'runtime-logs'));
  createWindow();
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
