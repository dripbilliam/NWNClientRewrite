const path = require('node:path');
const { app, BrowserWindow, ipcMain, dialog } = require('electron');
const {registerNetworkIpc}=require('./network_ipc.cjs');
const { registerRuntimeLog, observeWindow, flushOnClose } = require('./runtime_log.cjs');
let runtimeLog;
let networkIpc;

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
  networkIpc.attach(window);
  flushOnClose(window, observeWindow(window, runtimeLog));
  window.once('ready-to-show', () => window.show());
  window.loadFile(path.join(__dirname, '..', 'dist', 'index.html'));
}

app.whenReady().then(async () => {
  runtimeLog = registerRuntimeLog(ipcMain, path.join(__dirname, '..', 'runtime-logs'));
  const {createInstalledNetworkSession}=await import('./installed_network_session.mjs');
  networkIpc=registerNetworkIpc(ipcMain,{defaultInstall:path.resolve(__dirname,'../../FullDecomp/NwnRootInstall'),userDirectory:path.join(app.getPath('documents'),'Neverwinter Nights'),createSession:createInstalledNetworkSession,
    chooseInstall:async sender=>{const result=await dialog.showOpenDialog(BrowserWindow.fromWebContents(sender),{title:'Select the Neverwinter Nights installation',properties:['openDirectory']});return result.canceled?null:result.filePaths[0];}});
  createWindow();
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
