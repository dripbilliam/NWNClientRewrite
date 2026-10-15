// Interactive development launch. Characters persist in this stable workspace
// profile; installed game files are read through the regular file inputs.
const {app,BrowserWindow,ipcMain}=require('electron');
const path=require('node:path'),fs=require('node:fs');
const {registerRuntimeLog,observeWindow,flushOnClose}=require('../electron/runtime_log.cjs');
const workspace=path.resolve(__dirname,'..'),install=path.resolve(process.argv[2]??path.join(workspace,'../FullDecomp/NwnRootInstall'));
const moduleFile=path.resolve(process.argv[3]??path.join(install,'data/nwm/Prelude.nwm'));
const profile=path.join(workspace,'backups/character-play-profile');fs.mkdirSync(profile,{recursive:true});
app.setPath('userData',profile);app.setPath('logs',profile);app.setPath('crashDumps',profile);
app.whenReady().then(async()=>{
  const log=registerRuntimeLog(ipcMain,path.join(workspace,'runtime-logs'));
  const win=new BrowserWindow({show:false,width:1440,height:960,minWidth:960,minHeight:680,backgroundColor:'#0d141b',
    webPreferences:{preload:path.join(workspace,'electron/preload.cjs'),contextIsolation:true,nodeIntegration:false,sandbox:true,backgroundThrottling:false}});
  win.setMenuBarVisibility(false);flushOnClose(win,observeWindow(win,log));
  win.once('ready-to-show',()=>win.show());
  win.webContents.on('console-message',(_event,level,message)=>{if(level>=3)console.error(message);});
  const evaluate=code=>win.webContents.executeJavaScript(code);
  const wait=async condition=>{const deadline=Date.now()+120000;while(!await evaluate(condition)){if(Date.now()>deadline)throw new Error(`Launch timed out: ${await evaluate("document.querySelector('#status-text').textContent")}`);await new Promise(r=>setTimeout(r,100));}};
  try{
    await win.loadFile(path.join(workspace,'dist/index.html'));console.log('CLIENT LOADED');win.webContents.debugger.attach('1.3');
    const files=async(selector,paths)=>{const {root}=await win.webContents.debugger.sendCommand('DOM.getDocument');const {nodeId}=await win.webContents.debugger.sendCommand('DOM.querySelector',{nodeId:root.nodeId,selector});await win.webContents.debugger.sendCommand('DOM.setFileInputFiles',{nodeId,files:paths});};
    await files('#game-data-folder',[path.join(install,'data')]);await wait(`document.querySelector('#status-text').textContent.startsWith('GAME DATA READY')`);
    console.log('GAME DATA READY');
    const haks=path.join(install,'data/hk');if(fs.existsSync(haks))await files('#hak-data-folder',[haks]);
    await files('#language-data-folder',[path.join(install,'lang/en/data')]);await wait(`document.querySelector('#status-text').textContent==='LANGUAGE DATA READY'`);
    await files('#area-file',[moduleFile]);await wait(`document.querySelector('#character-frontend').dataset.mode==='select'`);
    const count=await evaluate(`document.querySelectorAll('.character-card').length`);
    win.webContents.debugger.detach();win.show();win.focus();
    console.log(`CHARACTER SELECTOR READY · ${count} characters · ${path.basename(moduleFile)}`);
  }catch(error){console.error(error.stack);if(win.webContents.debugger.isAttached())win.webContents.debugger.detach();win.show();win.focus();}
});
app.on('window-all-closed',()=>app.quit());
