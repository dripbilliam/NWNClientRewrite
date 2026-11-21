// Deferred authored GPU check. Nothing launches without explicit --run.
const {app,BrowserWindow,session}=require('electron');
const fs=require('node:fs/promises'),syncFs=require('node:fs'),path=require('node:path'),os=require('node:os'),{execFile}=require('node:child_process'),{promisify}=require('node:util'),{createHash}=require('node:crypto');
const root=path.resolve(__dirname,'../..'),args=process.argv.slice(2),outputArgument=args.find(a=>a.startsWith('--output='))?.slice(9);
for(const arg of args)if(arg!=='--run'&&arg!=='--native-legacy'&&!arg.startsWith('--output='))throw Error('Unknown GPU probe option');
if(!args.includes('--run')){console.log('Prepared only: Electron probe-zero-light-work.cjs --run --output=<new runtime-logs/performance-queue/report.json>');app.exit(0);}
else{
 const output=path.resolve(root,outputArgument??''),relative=path.relative(path.join(root,'runtime-logs/performance-queue'),output);
 if(!outputArgument||!relative||relative.startsWith('..')||path.isAbsolute(relative)||!output.endsWith('.json')||syncFs.existsSync(output)||syncFs.existsSync(output.replace(/\.json$/,'.png')))throw Error('Explicit unused report path required');
 const profile=syncFs.mkdtempSync(path.join(os.tmpdir(),'nwn-zero-light-gpu-'));for(const key of ['userData','logs','crashDumps'])app.setPath(key,profile);app.on('window-all-closed',()=>{});
 app.whenReady().then(async()=>{
  const report={success:false,executed:true,scope:'Authored offline GPU color/shadow/cleanup parity; no FPS or live-server claim',errors:[],warnings:[],progress:[],blockedRequests:[],sourceHashes:{}};let win,deadline;
  try{
   const powershell=path.join(process.env.SystemRoot,'System32/WindowsPowerShell/v1.0/powershell.exe'),{stdout}=await promisify(execFile)(powershell,['-NoProfile','-NonInteractive','-Command','Get-CimInstance Win32_Process | Select-Object ProcessId,ParentProcessId,Name | ConvertTo-Json -Compress'],{windowsHide:true});
   const inventory=JSON.parse(stdout),owned=new Set([process.pid]);let changed=true;while(changed){changed=false;for(const p of inventory)if(owned.has(p.ParentProcessId)&&!owned.has(p.ProcessId)){owned.add(p.ProcessId);changed=true;}}
   const games=inventory.filter(p=>['electron.exe','nwmain.exe','nwmain-windows.exe'].includes(p.Name.toLowerCase())&&!owned.has(p.ProcessId));if(games.length)throw Error('Existing games preserved; defer test: '+games.map(p=>p.Name+' PID '+p.ProcessId).join(', '));
   for(const file of ['src/renderer_zero_light_work.js','src/model_light.js','scripts/renderer-zero-light-work-fixture.html','scripts/renderer-zero-light-work-fixture.mjs','scripts/performance-queue/probe-zero-light-work.cjs','node_modules/three/build/three.module.js','node_modules/three/build/three.core.js'])report.sourceHashes[file]=createHash('sha256').update(await fs.readFile(path.join(root,file))).digest('hex');
   session.defaultSession.webRequest.onBeforeRequest((d,done)=>{const external=/^(?:https?|wss?|ftp):/i.test(d.url);if(external)report.blockedRequests.push(new URL(d.url).origin);done({cancel:external});});
   win=new BrowserWindow({show:false,webPreferences:{offscreen:true,backgroundThrottling:false,contextIsolation:true,nodeIntegration:false,sandbox:true}});
   win.webContents.on('console-message',(_e,level,message)=>{if(message.startsWith('NWN_ZERO_LIGHT_PROGRESS ')){const value=JSON.parse(message.slice('NWN_ZERO_LIGHT_PROGRESS '.length));if(report.progress.length<300)report.progress.push({at:Date.now(),...value});return;}if(level>=3)report.errors.push(message);else if(level>=2&&report.warnings.length<20)report.warnings.push(message);});
   await win.loadFile(path.join(root,'scripts/renderer-zero-light-work-fixture.html'));const js=code=>win.webContents.executeJavaScript(code),until=Date.now()+15000;
   while(!await js('typeof window.runZeroLightWorkFixture==="function"')){const failure=await js('window.fixtureFailure');if(failure||Date.now()>until)throw Error(failure??'Fixture startup timeout');await new Promise(r=>setTimeout(r,25));}
   report.nativeLegacy=args.includes('--native-legacy');
   report.result=await Promise.race([js('window.runZeroLightWorkFixture('+JSON.stringify({nativeLegacy:report.nativeLegacy})+')'),new Promise((_,reject)=>{deadline=setTimeout(()=>reject(Error('GPU fixture deadline exceeded')),180000);})]);
   await fs.mkdir(path.dirname(output),{recursive:true});await fs.writeFile(output.replace(/\.json$/,'.png'),Buffer.from(report.result.screenshot.split(',')[1],'base64'),{flag:'wx'});delete report.result.screenshot;
   report.gpuFeatures=app.getGPUFeatureStatus();report.success=report.result.passed&&!report.errors.length&&!report.blockedRequests.length;
  }catch(error){report.failure=error.stack;}
  finally{clearTimeout(deadline);win?.destroy();await fs.mkdir(path.dirname(output),{recursive:true});await fs.writeFile(output,JSON.stringify(report,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:report.success,failure:report.failure,output}));app.exit(report.success?0:1);}
 });
}
