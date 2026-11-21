const {app,BrowserWindow,ipcMain}=require('electron');
const assert=require('node:assert/strict'),fs=require('node:fs/promises'),path=require('node:path');
const {registerRuntimeLog,observeWindow,flushOnClose}=require('../electron/runtime_log.cjs');
const checkTransfer=process.argv.includes('--check-transfer');
const workspace=path.resolve(__dirname,'..'),install=path.resolve('../FullDecomp/NwnRootInstall'),profile=path.join(workspace,`backups/live-casting-ui-profile-${process.pid}`);
app.setPath('userData',profile);app.setPath('logs',profile);app.setPath('crashDumps',profile);
app.whenReady().then(async()=>{
 const log=registerRuntimeLog(ipcMain,path.join(workspace,'runtime-logs'));
 const win=new BrowserWindow({show:false,width:1440,height:960,webPreferences:{preload:path.join(workspace,'electron/preload.cjs'),contextIsolation:true,nodeIntegration:false,sandbox:true,offscreen:true,backgroundThrottling:false}});flushOnClose(win,observeWindow(win,log));
 const errors=[];win.webContents.on('console-message',(_e,level,message)=>{if(level>=3)errors.push(message);});
 const evaluate=code=>win.webContents.executeJavaScript(code),wait=async condition=>{const deadline=Date.now()+90000;while(!await evaluate(condition)){if(Date.now()>deadline)throw new Error('Timeout: '+condition+'\n'+await evaluate(`document.body.innerText.slice(-2000)`));await new Promise(r=>setTimeout(r,100));}};
 const point=selector=>evaluate(`{const r=document.querySelector(${JSON.stringify(selector)}).getBoundingClientRect();({x:Math.round(r.left+r.width/2),y:Math.round(r.top+r.height/2)});}`);
 const click=async(selector,button='left')=>{const p=await point(selector);for(const type of ['mousePressed','mouseReleased'])await win.webContents.debugger.sendCommand('Input.dispatchMouseEvent',{type,...p,button,clickCount:1});};
 const files=async(selector,paths)=>{const {root}=await win.webContents.debugger.sendCommand('DOM.getDocument'),{nodeId}=await win.webContents.debugger.sendCommand('DOM.querySelector',{nodeId:root.nodeId,selector});await win.webContents.debugger.sendCommand('DOM.setFileInputFiles',{nodeId,files:paths});};
 const key=async(type,key,code,windowsVirtualKeyCode)=>win.webContents.debugger.sendCommand('Input.dispatchKeyEvent',{type,key,code,windowsVirtualKeyCode,modifiers:type==='keyDown'?(key==='Control'?2:key==='Shift'?8:0):0});
 const open=async panel=>{await evaluate(`{const s=document.querySelector('#ui-panel-select');s.value=${JSON.stringify(panel)};s.dispatchEvent(new Event('change'));}`);await wait(`document.querySelector('#game-ui').dataset.panel===${JSON.stringify(panel)}`);};
 const buttons=()=>evaluate(`JSON.parse(document.querySelector('#game-ui').dataset.quickbar)`);
 const drag=async(source,slot)=>evaluate(`(()=>{const source=document.querySelector(${JSON.stringify(source)}),target=document.querySelector('.game-quick-slot[data-slot="${slot}"]'),data=new DataTransfer();source.dispatchEvent(new DragEvent('dragstart',{bubbles:true,dataTransfer:data}));const payload=JSON.parse(data.getData('application/x-nwn-quickbar'));target.dispatchEvent(new DragEvent('dragover',{bubbles:true,cancelable:true,dataTransfer:data}));target.dispatchEvent(new DragEvent('drop',{bubbles:true,cancelable:true,dataTransfer:data}));return payload;})()`);
 const load=async()=>{await files('#game-data-folder',[path.join(install,'data')]);await wait(`document.querySelector('#status-text').textContent.startsWith('GAME DATA READY')`);await files('#language-data-folder',[path.join(install,'lang/en/data')]);await wait(`document.querySelector('#status-text').textContent==='LANGUAGE DATA READY'`);await files('#area-file',[path.join(install,'data/nwm/Prelude.nwm')]);await wait(`document.querySelector('#character-frontend').dataset.mode==='select'`);await evaluate(`{[...document.querySelectorAll('.character-card')].find(b=>b.textContent.includes('wizard.bic')).click();document.querySelector('#run-module-startup').checked=false;[...document.querySelectorAll('#character-frontend button')].find(b=>b.textContent==='Play').click();}`);await wait(`document.querySelector('#status-text').textContent.includes('AREA RENDERED')`);};
 try{
  await win.loadFile(path.join(workspace,'dist/index.html'));win.webContents.debugger.attach('1.3');
  // The same in-memory entry fixture as smoke-viewer: no installed asset
  // writes. Keep the caster visible on the library floor with startup off.
  await evaluate(`{
   const input=document.querySelector('#area-file');input.addEventListener('change',async function override(event){
    event.stopImmediatePropagation();input.removeEventListener('change',override,true);
    const file=input.files[0],bytes=new Uint8Array(await file.arrayBuffer()),v=new DataView(bytes.buffer),text=(o,n)=>new TextDecoder().decode(bytes.subarray(o,o+n)).replace(/\\0.*$/,'');
    const count=v.getUint32(16,true),keys=v.getUint32(24,true),resources=v.getUint32(28,true),stride=text(4,4)==='V1.0'||(resources-keys)/count<40?24:40,names=stride===40?32:16;
    let base=-1;for(let i=0;i<count;i++){const k=keys+i*stride;if(v.getUint16(k+names+4,true)===2014){base=v.getUint32(resources+v.getUint32(k+names,true)*8,true);break;}}
    if(base<0)throw new Error('Fixture IFO unavailable');const fields=base+v.getUint32(base+16,true),labels=base+v.getUint32(base+24,true),data=base+v.getUint32(base+32,true),values={Mod_Entry_X:24,Mod_Entry_Y:14,Mod_Entry_Z:0};
    for(let i=0;i<v.getUint32(base+20,true);i++){const f=fields+i*12,label=text(labels+v.getUint32(f+4,true)*16,16);if(Object.hasOwn(values,label))v.setFloat32(f+8,values[label],true);else if(label==='Mod_Entry_Area'){const o=data+v.getUint32(f+8,true);bytes.set(new TextEncoder().encode('m0q1a'),o+1);}}
    const transfer=new DataTransfer();transfer.items.add(new File([bytes],file.name));input.files=transfer.files;input.dispatchEvent(new Event('change'));
   },true);
  }`);
  await load();await key('keyDown','f','KeyF',70);await key('keyUp','f','KeyF',70);
  const canvas='#model-canvas',snapshot=()=>evaluate(`JSON.parse(document.querySelector('${canvas}').dataset.creatureAnimations)`),player=()=>evaluate(`Number(document.querySelector('${canvas}').dataset.actorId)`);
  const events=[];
  const capture=async()=>{const value=await snapshot();for(const e of value.events)if(!events.some(v=>v.objectId===e.objectId&&v.at===e.at&&v.animation===e.animation))events.push(e);return value;};
  const selfTarget=async()=>{
   for(let n=0;n<35;n++){
    const o=(await snapshot()).actors.find(a=>a.id===awaitedPlayer),anchor=o.screen;
    assert.ok(anchor);const point={x:Math.round(anchor.x+(n%5-2)*6),y:Math.round(anchor.y+(Math.floor(n/5)-3)*6)};
    for(const type of ['mousePressed','mouseReleased'])await win.webContents.debugger.sendCommand('Input.dispatchMouseEvent',{type,...point,button:'left',clickCount:1});
    if(!await evaluate(`document.querySelector('${canvas}').dataset.spellTarget`))return;
   }
   throw new Error('Could not select the player as the spell target');
  };
  const awaitedPlayer=await player();
  const chooseWheel=async slot=>{await key('keyDown',String(slot+1),`Digit${slot+1}`,49+slot);await key('keyUp',String(slot+1),`Digit${slot+1}`,49+slot);};

  // The installed wizard has one ready Summon Creature VII. Enter through
  // actual ground-target right-click radial, not a test engine hook. The
  // native target mask44 excludes self, so self radial must stay disabled.
  const anchor=(await snapshot()).actors.find(a=>a.id===awaitedPlayer).screen;
  let ground=false;
  for(const [dx,dy] of [[-80,45],[80,45],[-130,75],[130,75],[0,100]]){
    for(const type of ['mousePressed','mouseReleased'])await win.webContents.debugger.sendCommand('Input.dispatchMouseEvent',{type,x:Math.round(anchor.x+dx),y:Math.round(anchor.y+dy),button:'right',clickCount:1});
    ground=await evaluate(`!document.querySelector('.radial-overlay').hidden&&document.querySelector('.radial-title').textContent==='Ground'`);
    if(ground)break;await key('keyDown','Escape','Escape',27);await key('keyUp','Escape','Escape',27);
  }
  assert.ok(ground,'Find an actual walkable floor hit for native ground targeting');
  await chooseWheel(1);await chooseWheel(5);await chooseWheel(7);
  await wait(`Boolean([...document.querySelectorAll('.radial-entry')].find(b=>b.getAttribute('aria-label')==='Summon Creature VII'))`);
  const label=await evaluate(`[...document.querySelectorAll('.radial-entry')].find(b=>b.getAttribute('aria-label')==='Summon Creature VII').getAttribute('aria-label')`);
  assert.equal(await evaluate(`document.querySelector('.radial-entry[aria-label="Summon Creature VII"]').disabled`),false);
  await click('.radial-entry[aria-label="Summon Creature VII"]');
  await wait(`JSON.parse(document.querySelector('#model-canvas').dataset.creatureAnimations).actors.some(a=>a.masterId===${awaitedPlayer}&&a.associateType===4)`);
  await win.webContents.debugger.sendCommand('Input.dispatchMouseEvent',{type:'mouseWheel',x:720,y:600,deltaX:0,deltaY:1800});
  // Use ordinary orbit input to see over the room walls, then pick the model.
  await win.webContents.debugger.sendCommand('Input.dispatchMouseEvent',{type:'mousePressed',x:720,y:550,button:'left',clickCount:1});
  for(let i=1;i<=6;i++)await win.webContents.debugger.sendCommand('Input.dispatchMouseEvent',{type:'mouseMoved',x:720,y:550+i*15,button:'left',buttons:1});
  await win.webContents.debugger.sendCommand('Input.dispatchMouseEvent',{type:'mouseReleased',x:720,y:640,button:'left',clickCount:1});
  await new Promise(r=>setTimeout(r,350));
  const summoned=(await snapshot()).actors.find(a=>a.masterId===awaitedPlayer&&a.associateType===4);
  assert.ok(summoned.screen);assert.notEqual(summoned.id,awaitedPlayer);
  assert.ok(summoned.screen.x>0&&summoned.screen.x<1440&&summoned.screen.y>0&&summoned.screen.y<900,'Summon must project inside the captured viewport: '+JSON.stringify(summoned));
  await new Promise(r=>setTimeout(r,2500));const settled=await snapshot();
  await open('spells');await evaluate(`[...document.querySelectorAll('.game-panel-tabs button')].find(b=>b.textContent==='Memorized').click()`);
  await wait(`Boolean(document.querySelector('[data-spell-id="181"][data-spell-ready="0"]'))`);
  await key('keyDown','Escape','Escape',27);await key('keyUp','Escape','Escape',27);
  await wait(`document.querySelector('#game-ui').dataset.panel===''`);assert.equal(errors.length,0);
  await new Promise(r=>setTimeout(r,500));
  await fs.writeFile(path.join(workspace,'backups/animations/live-summoning-ui.png'),(await win.webContents.capturePage()).toPNG());
  const pickOwned=async()=>{let owned=false;
  for(const dy of [-15,-30,0,-45,15])for(const dx of [0,-12,12]){
    if(owned)break;
    const visible=(await snapshot()).actors.find(a=>a.id===summoned.id).screen;
    for(const type of ['mousePressed','mouseReleased'])await win.webContents.debugger.sendCommand('Input.dispatchMouseEvent',{type,x:Math.round(visible.x+dx),y:Math.round(visible.y+dy),button:'right',clickCount:1});
    owned=await evaluate(`!document.querySelector('.radial-overlay').hidden&&Boolean(document.querySelector('.radial-entry[aria-label="Heal me"]'))`);
    if(!owned){await key('keyDown','Escape','Escape',27);await key('keyUp','Escape','Escape',27);}
  }
  assert.ok(owned,'Right-click must pick the actual canonical associate model');};
  await pickOwned();await chooseWheel(3);
  await wait(`JSON.parse(document.querySelector('#model-canvas').dataset.creatureAnimations).actors.some(a=>a.id===${summoned.id}&&a.lastAssociateCommand===-5&&a.listenPatternNumber===-5)`);
  await pickOwned();await chooseWheel(4);
  await wait(`JSON.parse(document.querySelector('#model-canvas').dataset.creatureAnimations).actors.some(a=>a.id===${summoned.id}&&a.lastAssociateCommand===-2&&a.listenPatternNumber===-2)`);
  const transfers=[];
  if(checkTransfer)for(const resRef of ['m0q1d','m0q1a']){
    await evaluate(`{const s=document.querySelector('#area-select');s.value=${JSON.stringify(resRef)};s.dispatchEvent(new Event('change'));}`);
    await wait(`document.querySelector('#model-canvas').dataset.areaResRef===${JSON.stringify(resRef)}&&document.querySelector('#status-text').textContent.includes('AREA RENDERED')`);
    await wait(`JSON.parse(document.querySelector('#model-canvas').dataset.creatureAnimations).actors.some(a=>a.id===${summoned.id}&&a.masterId===${awaitedPlayer}&&a.associateType===4)`);
    await key('keyDown','f','KeyF',70);await key('keyUp','f','KeyF',70);await new Promise(r=>setTimeout(r,400));
    // Each area render restores the player camera. Reapply the same ordinary
    // orbit input used above so the room wall does not occlude model picking.
    await win.webContents.debugger.sendCommand('Input.dispatchMouseEvent',{type:'mousePressed',x:720,y:550,button:'left',clickCount:1});
    for(let i=1;i<=6;i++)await win.webContents.debugger.sendCommand('Input.dispatchMouseEvent',{type:'mouseMoved',x:720,y:550+i*15,button:'left',buttons:1});
    await win.webContents.debugger.sendCommand('Input.dispatchMouseEvent',{type:'mouseReleased',x:720,y:640,button:'left',clickCount:1});await new Promise(r=>setTimeout(r,350));
    const value=await snapshot(),actor=value.actors.find(a=>a.id===summoned.id);assert.ok(actor.screen);transfers.push({resRef,actor,player:await player()});assert.equal(await player(),awaitedPlayer);
  }
  if(checkTransfer)await fs.writeFile(path.join(workspace,'backups/animations/live-associate-transfer-ui.png'),(await win.webContents.capturePage()).toPNG());
  await pickOwned();await chooseWheel(7);
  await wait(`Boolean(document.querySelector('.radial-entry[aria-label="Unsummon"]'))`);await click('.radial-entry[aria-label="Unsummon"]');
  await wait(`!JSON.parse(document.querySelector('#model-canvas').dataset.creatureAnimations).actors.some(a=>a.id===${summoned.id})`);
  assert.equal(errors.length,0);await new Promise(r=>setTimeout(r,500));
  await fs.writeFile(path.join(workspace,'backups/animations/live-summoning-dismissed-ui.png'),(await win.webContents.capturePage()).toPNG());
  await fs.writeFile(path.join(workspace,'backups/animations/live-summoning-ui.json'),JSON.stringify({label,player:awaitedPlayer,summoned,settled,testedCommands:[-5,-2,-10],dismissedId:summoned.id,afterDismiss:await snapshot(),
    audio:await evaluate(`JSON.parse(document.querySelector('#model-canvas').dataset.audio??'null')`),errors},null,2));
  console.log('WORLD RADIAL FOLLOW AND STAND GROUND THROUGH REAL AUTHORED CONVERSATION EVENTS PASS',summoned.id);
  console.log('WORLD ASSOCIATE RADIAL UNSUMMON AND RENDER VIEW REMOVAL PASS',summoned.id);
  if(checkTransfer){
    await evaluate('window.flushRuntimeDiagnostics()');const records=(await fs.readFile(log.path,'utf8')).trim().split('\n').map(JSON.parse),engineFailures=records.filter(r=>r.code==='engine.unimplemented'||r.code==='engine.failed'),engineCalls=[...new Set(engineFailures.map(r=>r.context?.engineCall))];
    await fs.writeFile(path.join(workspace,'backups/animations/live-associate-transfer-ui.json'),JSON.stringify({player:awaitedPlayer,summonId:summoned.id,transfers,afterDismiss:await snapshot(),browserErrors:errors,engineCalls,engineFailures,runtimeLog:path.relative(workspace,log.path),
      limits:'Actual area-selector scene changes with native NPC realization, installed summon/follow/stand/dismiss input. Browser errors and engine diagnostics are distinct. Does not test the native player ClientArea wire/ack handshake or issue-free campaign progression.'},null,2));
    console.log('RENDERED ASSOCIATE TRANSFER OUT AND BACK WITH CANONICAL ID AND RADIAL DISMISS PASS',summoned.id);console.log('OBSERVED ENGINE OMISSIONS',JSON.stringify(engineCalls));
  }
  console.log('LIVE SUMMON FROM RIGHT-CLICK RADIAL, CANONICAL MASTER/ASSOCIATE, REAL SLOT CONSUMPTION AND RENDER BINDING PASS',summoned.id);await evaluate('window.flushRuntimeDiagnostics()');app.exit(0);
 }catch(error){await fs.writeFile(path.join(workspace,'backups/animations/live-summoning-ui-failed.png'),(await win.webContents.capturePage()).toPNG());console.error(error.stack,errors);app.exit(1);}
});
