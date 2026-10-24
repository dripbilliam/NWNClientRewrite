// Run later through run.mjs. No server connections, authored assets only.
const {app,BrowserWindow,session}=require('electron');
const fs=require('node:fs/promises'),syncFs=require('node:fs'),path=require('node:path'),os=require('node:os'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..');
const output=path.resolve(root,process.argv.find(a=>a.startsWith('--output='))?.slice(9)??'runtime-logs/performance-queue/preview-gpu.json');
const allowed=path.join(root,'runtime-logs','performance-queue')+path.sep;
if(!output.toLowerCase().startsWith(allowed.toLowerCase()))throw Error('GPU report must be under runtime-logs/performance-queue');
if(syncFs.existsSync(output))throw Error('Refusing to overwrite GPU report');
const profile=syncFs.mkdtempSync(path.join(os.tmpdir(),'nwn-queued-preview-gpu-'));
for(const key of ['userData','logs','crashDumps'])app.setPath(key,profile);
// Closing the fixture window must not terminate the main process while its
// asynchronous report write is still outstanding.
app.on('window-all-closed',()=>{});
app.whenReady().then(async()=>{
  const report={success:false,joins:0,errors:[],sourceHashes:{},temporaryProfile:profile};let win;
  try {
    await fs.mkdir(path.dirname(output),{recursive:true});
    session.defaultSession.webRequest.onBeforeRequest((details,done)=>done({cancel:/^https?:/.test(details.url)}));
    const main=await fs.readFile(path.join(root,'src/main.js'),'utf8');
    const {extractPreviewFactorySource}=await import('./preview-factory.mjs');
    for(const file of ['src/main.js','src/model_particles.js','src/particle_preview.js','src/prepared_model_geometry.js','scripts/performance-queue/preview-factory.mjs','scripts/performance-queue/preview-gpu.mjs'])report.sourceHashes[file]=crypto.createHash('sha256').update(await fs.readFile(path.join(root,file))).digest('hex');
    win=new BrowserWindow({show:false,width:960,height:640,webPreferences:{sandbox:true,contextIsolation:true,nodeIntegration:false,offscreen:true,backgroundThrottling:false}});
    win.webContents.on('console-message',(_event,level,message)=>{if(level>=3)report.errors.push(message);});
    await win.loadFile(path.join(__dirname,'preview-gpu.html'));
    const js=code=>win.webContents.executeJavaScript(code),deadline=Date.now()+15000;
    while(!await js('typeof runPreviewGpuFixture==="function"')){
      if(report.errors.length||Date.now()>deadline)throw Error('Preview fixture startup failed: '+report.errors.join('; '));
      await new Promise(resolve=>setTimeout(resolve,25));
    }
    report.result=await js(`runPreviewGpuFixture(${JSON.stringify(extractPreviewFactorySource(main))})`);
    report.runtime={versions:process.versions,platform:process.platform,arch:process.arch,gpu:await app.getGPUInfo('basic')};
    if(report.result.screenshot){await fs.writeFile(output.replace(/\.json$/i,'.png'),Buffer.from(report.result.screenshot.split(',')[1],'base64'),{flag:'wx'});delete report.result.screenshot;}
    report.success=report.result.success&&!report.errors.length;
  } catch(error) {report.failure=error.stack;}
  finally {
    win?.destroy();
    await fs.mkdir(path.dirname(output),{recursive:true});await fs.writeFile(output,JSON.stringify(report,null,2)+'\n',{flag:'wx'});
    // The parent runner retires this exact private profile after app.exit,
    // when Chromium has released its database/file locks.
    console.log(JSON.stringify({success:report.success,output,failure:report.failure,errors:report.errors}));app.exit(report.success?0:1);
  }
});
