const {app,BrowserWindow,ipcMain,session}=require('electron');
const fs=require('node:fs/promises'),path=require('node:path'),os=require('node:os'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..'),profile=require('node:fs').mkdtempSync(path.join(os.tmpdir(),'nwn-highlight-main-'));
const buildArgument=process.argv.find(argument=>argument.startsWith('--build='))?.slice(8),build=path.resolve(root,buildArgument??'dist');
if(build!==path.join(root,'dist')&&!build.startsWith(path.join(root,'backups','animations')+path.sep))throw Error('Build fixture must remain in the workspace artifact directory');
const reportName=process.argv.find(argument=>argument.startsWith('--report='))?.slice(9)??(buildArgument?'shadow-preparation-main-v1':'creation-experience-world-highlight-main-v1');if(!/^[a-z0-9-]+$/.test(reportName))throw Error('Invalid boot report name');
for(const key of ['userData','logs','crashDumps'])app.setPath(key,profile);
app.whenReady().then(async()=>{
 const report={scope:'Built production renderer and preload boot with isolated profile; no joins or external fetches',joins:0,fetches:0,errors:[]};let win;
 try{
  global.fetch=()=>{report.fetches++;throw Error('External fetch forbidden in this boot fixture');};
  session.defaultSession.webRequest.onBeforeRequest((details,callback)=>callback({cancel:/^https?:/.test(details.url)}));
  const controller=require('../electron/network_ipc.cjs').registerNetworkIpc(ipcMain,{defaultInstall:path.resolve(root,'../FullDecomp/NwnRootInstall'),userDirectory:null,chooseInstall:async()=>null,createSession:async()=>{report.joins++;throw Error('No server connection allowed');}});
  require('../electron/runtime_log.cjs').registerRuntimeLog(ipcMain,path.join(root,'runtime-logs'));
  const debug=require('../electron/debug_window.cjs').registerDebugWindows({ipcMain,BrowserWindow,root});
  win=new BrowserWindow({show:false,width:1440,height:960,webPreferences:{preload:path.join(root,'electron/preload.cjs'),contextIsolation:true,nodeIntegration:false,sandbox:true,offscreen:true,backgroundThrottling:false}});controller.attach(win);debug.attach(win);
  win.webContents.on('console-message',(_e,level,message)=>{if(level>=3&&!message.includes('fonts.googleapis'))report.errors.push(message);});
  await win.loadFile(path.join(build,'index.html'));
  const js=code=>win.webContents.executeJavaScript(code),deadline=Date.now()+20000;
  while(!await js('document.querySelectorAll(".world-highlight-labels").length===1&&Boolean(document.querySelector("canvas")?.dataset.frameTimings)')){if(Date.now()>deadline)throw Error('Production frame and highlight owner not initialized');await new Promise(resolve=>setTimeout(resolve,25));}
  report.bundle=(await fs.readFile(path.join(build,'index.html'),'utf8')).match(/src="\.\/assets\/([^"\s]+\.js)"/)?.[1];
  report.modelPreparation=await js('JSON.parse(document.querySelector("#model-canvas").dataset.rendererModelPreparation??"null")');
  report.matrixSubtrees=await js('JSON.parse(document.querySelector("#model-canvas").dataset.matrixSubtrees??"null")');
  if(process.argv.includes('--expect-subtree-disabled'))assert.deepEqual(report.matrixSubtrees,{enabled:false,owners:0,nodes:0,walks:0,skipped:0});
  if(process.argv.includes('--expect-normal-performance')){
   report.mainBatches=await js('JSON.parse(document.querySelector("#model-canvas").dataset.rendererMainBatches??"null")');
   assert.equal(report.mainBatches.enabled,false);
   report.comparisonHooks=await js('Object.fromEntries(["setBatchPoolForTest","setRenderScaleForTest","batchPoolFrameSamplesForTest","batchPoolAuditForTest","setScalarPoseTransferForTest","setWorldPickingForTest","setPersistentModelPrepForTest"].map(key=>[key,typeof window[key]]))');
   assert.ok(Object.values(report.comparisonHooks).every(value=>value==='undefined'));
  }
  if(process.argv.includes('--expect-model-cache-disabled')){report.persistentModelPreparation=await js('document.querySelector("#model-canvas").dataset.persistentModelPreparation');assert.equal(report.persistentModelPreparation,'false');}
  report.rendererAndHighlightReady=true;assert.equal(report.joins,0);assert.equal(report.fetches,0);assert.deepEqual(report.errors,[]);report.success=true;
 }catch(error){report.success=false;report.failure=error.stack;}
 finally{await fs.writeFile(path.join(root,'backups/animations/'+reportName+'.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));if(win){await win.loadURL('about:blank');win.destroy();}app.exit(report.success?0:1);}
});
