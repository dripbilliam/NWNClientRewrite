// Installed model/texture resources stay in memory; no asset copies written.
// This is a rendered model preview, separate from gameplay impact/cessation.
const {app,BrowserWindow,ipcMain}=require('electron');
const assert=require('node:assert/strict'),fs=require('node:fs/promises'),path=require('node:path'),{pathToFileURL}=require('node:url');
const {registerRuntimeLog,observeWindow,flushOnClose}=require('../electron/runtime_log.cjs');
const workspace=path.resolve(__dirname,'..'),profile=path.join(workspace,`backups/model-particle-profile-${process.pid}`);
app.setPath('userData',profile);app.setPath('logs',profile);app.setPath('crashDumps',profile);
app.whenReady().then(async()=>{
 const log=registerRuntimeLog(ipcMain,path.join(workspace,'runtime-logs')),errors=[];
 const win=new BrowserWindow({show:false,width:1440,height:960,webPreferences:{preload:path.join(workspace,'electron/preload.cjs'),contextIsolation:true,nodeIntegration:false,sandbox:true,offscreen:true,backgroundThrottling:false}});flushOnClose(win,observeWindow(win,log));
 win.webContents.on('console-message',(_event,level,message)=>{if(level>=3)errors.push(message);});
 const evaluate=code=>win.webContents.executeJavaScript(code),wait=async condition=>{const deadline=Date.now()+45000;while(!await evaluate(condition)){if(Date.now()>deadline)throw new Error('Timeout: '+condition+' '+await evaluate(`document.querySelector('#status-text').textContent`));await new Promise(r=>setTimeout(r,50));}};
 try{
  const {openLocalModule}=await import(pathToFileURL(path.join(workspace,'scripts/local-module.mjs'))),{parseModel}=await import(pathToFileURL(path.join(workspace,'src/model_parser.js')));
  const resolver=await openLocalModule('../FullDecomp/NwnRootInstall','../FullDecomp/NwnRootInstall/data/nwm/Prelude.nwm'),name='vce_positive',bytes=await resolver.getResource(name,2002),model=parseModel(bytes),files=[{name:`${name}.mdl`,data:Buffer.from(bytes).toString('base64')}];
  for(const texture of model.materialNames)files.push({name:`${texture}.tga`,data:Buffer.from(await resolver.getResource(texture,3)).toString('base64')});
  await win.loadFile(path.join(workspace,'dist/index.html'));
  await evaluate(`(()=>{const transfer=new DataTransfer();for(const file of ${JSON.stringify(files)})transfer.items.add(new File([Uint8Array.from(atob(file.data),c=>c.charCodeAt(0))],file.name));const input=document.querySelector('#model-file');input.files=transfer.files;input.dispatchEvent(new Event('change'));})()`);
  await wait(`document.querySelector('#status-text').textContent==='MODEL RENDERED'`);
  assert.equal(await evaluate(`document.querySelector('#preview-effects-enabled').checked`),false);
  const crop=await evaluate(`(()=>{const r=document.querySelector('#model-canvas').getBoundingClientRect();return{x:Math.round(r.left+100),y:Math.round(r.top+100),width:Math.round(r.width-200),height:Math.round(r.height-200)};})()`),before=(await win.webContents.capturePage(crop)).toBitmap();
  await evaluate(`{const select=document.querySelector('#animation-clip');select.value='cessation';select.dispatchEvent(new Event('change'));}`);
  await wait(`Number(document.querySelector('#animation-time').dataset.time)>.25&&JSON.parse(document.querySelector('#model-canvas').dataset.modelParticles??'[]').filter(e=>e.active>0&&e.vertices>0&&!e.failed).length===3`);
  const snapshot=await evaluate(`JSON.parse(document.querySelector('#model-canvas').dataset.modelParticles)`);assert.equal(snapshot.length,3);assert.ok(snapshot.every(v=>!v.failed));
  const first=await win.webContents.capturePage();await fs.writeFile(path.join(workspace,'backups/animations/live-model-particles.png'),first.toPNG());
  const bitmap=(await win.webContents.capturePage(crop)).toBitmap();let goldPixels=0;for(let i=0;i<bitmap.length;i+=4)if(bitmap[i+2]>100&&bitmap[i+1]>70&&bitmap[i]<90&&Math.abs(bitmap[i+2]-before[i+2])+Math.abs(bitmap[i+1]-before[i+1])+Math.abs(bitmap[i]-before[i])>50)goldPixels++;
  assert.ok(goldPixels>10,'Authored golden particle vertices must produce colored pixels');
  // Model reload must release old runtimes. Empty input does not select or
  // delete a model; use the same real loader with a fresh model instance.
  await evaluate(`(()=>{const input=document.querySelector('#model-file'),transfer=new DataTransfer();for(const file of ${JSON.stringify(files)})transfer.items.add(new File([Uint8Array.from(atob(file.data),c=>c.charCodeAt(0))],file.name));input.files=transfer.files;input.dispatchEvent(new Event('change'));})()`);
  await wait(`document.querySelector('#animation-time').dataset.playing==='false'&&JSON.parse(document.querySelector('#model-canvas').dataset.modelParticles??'[]').length===3`);
  const reloaded=await evaluate(`JSON.parse(document.querySelector('#model-canvas').dataset.modelParticles)`);assert.ok(reloaded.every(v=>v.active===0&&v.vertices===0&&!v.failed));
  await evaluate('window.flushRuntimeDiagnostics()');const diagnostics=(await fs.readFile(log.path,'utf8')).trim().split('\n').map(JSON.parse);
  await fs.writeFile(path.join(workspace,'backups/animations/live-model-particles.json'),JSON.stringify({model:name,snapshot,reloaded,goldPixels,errors,diagnostics,runtimeLog:path.relative(workspace,log.path),limits:'Installed authored model/clip with native CPU particle owners and active textures; approximate decorative preview disabled. Two Fountains and one Explosion render; the authored detonate event activates the Explosion through model event dispatch. Gameplay visual phases, other handlers and native soft-depth/fog/gamma still open.'},null,2));
  assert.deepEqual(errors,[]);assert.deepEqual(diagnostics.filter(r=>r.code==='particle.runtime-unavailable'),[]);
  assert.deepEqual(diagnostics.filter(r=>r.code==='animation.event-handler-unavailable'),[]);console.log('LIVE AUTHORED FOUNTAIN/EXPLOSION PARTICLES, NATIVE DETONATE EVENT, GPU DRAW AND MODEL RELOAD/CLEANUP PASS',goldPixels);app.exit(0);
 }catch(error){await fs.writeFile(path.join(workspace,'backups/animations/live-model-particles-failed.png'),(await win.webContents.capturePage()).toPNG());console.error(error.stack,errors);app.exit(1);}
});
