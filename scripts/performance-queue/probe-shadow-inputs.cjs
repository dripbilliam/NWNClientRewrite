const {app,BrowserWindow,session}=require('electron');
const fs=require('node:fs/promises'),syncFs=require('node:fs'),path=require('node:path'),os=require('node:os');
const root=path.resolve(__dirname,'../..'),argument=process.argv.find(arg=>arg.startsWith('--output='))?.slice(9);
if(!argument)throw Error('Explicit report path required');
const output=path.resolve(root,argument),parent=path.join(root,'runtime-logs/performance-queue')+path.sep;
if(!output.toLowerCase().startsWith(parent.toLowerCase())||syncFs.existsSync(output))throw Error('Invalid/existing report path');
const profile=syncFs.mkdtempSync(path.join(os.tmpdir(),'nwn-shadow-inputs-gpu-'));for(const key of ['userData','logs','crashDumps'])app.setPath(key,profile);
app.on('window-all-closed',()=>{});
app.whenReady().then(async()=>{
 const report={success:false,scope:'Offline exact color and six-face shadow parity; no server connection',temporaryProfile:profile,errors:[],modes:[]};let win;
 try {
  session.defaultSession.webRequest.onBeforeRequest((details,done)=>done({cancel:/^https?:/.test(details.url)}));
  await fs.mkdir(path.dirname(output),{recursive:true});
  win=new BrowserWindow({show:false,webPreferences:{offscreen:true,backgroundThrottling:false,contextIsolation:true,nodeIntegration:false,sandbox:true}});
  win.webContents.on('console-message',(_event,level,message)=>{if(level>=3)report.errors.push(message);});
  await win.loadFile(path.join(root,'scripts/renderer-shadow-cache-fixture.html'));
  const js=code=>win.webContents.executeJavaScript(code),deadline=Date.now()+15000;
  while(!await js('typeof window.runShadowCacheFixture==="function"')){const error=await js('window.fixtureFailure');if(error||Date.now()>deadline)throw Error(error??'Fixture did not initialize');await new Promise(resolve=>setTimeout(resolve,25));}
  for(const enabled of [false,true]){
   const result=await js('window.runShadowCacheFixture({shortCircuitVolatile:'+enabled+'})');
   await fs.writeFile(output.replace(/\.json$/i,'-'+enabled+'.png'),Buffer.from(result.screenshot.split(',')[1],'base64'),{flag:'wx'});delete result.screenshot;
   if(!result.passed||result.shortCircuitVolatile!==enabled||result.results.length<19)throw Error('GPU fixture did not exercise both modes');report.modes.push(result);
  }
  if(report.errors.length)throw Error('Renderer errors');report.success=true;
 }catch(error){report.failure=error.stack;}
 finally{await fs.mkdir(path.dirname(output),{recursive:true});await fs.writeFile(output,JSON.stringify(report,null,2)+'\n',{flag:'wx'});win?.destroy();console.log(JSON.stringify({success:report.success,modes:report.modes.map(row=>({enabled:row.shortCircuitVolatile,cases:row.results.length})),failure:report.failure}));app.exit(report.success?0:1);}
});
