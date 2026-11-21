const path = require('node:path');
const { app, BrowserWindow, ipcMain, dialog, safeStorage } = require('electron');
const {registerNetworkIpc}=require('./network_ipc.cjs');
const { registerRuntimeLog, observeWindow, flushOnClose } = require('./runtime_log.cjs');
let runtimeLog;
let networkIpc;
let debugWindows;
let modelCache;
let sceneCapture;
const applicationBuild=require('./application_build.cjs').resolveApplicationBuild(path.resolve(__dirname,'..'));

function createWindow() {
  const recording=process.argv.includes('--record-scene');
  const window = new BrowserWindow({
    title:recording?'Neverwinter Nights - SCENE RECORDING':'Neverwinter Nights',
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
  debugWindows.attach(window);
  flushOnClose(window, observeWindow(window, runtimeLog));
  if(recording)window.on('page-title-updated',event=>{event.preventDefault();window.setTitle('Neverwinter Nights - SCENE RECORDING');});
  window.once('ready-to-show', () => {window.show();if(recording){window.restore();window.focus();}});
  window.loadFile(applicationBuild.index);
}

app.whenReady().then(async () => {
  if(process.argv.includes('--record-scene')){const {SceneCapture}=await import('./scene_capture.mjs');sceneCapture=new SceneCapture({directory:path.join(app.getPath('userData'),'scene-captures')});}
  debugWindows=require('./debug_window.cjs').registerDebugWindows({ipcMain,BrowserWindow,root:path.join(__dirname,'..'),applicationUrl:applicationBuild.applicationUrl});
  runtimeLog = registerRuntimeLog(ipcMain, path.join(__dirname, '..', 'runtime-logs'));
  const {createInstalledNetworkSession}=await import('./installed_network_session.mjs');
  const {NetworkCharacterVault}=await import('./network_character_vault.mjs');
  const {PreparedModelCache}=await import('./prepared_model_cache.mjs');modelCache=new PreparedModelCache({directory:path.join(app.getPath('userData'),'prepared-models')});
  const {ClientSettings,defaultModsDirectory}=await import('./client_settings.mjs'),install=path.resolve(__dirname,'../../FullDecomp/NwnRootInstall'),clientSettings=new ClientSettings({directory:app.getPath('userData'),encryption:safeStorage,modsDirectory:await defaultModsDirectory(install)});
  networkIpc=registerNetworkIpc(ipcMain,{applicationUrl:applicationBuild.applicationUrl,defaultInstall:install,clientSettings,modelCache,chooseMods:async sender=>{const current=await clientSettings.status(),result=await dialog.showOpenDialog(BrowserWindow.fromWebContents(sender),{title:'Select the Neverwinter Nights mods folder',defaultPath:current.modsDirectory||undefined,properties:['openDirectory']});return result.canceled?null:result.filePaths[0];},userDirectory:path.join(app.getPath('documents'),'Neverwinter Nights'),cacheDirectory:path.join(app.getPath('userData'),'server-content'),createSession:createInstalledNetworkSession,characterVault:new NetworkCharacterVault(path.join(app.getPath('userData'),'network-characters')),
    sceneCapture,chooseInstall:async sender=>{const result=await dialog.showOpenDialog(BrowserWindow.fromWebContents(sender),{title:'Select the Neverwinter Nights installation',properties:['openDirectory']});return result.canceled?null:result.filePaths[0];}});
  createWindow();
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
app.on('before-quit',()=>{void modelCache?.dispose();});
let captureQuitting=false;
app.on('before-quit',event=>{if(sceneCapture&&!captureQuitting){event.preventDefault();captureQuitting=true;void sceneCapture.close().finally(()=>app.quit());}});
