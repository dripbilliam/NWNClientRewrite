const {app,BrowserWindow,ipcMain,session}=require('electron');
const fs=require('node:fs/promises'),syncFs=require('node:fs'),path=require('node:path'),os=require('node:os'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),arg=name=>process.argv.find(value=>value.startsWith('--'+name+'='))?.slice(name.length+3);
const selected=require('../../electron/application_build.cjs').resolveApplicationBuild(root,['--client-build='+arg('build')]);
const output=path.resolve(root,arg('output')??'runtime-logs/performance-queue/live-smoke.json');
if(!output.toLowerCase().startsWith((path.join(root,'runtime-logs/performance-queue')+path.sep).toLowerCase())||syncFs.existsSync(output))throw Error('Invalid existing smoke output');
const profile=syncFs.mkdtempSync(path.join(os.tmpdir(),'nwn-live-performance-smoke-'));for(const key of ['userData','logs','crashDumps'])app.setPath(key,profile);
app.on('window-all-closed',()=>{});
app.whenReady().then(async()=>{
 const report={success:false,joins:0,fetches:0,blockedRequests:[],errors:[],applicationUrl:selected.applicationUrl,temporaryProfile:profile};let win,controller,sceneCapture;
 try {
  if(process.argv.includes('--record')){const {SceneCapture}=await import('../../electron/scene_capture.mjs');sceneCapture=new SceneCapture({directory:path.join(profile,'captures')});}
  await fs.mkdir(path.dirname(output),{recursive:true});
  session.defaultSession.webRequest.onBeforeRequest((details,done)=>{if(/^https?:/.test(details.url)){report.fetches++;const url=new URL(details.url);report.blockedRequests.push(url.origin+url.pathname);}done({cancel:/^https?:/.test(details.url)});});
  controller=require('../../electron/network_ipc.cjs').registerNetworkIpc(ipcMain,{applicationUrl:selected.applicationUrl,defaultInstall:path.resolve(root,'../FullDecomp/NwnRootInstall'),userDirectory:null,sceneCapture,chooseInstall:async()=>null,createSession:async()=>{report.joins++;throw Error('Offline startup only');}});
  require('../../electron/runtime_log.cjs').registerRuntimeLog(ipcMain,path.join(root,'runtime-logs'));
  const debug=require('../../electron/debug_window.cjs').registerDebugWindows({ipcMain,BrowserWindow,root,applicationUrl:selected.applicationUrl});
  win=new BrowserWindow({show:false,width:1440,height:960,webPreferences:{preload:path.join(root,'electron/preload.cjs'),sandbox:true,contextIsolation:true,nodeIntegration:false,offscreen:true,backgroundThrottling:false}});controller.attach(win);debug.attach(win);
  win.webContents.on('console-message',(_event,level,message)=>{if(level>=3)report.errors.push(message);});await win.loadFile(selected.index);
  const js=code=>win.webContents.executeJavaScript(code),deadline=Date.now()+15000,pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
  while(!await js('typeof window.performanceCandidatesForTest?.snapshot==="function"')){if(report.errors.length||Date.now()>deadline)throw Error('Live diagnostics failed to initialize');await pause(25);}
  const capture=()=>js('({snapshot:window.performanceCandidatesForTest.snapshot(),audit:window.gameplayPreviewAuditForTest(),controls:document.querySelectorAll("[data-candidate]").length})');
  await pause(300);report.candidates=await capture();await js('window.performanceCandidatesForTest.setProfile("baseline")');await pause(300);report.baseline=await capture();await js('window.performanceCandidatesForTest.setProfile("candidates")');await pause(300);report.restored=await capture();
  const expectedControls=(await import('../performance-candidates/live-performance-profile.mjs')).performanceCandidateDefinitions.length;
  for(const [name,enabled]of [['candidates',true],['baseline',false],['restored',true]]){const row=report[name];if(row.controls!==expectedControls||Object.values(row.snapshot.flags).some(flag=>flag!==enabled)||row.audit.omit!==enabled||row.audit.persistentModelPreparation!==enabled||row.audit.mainBatches!==enabled||row.audit.matrixSubtrees!==enabled)throw Error('Live candidate/baseline state mismatch: '+name);}
  if(sceneCapture){const end=Date.now()+5000;while(!await js('Array.from(document.querySelectorAll("button")).some(b=>b.textContent==="Finish recording"&&!b.parentElement.hidden)')){if(Date.now()>end)throw Error('Capture controls did not appear');await pause(25);}await js('Array.from(document.querySelectorAll("button")).find(b=>b.textContent==="Finish recording").click()');while(!sceneCapture.sealed){if(Date.now()>end)throw Error('Capture did not seal');await pause(25);}report.capture=sceneCapture.status();if(!report.capture.sealed||report.capture.failure)throw Error('Offline capture seal failed');}
  report.mainMenu=await js('document.querySelector(".network-lobby[data-screen=main]")?.hidden===false');if(!report.mainMenu)throw Error('Main Menu did not open');
  const image=await win.webContents.capturePage();await fs.writeFile(output.replace(/\.json$/i,'.png'),image.toPNG(),{flag:'wx'});report.bundleSha256=crypto.createHash('sha256').update(await fs.readFile(path.join(selected.directory,'index.html'))).digest('hex');
  // The existing stylesheet imports Google Fonts. Keep that request blocked;
  // it is an expected font attempt, never a server join or network response.
  report.success=!report.errors.length&&!report.joins&&report.blockedRequests.every(url=>url==='https://fonts.googleapis.com/css2');
 }catch(error){report.failure=error.stack;}
 finally{await sceneCapture?.close();await fs.mkdir(path.dirname(output),{recursive:true});await fs.writeFile(output,JSON.stringify(report,null,2)+'\n',{flag:'wx'});win?.destroy();console.log(JSON.stringify({success:report.success,failure:report.failure,errors:report.errors,joins:report.joins,fetches:report.fetches}));app.exit(report.success?0:1);}
});
