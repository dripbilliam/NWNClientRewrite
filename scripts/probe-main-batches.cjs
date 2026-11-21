const {app,BrowserWindow,session}=require('electron'),fs=require('node:fs/promises'),path=require('node:path'),os=require('node:os');
const root=path.resolve(__dirname,'..'),profile=require('node:fs').mkdtempSync(path.join(os.tmpdir(),'nwn-main-batches-'));for(const k of ['userData','logs','crashDumps'])app.setPath(k,profile);
app.whenReady().then(async()=>{
 let win;const report={success:false,errors:[]};try{
  const crypto=require('node:crypto');report.sourceHashes={};for(const file of ['src/renderer_main_batches.js','src/renderer_palette_arrays.js','src/renderer_local_hooks.js','src/target_preview_shader.js','src/camera_keyhole_shader.js'])report.sourceHashes[file]=crypto.createHash('sha256').update(await fs.readFile(path.join(root,file))).digest('hex');
  const {openServerResourceContext}=await import('../electron/server_resource_context.mjs'),{loadTargetPreviewShader}=await import('../src/target_preview_shader.js'),resolver=await openServerResourceContext({install:path.resolve(root,'../FullDecomp/NwnRootInstall')}),targetShader=await loadTargetPreviewShader(resolver);report.shader={resources:targetShader.resources,cacheKey:targetShader.cacheKey};
  session.defaultSession.webRequest.onBeforeRequest((d,done)=>done({cancel:/^https?:/.test(d.url)}));
  win=new BrowserWindow({show:false,width:1024,height:768,webPreferences:{contextIsolation:true,nodeIntegration:false,sandbox:true,offscreen:true,backgroundThrottling:false}});win.webContents.on('console-message',(_e,level,message)=>{if(level>=3)report.errors.push(message);});await win.loadFile(path.join(__dirname,'main-batches-fixture.html'));
  const js=c=>win.webContents.executeJavaScript(c),end=Date.now()+12000;while(!await js('typeof runMainBatchesFixture==="function"')){const failure=await js('window.fixtureFailure');if(failure||Date.now()>end)throw Error(failure||'Startup timeout');await new Promise(r=>setTimeout(r,25));}
  report.result=await js(`runMainBatchesFixture(${JSON.stringify({targetShader})})`);
  await fs.writeFile(path.join(root,'backups/animations/main-batches-v1.png'),Buffer.from(report.result.screenshot.split(',')[1],'base64'));delete report.result.screenshot;report.success=report.result.success&&!report.errors.length;
 }catch(e){report.failure=e.stack;}finally{await fs.writeFile(path.join(root,'backups/animations/main-batches-v1.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({success:report.success,failure:report.failure,errors:report.errors}));win?.destroy();app.exit(report.success?0:1);}
});
