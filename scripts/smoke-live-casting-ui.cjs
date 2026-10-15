const {app,BrowserWindow,ipcMain}=require('electron');
const assert=require('node:assert/strict'),fs=require('node:fs/promises'),path=require('node:path');
const {registerRuntimeLog,observeWindow,flushOnClose}=require('../electron/runtime_log.cjs');
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
  const awaitedPlayer=await player();await open('spells');
  await evaluate(`[...document.querySelectorAll('.game-panel-tabs button')].find(b=>b.textContent==='Memorized').click()`);
  await wait(`Boolean(document.querySelector('[data-spell-id="100"][data-spell-ready="1"]'))`);
  const binding=await drag('[data-spell-id="100"][data-spell-ready="1"]',1);assert.equal(binding.binding.classIndex,0);
  await click('[data-spell-id="100"][data-spell-ready="1"]');await wait(`document.querySelector('${canvas}').dataset.spellTarget==='100'`);
  await selfTarget();
  const settle=async()=>{const end=Date.now()+12000;while(Date.now()<end){const o=(await capture()).actors.find(a=>a.id===awaitedPlayer);if(events.some(e=>e.objectId===awaitedPlayer&&[17,18,19,20,61].includes(e.animation))&&o.base<=1)return;await new Promise(r=>setTimeout(r,100));}throw new Error('Cast did not finish');};
  await settle();await open('spells');await evaluate(`[...document.querySelectorAll('.game-panel-tabs button')].find(b=>b.textContent==='Memorized').click()`);
  const used=await evaluate(`document.querySelectorAll('[data-spell-id="100"][data-spell-ready="0"]').length`);assert.equal(used,1);
  await click('.game-close');await key('keyDown','F2','F2',113);await key('keyUp','F2','F2',113);
  await wait(`document.querySelector('${canvas}').dataset.spellTarget==='100'`);await selfTarget();
  // A second cast waits for the current six-second combat round; a fixed
  // conjure-only delay would inspect its slot before release.
  await open('spells');await evaluate(`[...document.querySelectorAll('.game-panel-tabs button')].find(b=>b.textContent==='Memorized').click()`);
  await wait(`document.querySelectorAll('[data-spell-id="100"][data-spell-ready="0"]').length===2`);await new Promise(r=>setTimeout(r,1800));await capture();
  assert.equal(await evaluate(`document.querySelectorAll('[data-spell-id="100"][data-spell-ready="0"]').length`),2);
  assert.ok(events.some(e=>e.objectId===awaitedPlayer&&e.clip!=='pause1'&&[15,16].includes(e.animation)));assert.equal(errors.length,0);
  await fs.writeFile(path.join(workspace,'backups/animations/live-casting-ui.png'),(await win.webContents.capturePage()).toPNG());
  await fs.writeFile(path.join(workspace,'backups/animations/live-casting-ui.json'),JSON.stringify({binding,events:events.filter(e=>e.objectId===awaitedPlayer),used:2,errors},null,2));
  console.log('SPELLBOOK CLICK, SELF TARGET, SLOT CONSUMPTION, HOTBAR F2 AND CAST ANIMATIONS PASS');await evaluate('window.flushRuntimeDiagnostics()');app.exit(0);
 }catch(error){await fs.writeFile(path.join(workspace,'backups/animations/live-casting-ui-failed.png'),(await win.webContents.capturePage()).toPNG());console.error(error.stack,errors);app.exit(1);}
});
