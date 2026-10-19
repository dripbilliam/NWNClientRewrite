const {app,BrowserWindow,ipcMain}=require('electron');
const assert=require('node:assert/strict'),fs=require('node:fs/promises'),path=require('node:path');
const {registerRuntimeLog,observeWindow,flushOnClose}=require('../electron/runtime_log.cjs');
const workspace=path.resolve(__dirname,'..'),install=path.resolve('../FullDecomp/NwnRootInstall'),profile=path.join(workspace,`backups/live-casting-ui-profile-${process.pid}`);
const polymorphHotbar=process.argv.includes('--polymorph-hotbar'),polymorphMode=process.argv.includes('--polymorph')||polymorphHotbar;
const featRadial=process.argv.includes('--feat-radial');
const sanctuaryMode=process.argv.includes('--sanctuary');
const timeStopMode=process.argv.includes('--time-stop');
const silentProjectile=process.argv.includes('--silent-projectiles');
const femaleProjectile=process.argv.includes('--female-projectiles');
const referenceModels=process.argv.includes('--reference-models');
const characterName=process.argv.includes('--versus')||sanctuaryMode?'cleric.bic':process.argv.includes('--feats')||featRadial?'druid.bic':'wizard.bic';
app.setPath('userData',profile);app.setPath('logs',profile);app.setPath('crashDumps',profile);
app.whenReady().then(async()=>{
 const log=registerRuntimeLog(ipcMain,path.join(workspace,'runtime-logs'));
 const win=new BrowserWindow({show:false,width:1440,height:960,webPreferences:{preload:path.join(workspace,'electron/preload.cjs'),contextIsolation:true,nodeIntegration:false,sandbox:true,offscreen:true,backgroundThrottling:false}});flushOnClose(win,observeWindow(win,log));
 const errors=[];win.webContents.on('console-message',(_e,level,message)=>{if(level>=3)errors.push(message);});
 const evaluate=async code=>{try{return await win.webContents.executeJavaScript(code);}catch(error){error.message+='\nRenderer evaluation: '+code;throw error;}},wait=async condition=>{const deadline=Date.now()+90000;while(!await evaluate(condition)){if(Date.now()>deadline)throw new Error('Timeout: '+condition+'\n'+await evaluate(`document.body.innerText.slice(-2000)`));await new Promise(r=>setTimeout(r,100));}};
 const paint=()=>evaluate('new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)))');
 const point=selector=>evaluate(`{const r=document.querySelector(${JSON.stringify(selector)}).getBoundingClientRect();({x:Math.round(r.left+r.width/2),y:Math.round(r.top+r.height/2)});}`);
 const click=async(selector,button='left')=>{const p=await point(selector);for(const type of ['mousePressed','mouseReleased'])await win.webContents.debugger.sendCommand('Input.dispatchMouseEvent',{type,...p,button,clickCount:1});};
 const files=async(selector,paths)=>{const {root}=await win.webContents.debugger.sendCommand('DOM.getDocument'),{nodeId}=await win.webContents.debugger.sendCommand('DOM.querySelector',{nodeId:root.nodeId,selector});await win.webContents.debugger.sendCommand('DOM.setFileInputFiles',{nodeId,files:paths});};
 const key=async(type,key,code,windowsVirtualKeyCode)=>win.webContents.debugger.sendCommand('Input.dispatchKeyEvent',{type,key,code,windowsVirtualKeyCode,modifiers:type==='keyDown'?(key==='Control'?2:key==='Shift'?8:0):0});
 const open=async panel=>{await evaluate(`{const s=document.querySelector('#ui-panel-select');s.value=${JSON.stringify(panel)};s.dispatchEvent(new Event('change'));}`);await wait(`document.querySelector('#game-ui').dataset.panel===${JSON.stringify(panel)}`);};
 const buttons=()=>evaluate(`JSON.parse(document.querySelector('#game-ui').dataset.quickbar)`);
 const drag=async(source,slot)=>evaluate(`(()=>{const source=document.querySelector(${JSON.stringify(source)}),target=document.querySelector('.game-quick-slot[data-slot="${slot}"]'),data=new DataTransfer();source.dispatchEvent(new DragEvent('dragstart',{bubbles:true,dataTransfer:data}));const payload=JSON.parse(data.getData('application/x-nwn-quickbar'));target.dispatchEvent(new DragEvent('dragover',{bubbles:true,cancelable:true,dataTransfer:data}));target.dispatchEvent(new DragEvent('drop',{bubbles:true,cancelable:true,dataTransfer:data}));return payload;})()`);
 const load=async()=>{await files('#game-data-folder',[path.join(install,'data')]);await wait(`document.querySelector('#status-text').textContent.startsWith('GAME DATA READY')`);await files('#language-data-folder',[path.join(install,'lang/en/data')]);await wait(`document.querySelector('#status-text').textContent==='LANGUAGE DATA READY'`);await files('#area-file',[path.join(install,'data/nwm/Prelude.nwm')]);await wait(`document.querySelector('#character-frontend').dataset.mode==='select'`);await evaluate(`{[...document.querySelectorAll('.character-card')].find(b=>b.textContent.includes(${JSON.stringify(characterName)})).click();document.querySelector('#run-module-startup').checked=false;[...document.querySelectorAll('#character-frontend button')].find(b=>b.textContent==='Play').click();}`);await wait(`document.querySelector('#status-text').textContent.includes('AREA RENDERED')`);};
 let scrollChoices,versusChoices,silentCharacterBytes,femaleCharacterBytes,timeStopChoice;
 try{
  await win.loadFile(path.join(workspace,'dist/index.html'));win.webContents.debugger.attach('1.3');
  if(timeStopMode){
   const {openLocalModule}=await import('./local-module.mjs'),{ModuleSession}=await import('../src/module_session.js'),{createTimeStopFixture}=await import('./create-time-stop-fixture.mjs'),original=await fs.readFile(path.join(install,'data/lcv/wizard.bic'));
   const session=await new ModuleSession(await openLocalModule(install,path.join(install,'data/nwm/Prelude.nwm')),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize([],{character:original}),fixture=createTimeStopFixture(original,session);timeStopChoice={spellId:fixture.spellId,level:fixture.level,classLevel:fixture.classLevel};
   const encoded=Buffer.from(fixture.bytes).toString('base64');await evaluate(`{const original=File.prototype.arrayBuffer;File.prototype.arrayBuffer=async function(){if(this.name.toLowerCase()!=='wizard.bic')return original.call(this);return Uint8Array.from(atob(${JSON.stringify(encoded)}),c=>c.charCodeAt(0)).buffer;};true;}`);
  }
  if(femaleProjectile){
   const {parseGff}=await import('../src/gff.js'),{typedGff,writeGff}=await import('../src/gff_writer.js');const draft=typedGff(parseGff(await fs.readFile(path.join(install,'data/lcv/wizard.bic'))).root);draft.fields.Gender.value=1;femaleCharacterBytes=writeGff('BIC ',draft);
   // Only the owned in-memory character changes; female models/sounds resolve
   // through unchanged installed metadata and resources, never test overrides.
   const encoded=Buffer.from(femaleCharacterBytes).toString('base64');await evaluate(`{const original=File.prototype.arrayBuffer;File.prototype.arrayBuffer=async function(){if(this.name.toLowerCase()!=='wizard.bic')return original.call(this);return Uint8Array.from(atob(${JSON.stringify(encoded)}),c=>c.charCodeAt(0)).buffer;};true;}`);
  }
  if(silentProjectile){
   const {openLocalModule}=await import('./local-module.mjs'),{ModuleSession}=await import('../src/module_session.js'),{parseGff}=await import('../src/gff.js'),{typedGff,writeGff,gffField}=await import('../src/gff_writer.js'),{clientProjectileSpell}=await import('../src/client_projectile_runtime.js');
   const original=await fs.readFile(path.join(install,'data/lcv/wizard.bic')),s=await new ModuleSession(await openLocalModule(install,path.join(install,'data/nwm/Prelude.nwm')),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize([],{character:original}),draft=typedGff(parseGff(original).root);let choice;
   for(const [index,cls]of s.player.nativeTalentClasses.entries())for(const slots of cls.memorized)for(const slot of slots){const spell=slot?.ready?clientProjectileSpell(s.characterRules,slot.id):null;if(!spell||!(spell.metamagic&16)||!spell.useProjectile||![1,2,5,6].includes(spell.projectilePath)||!spell.model||!spell.conjureSound)continue;const level=s.spellBook.level(slot.id,draft.fields.ClassList.value[index].fields.Class.value)+s.spellBook.metamagicCost(16);if(level<10&&draft.fields.ClassList.value[index].fields[`MemorizedList${level}`]?.value.length)choice??={index,id:slot.id,level};}
   assert.ok(choice);const cls=draft.fields.ClassList.value[choice.index];let copy;
   for(let level=0;level<10;level++)for(const slot of cls.fields[`MemorizedList${level}`]?.value??[])if(slot.fields.Spell.value===choice.id){copy??=structuredClone(slot);slot.fields.Ready=gffField(0,0);}
   copy.fields.SpellMetaMagic=gffField(0,16);copy.fields.Ready=gffField(0,1);cls.fields[`MemorizedList${choice.level}`].value[0]=copy;
   if(!draft.fields.FeatList.value.some(f=>f.fields.Feat.value===33)){const feat=structuredClone(draft.fields.FeatList.value[0]);feat.fields.Feat.value=33;draft.fields.FeatList.value.push(feat);}
   // Owned in-memory BIC only: a known installed spell in its legal Silent
   // slot with the standard Silent feat. No installed resource or game rule edit.
   silentCharacterBytes=writeGff('BIC ',draft);const encoded=Buffer.from(silentCharacterBytes).toString('base64');await evaluate(`{const original=File.prototype.arrayBuffer;File.prototype.arrayBuffer=async function(){if(this.name.toLowerCase()!=='wizard.bic')return original.call(this);return Uint8Array.from(atob(${JSON.stringify(encoded)}),c=>c.charCodeAt(0)).buffer;};true;}`);
  }
  if(process.argv.includes('--versus')){
   const {openLocalModule}=await import('./local-module.mjs'),{ModuleSession}=await import('../src/module_session.js'),{parseGff}=await import('../src/gff.js'),{typedGff,writeGff}=await import('../src/gff_writer.js');
   const resolver=await openLocalModule(install,path.join(install,'data/nwm/Prelude.nwm')),original=await fs.readFile(path.join(install,'data/lcv',characterName)),session=await new ModuleSession(resolver,{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize([],{character:original}),draft=typedGff(parseGff(original).root),classData=draft.fields.ClassList.value[0],p=session.items.learningProviders();
   versusChoices=['nw_s0_previl','nw_s0_prgood'].map(script=>{const spellId=session.characterRules.spells.orderedRows.findIndex(r=>String(r.ImpactScript).toLowerCase()===script),spell=p.spell(spellId),parentId=spell.master;return{script,spellId,parentId,level:p.spellLevel(p.spell(parentId),classData.fields.Class.value)};});
   for(const [index,choice]of versusChoices.entries()){
    assert.equal(choice.level,1);const known=classData.fields.KnownList1?.value,memo=classData.fields.MemorizedList1.value;assert.ok(memo[index]);
    if(known&&!known.some(e=>e.fields.Spell.value===choice.parentId)){const entry=structuredClone(known[0]);entry.fields.Spell.value=choice.parentId;known.push(entry);}
    memo[index].fields.Spell.value=choice.parentId;if(memo[index].fields.Ready)memo[index].fields.Ready.value=1;if(memo[index].fields.DomainSpell)memo[index].fields.DomainSpell.value=0;if(memo[index].fields.SpellMetaMagic)memo[index].fields.SpellMetaMagic.value=0;
   }
   // Only the owned BIC fixture selects two legal same-level prepared spells.
   const encoded=Buffer.from(writeGff('BIC ',draft)).toString('base64');await evaluate(`{const original=File.prototype.arrayBuffer;File.prototype.arrayBuffer=async function(){if(this.name.toLowerCase()!==${JSON.stringify(characterName)})return original.call(this);return Uint8Array.from(atob(${JSON.stringify(encoded)}),c=>c.charCodeAt(0)).buffer;};true;}`);
  }
  if(process.argv.includes('--scroll-learning')||process.argv.includes('--rest')){
   const {openLocalModule}=await import('./local-module.mjs'),{ModuleSession}=await import('../src/module_session.js'),{parseGff}=await import('../src/gff.js'),{typedGff,gffField,writeGff}=await import('../src/gff_writer.js'),{selectInstalledLearnableScrolls}=await import('./select-installed-scrolls.mjs');
   const resolver=await openLocalModule(install,path.join(install,'data/nwm/Prelude.nwm')),original=await fs.readFile(path.join(install,'data/lcv/wizard.bic')),
    session=await new ModuleSession(resolver,{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize([],{character:original}),draft=typedGff(parseGff(original).root);
   scrollChoices=await selectInstalledLearnableScrolls(session);assert.equal(scrollChoices.length,2);
   for(const [index,choice]of scrollChoices.entries()){
    const item=typedGff(parseGff(await resolver.getResource(choice.template,2025),'UTI ').root,0);item.fields.StackSize=gffField(2,index===0?2:1);item.fields.Repos_PosX=gffField(0,255);item.fields.Repos_Posy=gffField(0,255);draft.fields.ItemList.value.push(item);
   }
   // Only the owned in-memory BIC adds these unchanged installed UTI records;
   // stock installation/character files stay read-only. No gameplay exception.
   const encoded=Buffer.from(writeGff('BIC ',draft)).toString('base64');await evaluate(`{const original=File.prototype.arrayBuffer;File.prototype.arrayBuffer=async function(){if(this.name.toLowerCase()!=='wizard.bic')return original.call(this);return Uint8Array.from(atob(${JSON.stringify(encoded)}),c=>c.charCodeAt(0)).buffer;};true;}`);
  }
  if(process.argv.includes('--abilities')){
   const {openLocalModule}=await import('./local-module.mjs'),{ModuleSession}=await import('../src/module_session.js'),{parseGff}=await import('../src/gff.js'),{typedGff,gffField,writeGff}=await import('../src/gff_writer.js');
   const resolver=await openLocalModule(install,path.join(install,'data/nwm/Prelude.nwm')),original=await fs.readFile(path.join(install,'data/lcv/wizard.bic'));
   const session=await new ModuleSession(resolver,{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize([],{character:original});
   const source=[...session.registry.objects.values()].find(o=>o.nativeSpellLikeAbilities?.some(a=>a.id===126)),ability=(source.creatureData??source.authored).SpecAbilityList.find(a=>a.Spell===126),draft=typedGff(parseGff(original).root);
   // Two independent entries copied from an actual installed NPC, solely in
   // this owned fixture. Exercise real import and duplicate-use consumption.
   draft.fields.SpecAbilityList=gffField(15,[typedGff(ability),typedGff(ability)]);const encoded=Buffer.from(writeGff('BIC ',draft)).toString('base64');
   await evaluate(`{const original=File.prototype.arrayBuffer;File.prototype.arrayBuffer=async function(){if(this.name.toLowerCase()!=='wizard.bic')return original.call(this);return Uint8Array.from(atob(${JSON.stringify(encoded)}),c=>c.charCodeAt(0)).buffer;};true;}`);
  }
  if(polymorphMode)await evaluate(`{
   // Owned in-memory fixture: replace the preset's prepared/known Phantasmal
   // Killer127 with same-level PolymorphSelf130. Installed BIC stays untouched.
   const original=File.prototype.arrayBuffer;File.prototype.arrayBuffer=async function(){
    const buffer=await original.call(this);if(this.name.toLowerCase()!=='wizard.bic')return buffer;
    const bytes=new Uint8Array(buffer.slice(0)),v=new DataView(bytes.buffer),fields=v.getUint32(16,true),count=v.getUint32(20,true),labels=v.getUint32(24,true);
    for(let n=0;n<count;n++){const f=fields+n*12,label=new TextDecoder().decode(bytes.subarray(labels+v.getUint32(f+4,true)*16,labels+v.getUint32(f+4,true)*16+16)).replace(/\\0.*$/,'');if(label==='Spell'&&v.getUint32(f+8,true)===127)v.setUint32(f+8,130,true);}
    return bytes.buffer;
   };true;
  }`);
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
  if(timeStopMode){
   await open('spells');await evaluate(`[...document.querySelectorAll('.game-panel-tabs button')].find(b=>b.textContent==='Memorized').click()`);
   const selector=`[data-spell-id="${timeStopChoice.spellId}"][data-spell-ready="1"]`;await wait(`Boolean(document.querySelector('${selector}'))`);const binding=await drag(selector,1);assert.equal(binding.binding.intParam,timeStopChoice.spellId);await click('.game-close');
   await evaluate('window.flushRuntimeDiagnostics()');const baselineCount=(await fs.readFile(log.path,'utf8')).trim().split('\n').length;
   await click('#player-actions','right');await wait(`!document.querySelector('.radial-overlay').hidden`);await click('.radial-entry[aria-label="Cast spell"]');await click('.radial-entry[aria-label="Wizard"]');await click('.radial-entry[aria-label="Levels 7–9"]');
   await wait(`Boolean(document.querySelector('.radial-entry[aria-label="Time Stop"]'))`);await click('.radial-entry[aria-label="Time Stop"]');assert.equal(await evaluate(`document.querySelector('${canvas}').dataset.spellTarget??null`),null);
   const effects=`JSON.parse(document.querySelector('#game-ui').dataset.nativeEffects)`,pause=`JSON.parse(document.querySelector('${canvas}').dataset.clientPause??'null')`;await wait(`${effects}.effects.some(e=>e.type===64&&e.spellId===${timeStopChoice.spellId})&&${pause}?.flags===1`);const during=await evaluate(effects),beforePause=await evaluate(pause),beforePoses=await capture(),frozenActor=beforePoses.actors.find(a=>a.id!==awaitedPlayer&&a.clip&&![6,8].includes(a.base)&&!beforePause.exclusions.includes((a.id|0x80000000)>>>0));assert.ok(frozenActor);
   await new Promise(r=>setTimeout(r,250));const laterPause=await evaluate(pause),laterPoses=await capture(),laterFrozen=laterPoses.actors.find(a=>a.id===frozenActor.id);assert.equal(laterPause.flags,1);assert.deepEqual(laterPause.world,beforePause.world);assert.ok(laterPause.one.time>beforePause.one.time);assert.equal(laterFrozen.time,frozenActor.time);assert.equal(laterFrozen.clip,frozenActor.clip);const animationFreeze={beforePause,laterPause,before:frozenActor,after:laterFrozen};
   await paint();await fs.writeFile(path.join(workspace,'backups/animations/live-time-stop-active.png'),(await win.webContents.capturePage()).toPNG());
   await wait(`!${effects}.effects.some(e=>e.type===64)`);await open('spells');await evaluate(`[...document.querySelectorAll('.game-panel-tabs button')].find(b=>b.textContent==='Memorized').click()`);await wait(`document.querySelectorAll('[data-spell-id="${timeStopChoice.spellId}"][data-spell-ready="0"]').length===1`);assert.equal(await player(),awaitedPlayer);await paint();await capture();
   await fs.writeFile(path.join(workspace,'backups/animations/live-time-stop-expired.png'),(await win.webContents.capturePage()).toPNG());await evaluate('window.flushRuntimeDiagnostics()');const diagnostics=(await fs.readFile(log.path,'utf8')).trim().split('\n').slice(baselineCount).map(JSON.parse),failures=diagnostics.filter(d=>d.severity==='error'||d.level==='error'),knownLoadFailures=failures.filter(d=>d.message==='Resource plc_w02.pwk was not found in module, loaded HAKs, or KEY.'),newFailures=failures.filter(d=>!knownLoadFailures.includes(d));
   await fs.writeFile(path.join(workspace,'backups/animations/live-time-stop-ui.json'),JSON.stringify({playerId:awaitedPlayer,choice:timeStopChoice,binding,during,animationFreeze,clientAfter:await evaluate(pause),after:await evaluate(effects),events,errors,knownLoadFailures,newFailures,diagnostics,limits:'Owned high-level BIC fixture, real spellbook drag to hotbar, right-click self Cast spell/Wizard/Levels7–9/TimeStop, ordinary queue/slot/installed NCS, effect64/natural native-AI expiry/canonical player ID. Decoded native client pause clocks/exclusion IDs and real ordinary NPC clip freeze sampled250ms apart while caster clock advances. General native AI on, startup/entry fixture. Scene virtuals/audio/GUI, raw pause transport, every periodic owner and campaign acceptance remain incomplete; all diagnostics retained.'},null,2)+'\n');assert.deepEqual(errors,[]);assert.deepEqual(newFailures,[]);console.log('TIME STOP SPELLBOOK/HOTBAR/SELF RADIAL, CAST/SLOT/EXPIRY AND CLIENT CLOCK/NPC POSE FREEZE PASS');app.exit(0);return;
  }
  if(process.argv.includes('--character-sheet')){
   const readSheet=()=>evaluate(`JSON.parse(document.querySelector('#game-ui').dataset.nativeCharacterSheet)`);
   await evaluate('window.flushRuntimeDiagnostics()');const baselineCount=(await fs.readFile(log.path,'utf8')).trim().split('\n').length;
   await wait(`Boolean(document.querySelector('#game-ui').dataset.nativeCharacterSheet)`);const initial=await readSheet();assert.equal(initial.targetId,0x7f000000);assert.equal(initial.page,-1);assert.equal(initial.consumers,0);
   await open('character');await wait(`JSON.parse(document.querySelector('#game-ui').dataset.nativeCharacterSheet).page===0`);const opened=await readSheet();assert.equal(opened.targetId,awaitedPlayer);assert.equal(opened.consumers,1);
   for(let index=0;index<3;index++){
    await click('.game-close');await wait(`JSON.parse(document.querySelector('#game-ui').dataset.nativeCharacterSheet).page===-1`);assert.equal((await readSheet()).consumers,1);
    await key('keyDown','c','KeyC',67);await key('keyUp','c','KeyC',67);await wait(`document.querySelector('#game-ui').dataset.panel==='character'&&JSON.parse(document.querySelector('#game-ui').dataset.nativeCharacterSheet).page===0`);assert.equal((await readSheet()).consumers,1);
   }
   await open('spells');await wait(`JSON.parse(document.querySelector('#game-ui').dataset.nativeCharacterSheet).page===-1`);const hidden=await readSheet();assert.equal(hidden.targetId,awaitedPlayer);assert.equal(hidden.consumers,1);await click('.game-close');
   await open('character');await wait(`JSON.parse(document.querySelector('#game-ui').dataset.nativeCharacterSheet).page===0`);await paint();
   await fs.writeFile(path.join(workspace,'backups/animations/live-character-sheet-ui.png'),(await win.webContents.capturePage()).toPNG());await evaluate('window.flushRuntimeDiagnostics()');const diagnostics=(await fs.readFile(log.path,'utf8')).trim().split('\n').map(JSON.parse);
   const interactionFailures=diagnostics.slice(baselineCount).filter(d=>d.severity==='error'||d.level==='error');
   await fs.writeFile(path.join(workspace,'backups/animations/live-character-sheet-ui.json'),JSON.stringify({playerId:awaitedPlayer,initial,opened,hidden,final:await readSheet(),errors,interactionFailures,diagnostics,limits:'Installed Prelude/wizard, visible character sheet opened by panel selector and C key, close button and panel switching. Decoded local frontend mapping invokes original-compared server subscription semantics. Native client marshaling/initial request, complete stats update writer/replication, campaign and every stat are not claimed. Startup/entry fixture; all diagnostics retained, including selector rejection of dungeonmaster.bic outside a DM session.'},null,2)+'\n');assert.deepEqual(errors,[]);assert.deepEqual(interactionFailures,[]);console.log('CHARACTER-SHEET OPEN/CLOSE/REOPEN/PANEL SWITCH, CANONICAL TARGET AND NON-ACCUMULATING SUBSCRIPTION PASS');app.exit(0);return;
  }
  if(process.argv.includes('--projectiles')||silentProjectile||femaleProjectile||referenceModels){
   const {openLocalModule}=await import('./local-module.mjs'),{ModuleSession}=await import('../src/module_session.js'),{clientProjectileSpell}=await import('../src/client_projectile_runtime.js');
   const s=await new ModuleSession(await openLocalModule(install,path.join(install,'data/nwm/Prelude.nwm')),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize([],{character:silentCharacterBytes??femaleCharacterBytes??await fs.readFile(path.join(install,'data/lcv/wizard.bic'))});
   const candidates=[];for(const cls of s.player.nativeTalentClasses)for(const slots of cls.memorized)for(const slot of slots){if(!slot?.ready||silentProjectile&&slot.metamagic!==16)continue;const spell=clientProjectileSpell(s.characterRules,slot.id);if(spell.useProjectile!==0&&[1,2,5,6].includes(spell.projectilePath)&&spell.model)candidates.push({id:slot.id,model:spell.model,path:spell.projectilePath,metamagic:slot.metamagic});}
   if(referenceModels){
    const {parseModel}=await import('../src/model_parser.js'),cache=new Map();
    for(const candidate of candidates){const spell=clientProjectileSpell(s.characterRules,candidate.id);candidate.referenceResources=[];for(const resource of spell.conjure.filter(Boolean)){if(!cache.has(resource))cache.set(resource,parseModel(await s.resolver.getResource(resource,2002)));if(cache.get(resource).nodes.some(n=>n.type==='reference'))candidate.referenceResources.push(resource);}}
    for(let i=candidates.length-1;i>=0;i--)if(!candidates[i].referenceResources.length)candidates.splice(i,1);
   }
   await open('spells');await evaluate(`[...document.querySelectorAll('.game-panel-tabs button')].find(b=>b.textContent==='Memorized').click()`);
   const choice=candidates.find(c=>c.id!==undefined);assert.ok(choice);const selector=`[data-spell-id="${choice.id}"][data-spell-ready="1"]`;
   await wait(`Boolean(document.querySelector(${JSON.stringify(selector)}))`);if(referenceModels){await evaluate(`document.querySelector(${JSON.stringify(selector)}).scrollIntoView({block:'center'})`);await paint();}await click(selector);if(await evaluate(`Boolean(document.querySelector('.game-close'))`))await click('.game-close');
   await wait(`document.querySelector('${canvas}').dataset.spellTarget===${JSON.stringify(String(choice.id))}`);
   const actors=(await snapshot()).actors,pc=actors.find(a=>a.id===awaitedPlayer),targets=actors.filter(a=>a.id!==awaitedPlayer&&a.hp>0&&a.screen&&a.screen.x>40&&a.screen.x<1380&&a.screen.y>80&&a.screen.y<830).sort((a,b)=>Math.hypot(...a.position.map((v,i)=>v-pc.position[i]))-Math.hypot(...b.position.map((v,i)=>v-pc.position[i])));assert.ok(targets.length);
   const target=targets[0];for(let n=0;n<35;n++){
    const actor=(await snapshot()).actors.find(a=>a.id===target.id),anchor=actor.screen,point={x:Math.round(anchor.x+(n%5-2)*6),y:Math.round(anchor.y+(Math.floor(n/5)-3)*6)};
    for(const type of ['mousePressed','mouseReleased'])await win.webContents.debugger.sendCommand('Input.dispatchMouseEvent',{type,...point,button:'left',clickCount:1});
    if(!await evaluate(`document.querySelector('${canvas}').dataset.spellTarget`))break;
   }
   let referenceCapture=null;
   if(referenceModels){
    await wait(`JSON.parse(document.querySelector('${canvas}').dataset.modelReferences??'[]').some(r=>${JSON.stringify(choice.referenceResources)}.includes(r.resource)&&r.children.length>0)`);
    const first=await evaluate(`JSON.parse(document.querySelector('${canvas}').dataset.modelReferences)`);await new Promise(r=>setTimeout(r,200));const second=await evaluate(`JSON.parse(document.querySelector('${canvas}').dataset.modelReferences)`);referenceCapture={choice,first,second};
    assert.ok(first.every(r=>!r.failed));assert.ok(second.every(r=>!r.failed));
    assert.ok(first.some(r=>{const next=second.find(s=>s.resource===r.resource);return r.children.some((child,i)=>{const other=next?.children[i];return other&&[...child.position,...child.quaternion].some((v,j)=>Math.abs(v-[...other.position,...other.quaternion][j])>1e-6);});}),'The authored reference child must follow its animated anchor');
   }
   let conjuring=null;if(silentProjectile){await wait(`JSON.parse(document.querySelector('${canvas}').dataset.projectiles).casts.controllers.some(c=>c.spellId===${choice.id}&&c.suppressSound===1&&[15,16].includes(c.animation))`);conjuring=await evaluate(`JSON.parse(document.querySelector('${canvas}').dataset.projectiles)`);}
   await wait(`JSON.parse(document.querySelector('${canvas}').dataset.projectiles).events.some(e=>e.kind==='ready')`);
   const during=await evaluate(`JSON.parse(document.querySelector('${canvas}').dataset.projectiles)`);await paint();await fs.writeFile(path.join(workspace,`backups/animations/${silentProjectile?'live-silent-cast-ui':femaleProjectile?'live-female-cast-ui':'live-projectile-ui'}.png`),(await win.webContents.capturePage()).toPNG());
   await wait(`(()=>{const p=JSON.parse(document.querySelector('${canvas}').dataset.projectiles);return p.impacts>=1&&p.destroyed>=1;})()`);
   const completed=await evaluate(`JSON.parse(document.querySelector('${canvas}').dataset.projectiles)`);await evaluate('window.flushRuntimeDiagnostics()');await fs.writeFile(path.join(workspace,'backups/animations/live-projectile-ui-observation-v2.json'),JSON.stringify({choice,during,completed,diagnostics:(await fs.readFile(log.path,'utf8')).trim().split('\n').map(JSON.parse)},null,2));
   const {parseModel}=await import('../src/model_parser.js'),{inheritAnimations}=await import('../src/mdl_animation.js'),asset=parseModel(await s.resolver.getResource(choice.model,2002));await inheritAnimations(asset,async name=>parseModel(await s.resolver.getResource(name,2002)));
   const loaded=completed.events.find(e=>e.kind==='loaded'&&e.resource.toLowerCase()===choice.model.toLowerCase());assert.ok(loaded);assert.deepEqual(loaded.clips,asset.animations.map(a=>a.name));assert.ok(completed.events.some(e=>e.kind==='stage'&&e.stage===1));assert.ok(completed.events.some(e=>e.kind==='stage'&&e.stage===2));assert.equal(completed.failed,0);assert.equal(errors.length,0);
   assert.ok(completed.events.some(e=>e.kind==='impactAttach'&&e.attached),'The real projectile must attach to its target body impact part');
   const spell=clientProjectileSpell(s.characterRules,choice.id),conjureRefs=spell.conjure.filter(Boolean);
   if(conjureRefs.length){
    for(const resource of conjureRefs){assert.ok(completed.casts.events.some(e=>e.kind==='loaded'&&e.resource===resource));assert.ok(completed.casts.events.some(e=>e.kind==='play'&&e.resource===resource&&e.clip==='conjure01'&&e.flags===0&&e.played));assert.ok(completed.casts.events.some(e=>e.kind==='play'&&e.resource===resource&&e.clip==='fade'&&e.flags===1&&e.played));}
    await wait(`JSON.parse(document.querySelector('${canvas}').dataset.projectiles).casts.active.length===0`);
   }
   const settled=await evaluate(`JSON.parse(document.querySelector('${canvas}').dataset.projectiles)`);for(const resource of conjureRefs)assert.ok(settled.casts.events.some(e=>e.kind==='destroy'&&e.resource===resource));
   if(referenceModels){
    await wait(`!JSON.parse(document.querySelector('${canvas}').dataset.modelReferences??'[]').some(r=>${JSON.stringify(choice.referenceResources)}.includes(r.resource))`);
    referenceCapture.cleaned=await evaluate(`JSON.parse(document.querySelector('${canvas}').dataset.modelReferences??'[]')`);
    await fs.writeFile(path.join(workspace,'backups/animations/live-model-reference-ui.json'),JSON.stringify(referenceCapture,null,2));
    console.log('ACTIVE SPELL CONJURE REFERENCE CHILD CREATION/ATTACHMENT/CLEANUP PASS');
   }
   const sounds=settled.casts.events.filter(e=>e.kind==='sound'&&e.sourceId===((awaitedPlayer|0x80000000)>>>0));if(silentProjectile)assert.equal(sounds.length,0);else if(spell.conjureSound)assert.ok(sounds.some(e=>e.resource===spell.conjureSound));
   const expectedChant=s.player.stats.gender===1?spell.conjureSoundFemale:spell.conjureSoundMale;if(!silentProjectile&&s.player.stats.race>=0&&s.player.stats.race<=6&&expectedChant)assert.ok(sounds.some(e=>e.resource===expectedChant),'The active spell chant must match the native source race/gender branch');
   await evaluate('window.flushRuntimeDiagnostics()');const diagnostics=(await fs.readFile(log.path,'utf8')).trim().split('\n').map(JSON.parse);
   assert.equal(diagnostics.filter(d=>['visual.cast-model-failed','visual.cast-controller-failed','visual.cast-animation-failed','visual.cast-clip-unavailable','visual.cast-anchor-unavailable'].includes(d.code)).length,0);
   assert.equal(diagnostics.filter(d=>d.code==='visual.cast-voice-fields-unavailable'||d.code==='audio.sound-failed'&&[expectedChant,spell.conjureSound].includes(d.context?.resRef)).length,0);
   assert.equal(diagnostics.filter(d=>['visual.projectile-impact-attachment-unimplemented','visual.projectile-impact-anchor-unavailable','visual.projectile-impact-scene-update-failed'].includes(d.code)).length,0);
   const spellMessages=await evaluate(`JSON.parse(document.querySelector('${canvas}').dataset.spellMessages)`),notices=spellMessages.events.filter(e=>e.spellId===choice.id&&e.sourceId===((awaitedPlayer|0x80000000)>>>0));assert.ok(notices.some(e=>e.casting===1&&e.identified===1&&e.hasItem===0));assert.ok(notices.some(e=>e.casting===0&&e.identified===1&&e.hasItem===0));assert.ok(notices.every(e=>e.text&&!e.text.includes('<CUSTOM')));
   assert.equal(diagnostics.filter(d=>['spell.client-message-failed','spell.client-message-unimplemented'].includes(d.code)).length,0);
   const observation={silentProjectile,femaleProjectile,expectedChant,playerId:awaitedPlayer,target,choice,conjuring,during,completed,settled,spellMessages,diagnostics,errors,limits:(silentProjectile?'Owned in-memory wizard BIC: known installed spell prepared in its legal Silent slot with standard Silent feat; installed files unchanged.':femaleProjectile?'Owned in-memory wizard BIC changes Gender to1; installed models, metadata and sounds unchanged.':'Untouched installed wizard prepared projectile spell selected using active Proj/ProjType/ProjModel data.')+' Real spellbook/world target/release, client IDs, authored projectile/conjure assets, native chant selection, cast controller fade and cleanup, native stage/path/AI services; native CC8 start/release templates and client reserved tokens. Startup/entry fixture. Native rich widget colors/layout, full cast/appearance packets and async scene/audio adapters remain diagnosed; not full campaign/save/network parity.'};
   observation.impactAttachments=completed.events.filter(e=>e.kind==='impactAttach');observation.limits+=' Real body impact parenting is checked; native flag28 update replication, client shield equipment/model bridge and ranged visual owner remain incomplete.';
   for(const file of silentProjectile?['live-silent-cast-ui.json']:femaleProjectile?['live-female-cast-ui.json']:['live-projectile-ui.json','live-cast-visual-ui.json','live-client-spell-message-ui.json','live-projectile-impact-ui.json'])await fs.writeFile(path.join(workspace,'backups/animations',file),JSON.stringify(observation,null,2));console.log(`${silentProjectile?'SILENT SUPPRESSION, ':femaleProjectile?'FEMALE CHANT, ':'MALE CHANT, '}INSTALLED CC8 START/RELEASE TEXT, CONJURE/FADE/CLEANUP AND PROJECTILE TRAVEL/BODY ATTACHMENT/CLEANUP PASS`);app.exit(0);return;
  }
  if(sanctuaryMode){
   await open('spells');await evaluate(`[...document.querySelectorAll('.game-panel-tabs button')].find(b=>b.textContent==='Memorized').click()`);
   const choice=await evaluate(`(()=>{const b=[...document.querySelectorAll('[data-spell-ready="1"]')].find(b=>b.textContent.startsWith('Sanctuary ·'));if(!b)return null;let h=b.previousElementSibling;while(h&&h.tagName!=='H4')h=h.previousElementSibling;return{spellId:Number(b.dataset.spellId),level:Number(h.textContent.match(/\\d+/)[0])};})()`);assert.ok(choice);await click('.game-close');
   await evaluate('window.flushRuntimeDiagnostics()');const baselineCount=(await fs.readFile(log.path,'utf8')).trim().split('\n').length;
   const choose=async slot=>{await key('keyDown',String(slot+1),`Digit${slot+1}`,49+slot);await key('keyUp',String(slot+1),`Digit${slot+1}`,49+slot);};
   await click('#player-actions','right');await wait(`!document.querySelector('.radial-overlay').hidden`);await choose(1);await choose(5);await choose(choice.level);
   await wait(`Boolean(document.querySelector('.radial-entry[aria-label="Sanctuary"]'))`);await click('.radial-entry[aria-label="Sanctuary"]');
   assert.equal(await evaluate(`document.querySelector('${canvas}').dataset.spellTarget??null`),null);
   const effects=`JSON.parse(document.querySelector('#game-ui').dataset.nativeEffects)`;await wait(`${effects}.effects.some(e=>e.type===63&&e.spellId===${choice.spellId})&&${effects}.icons.some(e=>e.iconId===52)`);const state=await evaluate(effects);await capture();
   await open('spells');await evaluate(`[...document.querySelectorAll('.game-panel-tabs button')].find(b=>b.textContent==='Memorized').click()`);await wait(`document.querySelectorAll('[data-spell-id="${choice.spellId}"][data-spell-ready="0"]').length===1`);await paint();
   await fs.writeFile(path.join(workspace,'backups/animations/live-sanctuary-ui.png'),(await win.webContents.capturePage()).toPNG());await evaluate('window.flushRuntimeDiagnostics()');
   const diagnostics=(await fs.readFile(log.path,'utf8')).trim().split('\n').slice(baselineCount).map(line=>JSON.parse(line)),failures=diagnostics.filter(d=>d.severity==='error'),knownLoadFailures=failures.filter(d=>d.message==='Resource plc_w02.pwk was not found in module, loaded HAKs, or KEY.'),newFailures=failures.filter(d=>!knownLoadFailures.includes(d));
   await fs.writeFile(path.join(workspace,'backups/animations/live-sanctuary-ui.json'),JSON.stringify({playerId:awaitedPlayer,choice,state,events,errors,knownLoadFailures,newFailures,diagnostics,limits:'Untouched installed cleric ready Sanctuary through actual right-button self wheel/class/level selection, automatic canonical target, queue/release, installed impact, effect/icon pool and used physical slot. Native AI on; startup/entry fixture. Icon pool verified, not HUD buff art or whole campaign/save/protocol.'},null,2));assert.deepEqual(errors,[]);assert.deepEqual(newFailures,[]);console.log('SANCTUARY SELF WHEEL, PREPARED SLOT, RELEASE AND EFFECT/ICON POOL PASS');app.exit(0);return;
  }
  if(process.argv.includes('--versus')){
   await wait(`Boolean(document.querySelector('#game-ui').dataset.nativeEffects)`);await evaluate('window.flushRuntimeDiagnostics()');const baselineCount=(await fs.readFile(log.path,'utf8')).trim().split('\n').length,casts=[];
   const choose=async slot=>{await key('keyDown',String(slot+1),`Digit${slot+1}`,49+slot);await key('keyUp',String(slot+1),`Digit${slot+1}`,49+slot);};
   for(const [index,choice]of versusChoices.entries()){
    await click('#player-actions','right');await wait(`!document.querySelector('.radial-overlay').hidden`);await choose(1);await choose(5);await choose(choice.level);
    await wait(`Boolean(document.querySelector('.radial-entry[aria-label="Protection from Alignment"]'))`);await click('.radial-entry[aria-label="Protection from Alignment"]');
    const childSelector=`.radial-entry[aria-label="Protection from ${choice.script==='nw_s0_previl'?'Evil':'Good'}"]`;await wait(`Boolean(document.querySelector(${JSON.stringify(childSelector)}))`);await click(childSelector);
    assert.equal(await evaluate(`document.querySelector('${canvas}').dataset.spellTarget??null`),null);
    const effects=`JSON.parse(document.querySelector('#game-ui').dataset.nativeEffects)`;await wait(`${effects}.effects.some(e=>e.spellId===${choice.spellId}&&e.type===48)&&${effects}.effects.some(e=>e.spellId===${choice.spellId}&&e.type===26)`);await capture();
    const state=await evaluate(effects),armor=state.effects.find(e=>e.spellId===choice.spellId&&e.type===48),save=state.effects.find(e=>e.spellId===choice.spellId&&e.type===26);assert.equal(armor.id,save.id);assert.equal(armor.integers[4],choice.script==='nw_s0_previl'?5:4);assert.equal(save.integers[5],armor.integers[4]);assert.ok(state.icons.some(e=>e.iconId===35));assert.ok(state.icons.some(e=>e.iconId===39));
    await open('spells');await evaluate(`[...document.querySelectorAll('.game-panel-tabs button')].find(b=>b.textContent==='Memorized').click()`);await wait(`document.querySelectorAll('[data-spell-id="${choice.parentId}"][data-spell-ready="0"]').length===${index+1}`);casts.push({choice,state});await click('.game-close');
   }
   await paint();await fs.writeFile(path.join(workspace,'backups/animations/live-versus-casting-ui.png'),(await win.webContents.capturePage()).toPNG());await evaluate('window.flushRuntimeDiagnostics()');const diagnostics=(await fs.readFile(log.path,'utf8')).trim().split('\n').map(JSON.parse),failures=diagnostics.slice(baselineCount).filter(d=>d.severity==='error'||d.level==='error'),knownLoadFailures=failures.filter(d=>d.context?.operation==='native-placeable-pwk-missing-empty-mesh'&&d.message==='Resource plc_w02 (type 2053) was not found in the module, loaded HAKs, or KEY.'),newFailures=failures.filter(d=>!knownLoadFailures.includes(d));
   await fs.writeFile(path.join(workspace,'backups/animations/live-versus-casting-ui.json'),JSON.stringify({playerId:awaitedPlayer,casts,events,errors,knownLoadFailures,newFailures,diagnostics,limits:'Owned cleric BIC selects two legal active first-level prepared protection spells. Real self wheel/class/level selection, automatic canonical self target, cast queue, release, installed authored scripts, conditional effects/icon pools and physical slot consumption. Native AI on; startup/entry fixture. Native icon pool is asserted; HUD buff-art display is not claimed. Known PWK absence retained. Not whole campaign/save/protocol completion.'},null,2));assert.deepEqual(errors,[]);assert.deepEqual(newFailures,[]);console.log('PROTECTION SPELLS VIA RIGHT-CLICK WHEEL, RELEASE, CONDITIONAL EFFECTS/ICONS AND SLOT CONSUMPTION PASS');app.exit(0);return;
  }
  if(process.argv.includes('--rest')){
   await wait(`Boolean(document.querySelector('#game-ui').dataset.nativeInventory)&&Boolean(document.querySelector('#game-ui').dataset.nativeRest)`);
   await evaluate('window.flushRuntimeDiagnostics()');const baselineCount=(await fs.readFile(log.path,'utf8')).trim().split('\n').length,choice=scrollChoices[0];
   const inventory=await evaluate(`JSON.parse(document.querySelector('#game-ui').dataset.nativeInventory)`),scroll=inventory.find(i=>i.baseItem===75&&i.properties[0]?.subtype===choice.subtype);assert.ok(scroll);
   await open('inventory');await evaluate(`[...document.querySelectorAll('.game-panel-tabs button')].find(b=>b.textContent==='Contents').click()`);await click(`.game-item-slot[data-object-id="${scroll.id}"]`,'right');await wait(`Boolean(document.querySelector('.radial-entry[data-action="item.learn"]'))`);await click('.radial-entry[data-action="item.learn"]');await wait(`Boolean(document.querySelector('${canvas}').dataset.lastScrollLearnResult)`);
   const learned=await evaluate(`JSON.parse(document.querySelector('${canvas}').dataset.lastScrollLearnResult)`);assert.equal(learned.result,1);
   await open('spells');await evaluate(`[...document.querySelectorAll('.game-panel-tabs button')].find(b=>b.textContent==='Prepare').click()`);const source=`[data-preparation-kind="1"][data-spell-id="${choice.spellId}"][data-spell-class-index="${choice.classIndex}"]`,destination=`[data-preparation-kind="0"][data-preparation-level="${choice.level}"][data-preparation-slot="0"]`;
   await wait(`Boolean(document.querySelector(${JSON.stringify(source)}))&&Boolean(document.querySelector('#game-ui').dataset.nativeSpellBook)`);await evaluate(`(()=>{const source=document.querySelector(${JSON.stringify(source)}),dest=document.querySelector(${JSON.stringify(destination)}),data=new DataTransfer();source.dispatchEvent(new DragEvent('dragstart',{bubbles:true,dataTransfer:data}));dest.dispatchEvent(new DragEvent('dragover',{bubbles:true,cancelable:true,dataTransfer:data}));dest.dispatchEvent(new DragEvent('drop',{bubbles:true,cancelable:true,dataTransfer:data}));return true;})()`);
   const record=`JSON.parse(document.querySelector('#game-ui').dataset.nativeSpellBook)[${choice.classIndex}].memorized[${choice.level}][0]`,rest=`JSON.parse(document.querySelector('#game-ui').dataset.nativeRest)`;
   await wait(`${record}?.id===${choice.spellId}&&${record}.ready===0`);const prepared=await evaluate(record);
   await click('.game-close');await click('.game-hud-icon[aria-label="Rest"]');await wait(`${rest}.activity===1&&${rest}.timing?.active===1`);await capture();
   await wait(`JSON.parse(document.querySelector('${canvas}').dataset.creatureAnimations).actors.find(a=>a.id===${awaitedPlayer})?.animation===47`);const during=await evaluate(rest);await capture();await paint();await fs.writeFile(path.join(workspace,'backups/animations/live-rest-progress-ui.png'),(await win.webContents.capturePage()).toPNG());
   await wait(`${rest}.activity===0&&${rest}.timing?.active===0`);await capture();const completed=await evaluate(rest);
   await open('spells');await evaluate(`[...document.querySelectorAll('.game-panel-tabs button')].find(b=>b.textContent==='Memorized').click()`);const ready=`[data-spell-id="${choice.spellId}"][data-spell-class-index="${choice.classIndex}"][data-spell-ready="1"]`;await wait(`Boolean(document.querySelector(${JSON.stringify(ready)}))&&${record}.ready===1`);const restored=await evaluate(record);assert.equal(restored.ready,1);
   await click(ready);if(await evaluate(`Boolean(document.querySelector('${canvas}').dataset.spellTarget)`))await selfTarget();await wait(`document.querySelector('${canvas}').dataset.lastSpellAccepted==='1'`);await capture();
   await open('spells');await evaluate(`[...document.querySelectorAll('.game-panel-tabs button')].find(b=>b.textContent==='Memorized').click()`);await wait(`Boolean(document.querySelector('[data-spell-id="${choice.spellId}"][data-spell-ready="0"]'))&&${record}.ready===0`);const used=await evaluate(record);assert.equal(used.ready,0);await capture();
   await click('.game-close');await wait(`${rest}.excited===0`);await click('.game-hud-icon[aria-label="Rest"]');await wait(`${rest}.activity===1&&${rest}.timing?.active===1`);await key('keyDown','Escape','Escape',27);await key('keyUp','Escape','Escape',27);await wait(`${rest}.activity===0&&${rest}.timing?.active===0`);const canceled=await evaluate(rest);
   await open('spells');await evaluate(`[...document.querySelectorAll('.game-panel-tabs button')].find(b=>b.textContent==='Memorized').click()`);await wait(`${record}.ready===0`);await paint();await fs.writeFile(path.join(workspace,'backups/animations/live-rest-completed-ui.png'),(await win.webContents.capturePage()).toPNG());
   await evaluate('window.flushRuntimeDiagnostics()');const diagnostics=(await fs.readFile(log.path,'utf8')).trim().split('\n').map(JSON.parse),failures=diagnostics.slice(baselineCount).filter(d=>d.severity==='error'||d.level==='error');
   const knownLoadFailures=failures.filter(d=>d.context?.operation==='native-placeable-pwk-missing-empty-mesh'&&d.message==='Resource plc_w02 (type 2053) was not found in the module, loaded HAKs, or KEY.'),newFailures=failures.filter(d=>!knownLoadFailures.includes(d));
   const report={playerId:awaitedPlayer,choice,learned,prepared,during,completed,restored,used,canceled,events,errors,failures,knownLoadFailures,newFailures,diagnostics,limits:'Installed wizard plus unchanged active-data-selected scroll UTI fixture. Actual inventory wheel learning, Prepare DOM drop, HUD Rest button and native action42 with progress bar and animation47, restored prepared pool, authored cast selection/self target/slot consumption, second rest canceled through Escape. Native AI enabled, startup/entry fixture. CLI separately verifies impact and healing. Known absent plc_w02 PWK retained separately. No full campaign/save/protocol equivalence claim.'};
   await fs.writeFile(path.join(workspace,'backups/animations/live-rest-ui.json'),JSON.stringify(report,null,2));assert.deepEqual(errors,[]);assert.deepEqual(newFailures,[]);assert.ok(events.some(e=>e.objectId===awaitedPlayer&&e.animation===47&&e.clip==='sitcrossps'));console.log('LEARN, PREPARE, REST, CAST AND CANCEL REST UI PASS');app.exit(0);return;
  }
  if(process.argv.includes('--preparation')){
   await evaluate('window.flushRuntimeDiagnostics()');const baselineCount=(await fs.readFile(log.path,'utf8')).trim().split('\n').length;
   await open('spells');await evaluate(`[...document.querySelectorAll('.game-panel-tabs button')].find(b=>b.textContent==='Prepare').click()`);await wait(`document.querySelectorAll('[data-preparation-kind="0"]').length>0&&Boolean(document.querySelector('#game-ui').dataset.nativeSpellBook)`);
   const book=()=>evaluate(`JSON.parse(document.querySelector('#game-ui').dataset.nativeSpellBook)`),initial=await book(),available=await evaluate(`[...document.querySelectorAll('[data-preparation-kind="1"]')].map(b=>({key:b.dataset.preparationKey,id:Number(b.dataset.spellId),level:Number(b.dataset.preparationLevel),classIndex:Number(b.dataset.spellClassIndex)}))`),slots=await evaluate(`[...document.querySelectorAll('[data-preparation-kind="0"]')].map(b=>({key:b.dataset.preparationKey,id:Number(b.dataset.spellId),level:Number(b.dataset.preparationLevel),slot:Number(b.dataset.preparationSlot),classIndex:Number(b.dataset.spellClassIndex)}))`);
   const destination=slots.find(d=>available.some(s=>s.level===d.level&&s.id!==d.id)),source=available.find(s=>s.level===destination.level&&s.id!==destination.id);assert.ok(source);assert.ok(destination);
   const drop=async(sourceKey,destKey)=>evaluate(`(()=>{const source=document.querySelector('[data-preparation-key="'+${JSON.stringify(sourceKey)}+'"]'),dest=document.querySelector('[data-preparation-key="'+${JSON.stringify(destKey)}+'"]'),data=new DataTransfer();source.dispatchEvent(new DragEvent('dragstart',{bubbles:true,dataTransfer:data}));dest.dispatchEvent(new DragEvent('dragover',{bubbles:true,cancelable:true,dataTransfer:data}));dest.dispatchEvent(new DragEvent('drop',{bubbles:true,cancelable:true,dataTransfer:data}));return JSON.parse(data.getData('application/x-nwn-preparation'));})()`);
   const payload=await drop(source.key,destination.key),record=`JSON.parse(document.querySelector('#game-ui').dataset.nativeSpellBook)[${destination.classIndex}].memorized[${destination.level}][${destination.slot}]`;
   await wait(`${record}?.id===${source.id}&&${record}.ready===0`);const prepared=await book();assert.equal(prepared[destination.classIndex].memorized[destination.level].length,initial[destination.classIndex].memorized[destination.level].length);
   const peer=slots.find(d=>d.level===destination.level&&d.slot!==destination.slot&&d.id>=0&&d.id!==source.id);assert.ok(peer);
   await drop(destination.key,peer.key);const peerRecord=`JSON.parse(document.querySelector('#game-ui').dataset.nativeSpellBook)[${peer.classIndex}].memorized[${peer.level}][${peer.slot}]`;
   await wait(`${record}?.id===${peer.id}&&${record}.ready===0&&${peerRecord}?.id===${source.id}&&${peerRecord}.ready===0`);const exchanged=await book();
   await evaluate(`{const b=document.querySelector('[data-preparation-key="'+${JSON.stringify(peer.key)}+'"]');b.dispatchEvent(new MouseEvent('dblclick',{bubbles:true}));true;}`);await wait(`${peerRecord}===null`);const cleared=await book();
   const metaChoices=await evaluate(`[...document.querySelector('[aria-label="Preparation metamagic"]').options].map(o=>Number(o.value))`);let metamagic=null;
   for(const meta of metaChoices.filter(Boolean)){
    await evaluate(`{const s=document.querySelector('[aria-label="Preparation metamagic"]');s.value=${meta};s.dispatchEvent(new Event('change'));true;}`);
    const pair=await evaluate(`(()=>{const sources=[...document.querySelectorAll('[data-preparation-kind="1"]')],slots=[...document.querySelectorAll('[data-preparation-kind="0"]')];for(const s of sources){const d=slots.find(d=>d.dataset.preparationLevel===s.dataset.preparationLevel);if(d)return{source:s.dataset.preparationKey,destination:d.dataset.preparationKey,id:Number(s.dataset.spellId),level:Number(d.dataset.preparationLevel),slot:Number(d.dataset.preparationSlot),classIndex:Number(d.dataset.spellClassIndex)};}return null;})()`);
    if(!pair)continue;await drop(pair.source,pair.destination);await wait(`JSON.parse(document.querySelector('#game-ui').dataset.nativeSpellBook)[${pair.classIndex}].memorized[${pair.level}][${pair.slot}]?.id===${pair.id}&&JSON.parse(document.querySelector('#game-ui').dataset.nativeSpellBook)[${pair.classIndex}].memorized[${pair.level}][${pair.slot}].metamagic===${meta}&&JSON.parse(document.querySelector('#game-ui').dataset.nativeSpellBook)[${pair.classIndex}].memorized[${pair.level}][${pair.slot}].ready===0`);metamagic={meta,pair,book:await book()};break;
   }
   assert.ok(metamagic,'Installed wizard must exercise a real metamagic preparation');
   await evaluate(`document.querySelector('[data-preparation-key="'+${JSON.stringify(peer.key)}+'"]')?.scrollIntoView({block:'center'});true;`);await paint();await fs.writeFile(path.join(workspace,'backups/animations/live-spell-preparation-ui.png'),(await win.webContents.capturePage()).toPNG());
   await evaluate('window.flushRuntimeDiagnostics()');const diagnostics=(await fs.readFile(log.path,'utf8')).trim().split('\n').map(JSON.parse),failures=diagnostics.slice(baselineCount).filter(d=>d.severity==='error'||d.level==='error');
   const report={playerId:awaitedPlayer,initial,source,destination,peer,payload,prepared,exchanged,cleared,metaChoices,metamagic,errors,failures,diagnostics,limits:'Installed wizard, actual Prepare tab and DOM drag/drop/double-click/select events, copied known spell, exchanged prepared spells, clear/null physical slot, owned metamagic and active cost, every edited record remains unready. Native AI on; startup/entry fixture. Rest/cast-after-rest/domain rendered acceptance/save/reload and campaign not yet validated.'};
   await fs.writeFile(path.join(workspace,'backups/animations/live-spell-preparation-ui.json'),JSON.stringify(report,null,2));assert.deepEqual(errors,[]);assert.deepEqual(failures,[]);console.log('SPELL PREPARATION COPY, SLOT EXCHANGE, CLEAR AND UNREADY POOLS PASS');app.exit(0);return;
  }
  if(process.argv.includes('--scroll-learning')){
   await evaluate('window.flushRuntimeDiagnostics()');const baselineCount=(await fs.readFile(log.path,'utf8')).trim().split('\n').length,
    inventory=()=>evaluate(`JSON.parse(document.querySelector('#game-ui').dataset.nativeInventory)`),initial=await inventory(),scrolls=scrollChoices.map(c=>initial.find(i=>i.baseItem===75&&i.properties[0]?.subtype===c.subtype)),records=[];assert.ok(scrolls.every(Boolean));assert.equal(scrolls[0].stackSize,2);assert.equal(scrolls[1].stackSize,1);
   const inventoryTab=async()=>{await open('inventory');await evaluate(`[...document.querySelectorAll('.game-panel-tabs button')].find(b=>b.textContent==='Contents').click()`);};
   for(const [index,n]of [0,0,1].entries()){
    await inventoryTab();await click(`.game-item-slot[data-object-id="${scrolls[n].id}"]`,'right');await wait(`Boolean(document.querySelector('.radial-entry[data-action="item.learn"]'))`);
    if(index===0){await paint();await fs.writeFile(path.join(workspace,'backups/animations/live-scroll-learning-wheel.png'),(await win.webContents.capturePage()).toPNG());}
    await evaluate(`delete document.querySelector('${canvas}').dataset.lastScrollLearnResult;true`);await click('.radial-entry[data-action="item.learn"]');await wait(`Boolean(document.querySelector('${canvas}').dataset.lastScrollLearnResult)`);
    const result=await evaluate(`JSON.parse(document.querySelector('${canvas}').dataset.lastScrollLearnResult)`);assert.equal(result.ack,1);assert.equal(result.actorId,awaitedPlayer);assert.equal(result.itemId,scrolls[n].id);assert.equal(result.result,index===1?0:1);
    if(n===0)await wait(`JSON.parse(document.querySelector('#game-ui').dataset.nativeInventory).find(i=>i.id===${scrolls[n].id})?.stackSize===1&&JSON.parse(document.querySelector('#game-ui').dataset.nativeInventory).find(i=>i.id===${scrolls[n].id})?.pending===0`);
    else await wait(`!JSON.parse(document.querySelector('#game-ui').dataset.nativeInventory).some(i=>i.id===${scrolls[n].id})`);
    await open('spells');await evaluate(`[...document.querySelectorAll('.game-panel-tabs button')].find(b=>b.textContent==='Spellbook').click()`);await wait(`Boolean(document.querySelector('[data-spell-id="${scrollChoices[n].spellId}"][data-spell-class-index="${scrollChoices[n].classIndex}"]'))`);
    assert.equal(await evaluate(`document.querySelectorAll('[data-spell-id="${scrollChoices[n].spellId}"][data-spell-class-index="${scrollChoices[n].classIndex}"]').length`),1);
    records.push({result,inventory:await inventory(),spellId:scrollChoices[n].spellId,panel:await evaluate(`document.querySelector('#game-ui').dataset.panel`)});
   }
   await evaluate(`document.querySelector('[data-spell-id="${scrollChoices.at(-1).spellId}"][data-spell-class-index="${scrollChoices.at(-1).classIndex}"]').scrollIntoView({block:'center'});true`);await paint();await fs.writeFile(path.join(workspace,'backups/animations/live-scroll-learning-book.png'),(await win.webContents.capturePage()).toPNG());
   await evaluate('window.flushRuntimeDiagnostics()');const diagnostics=(await fs.readFile(log.path,'utf8')).trim().split('\n').map(JSON.parse),failures=diagnostics.slice(baselineCount).filter(d=>d.severity==='error'||d.level==='error'),knownLoadFailures=failures.filter(d=>d.context?.operation==='native-placeable-pwk-missing-empty-mesh'&&d.message==='Resource plc_w02 (type 2053) was not found in the module, loaded HAKs, or KEY.'),newFailures=failures.filter(d=>!knownLoadFailures.includes(d));
   const report={playerId:awaitedPlayer,scrollChoices,scrolls,records,errors,baselineCount,failures,knownLoadFailures,newFailures,diagnostics,limits:'Two unchanged installed scroll UTI records selected using live class/spell/school/known data, added only to an owned in-memory wizard BIC. Real inventory right-click Learn Scroll, native menu pending, input13/LearnScroll/reply14, canonical known pool visible in spellbook, duplicate rejection, stack decrease and last-scroll immediate destruction. Startup/entry-position fixture; native AI stays on. Known missing PWK and all presentation warnings retained. No full spell/combat/campaign or native GUI/packet equivalence claim.'};
   await fs.writeFile(path.join(workspace,'backups/animations/live-scroll-learning-ui.json'),JSON.stringify(report,null,2));assert.deepEqual(errors,[]);assert.deepEqual(newFailures,[]);console.log('RIGHT-CLICK SCROLL LEARNING, SPELLBOOK UPDATE, DUPLICATE REJECTION, STACK AND DESTRUCTION PASS');app.exit(0);return;
  }
  if(process.argv.includes('--item-use')||process.argv.includes('--default-item')){
   const defaultItem=process.argv.includes('--default-item'),artifact=defaultItem?'default-item':'item-use';
   await evaluate('window.flushRuntimeDiagnostics()');const baselineCount=(await fs.readFile(log.path,'utf8')).trim().split('\n').length;
   const inventory=()=>evaluate(`JSON.parse(document.querySelector('#game-ui').dataset.nativeInventory)`),initial=await inventory(),potion=initial.find(i=>i.baseItem===49&&i.properties.some(p=>p.type===15));assert.ok(potion);assert.equal(potion.stackSize,3);
   const inventoryTab=async()=>{await open('inventory');await evaluate(`[...document.querySelectorAll('.game-panel-tabs button')].find(b=>b.textContent==='Contents').click()`);};
   const itemSelector=`.game-item-slot[data-object-id="${potion.id}"]`,useSelector='.radial-entry[data-action="item.use"][draggable="true"]';
   await inventoryTab();await click(itemSelector,'right');await wait(`Boolean(document.querySelector('${useSelector}'))`);
   const menu=await evaluate(`[...document.querySelectorAll('.radial-entry')].map(b=>({slot:Number(b.dataset.slot),label:b.getAttribute('aria-label'),binding:b.dataset.quickbarBinding??null}))`);
   assert.equal(menu.find(e=>e.binding)?.slot,3);await fs.writeFile(path.join(workspace,`backups/animations/live-${artifact}-wheel.png`),(await win.webContents.capturePage()).toPNG());
   const binding=await drag(defaultItem?itemSelector:useSelector,1);assert.equal(binding.binding.type,1);assert.equal(binding.binding.itemId,potion.id);assert.equal(binding.binding.intParam,defaultItem?0xff00ff:0xff0000);
   await wait(`JSON.parse(document.querySelector('#game-ui').dataset.quickbar)[1].itemId===${potion.id}&&JSON.parse(document.querySelector('#game-ui').dataset.quickbar)[1].intParam===0xff0000`);
   await evaluate(`document.querySelector('${useSelector}').dispatchEvent(new DragEvent('dragend',{bubbles:true}));true`);assert.equal((await buttons())[1].itemId,potion.id);
   assert.equal(await evaluate(`document.querySelector('.game-quick-slot[data-slot="1"]').dataset.uses`),'3');
   await fs.writeFile(path.join(workspace,`backups/animations/live-${artifact}-assigned.png`),(await win.webContents.capturePage()).toPNG());
   await click(itemSelector,'right');await click(useSelector);await wait(`document.querySelector('${canvas}').dataset.lastItemInputResult==='0'`);
   const records=[];
   for(let n=0;n<3;n++){
    if(n){await evaluate(`delete document.querySelector('${canvas}').dataset.lastItemInputResult;true`);await key('keyDown','F2','F2',113);await key('keyUp','F2','F2',113);await wait(`document.querySelector('${canvas}').dataset.lastItemInputResult==='0'`);}
    await wait(n<2?`JSON.parse(document.querySelector('#game-ui').dataset.nativeInventory).find(i=>i.id===${potion.id})?.stackSize===${2-n}`:`!JSON.parse(document.querySelector('#game-ui').dataset.nativeInventory).some(i=>i.id===${potion.id})`);
    await capture();await wait(`JSON.parse(document.querySelector('#game-ui').dataset.nativeActionQueue).every(r=>r.action===65535&&r.special===65535)`);
    records.push({path:n?'F2':'item-wheel',request:await evaluate(`JSON.parse(document.querySelector('${canvas}').dataset.lastItemRequest)`),inventory:await inventory(),quickbar:await buttons()});
    assert.equal(records[n].request.itemId,potion.id);assert.equal(records[n].request.targetId,awaitedPlayer);
   }
   assert.equal((await buttons())[1].type,0);const drinks=events.filter(e=>e.objectId===awaitedPlayer&&e.animation===70);assert.ok(drinks.length>=3);assert.ok(drinks.every(e=>e.clip==='drink'));assert.equal(await player(),awaitedPlayer);
   await fs.writeFile(path.join(workspace,`backups/animations/live-${artifact}-hotbar.png`),(await win.webContents.capturePage()).toPNG());
   await evaluate('window.flushRuntimeDiagnostics()');const diagnostics=(await fs.readFile(log.path,'utf8')).trim().split('\n').map(JSON.parse),failures=diagnostics.slice(baselineCount).filter(r=>r.severity==='error'||r.level==='error');
   const knownLoadFailures=failures.filter(r=>r.context?.operation==='native-placeable-pwk-missing-empty-mesh'&&r.message==='Resource plc_w02 (type 2053) was not found in the module, loaded HAKs, or KEY.'),newFailures=failures.filter(r=>!knownLoadFailures.includes(r));
   const spellMessages=await evaluate(`JSON.parse(document.querySelector('${canvas}').dataset.spellMessages)`),itemNotices=spellMessages.events.filter(e=>e.sourceId===((awaitedPlayer|0x80000000)>>>0)&&e.hasItem===1);assert.ok(itemNotices.length>=3);assert.ok(itemNotices.every(e=>e.identified===1&&e.casting===0&&e.text&&!e.text.includes('<CUSTOM')));assert.equal(diagnostics.filter(d=>d.code==='spell.client-message-failed'||d.code==='spell.client-message-unimplemented').length,0);
   const logMessages=await evaluate(`[...document.querySelectorAll('.game-message.combat')].map(e=>e.textContent)`);assert.ok(logMessages.filter(text=>text===itemNotices[0].text).length>=3,'Each consumed item must create its own log row, including repeated identical messages');
   const report={defaultItem,playerId:awaitedPlayer,potion,menu,binding,records,events,spellMessages,errors,baselineCount,failures,knownLoadFailures,newFailures,diagnostics,limits:`Unchanged installed wizard inventory; Prelude entry-position/startup-off UI fixture, native AI remains enabled. Actual item wheel and F2 keyboard input, DOM drag/drop events for the ${defaultItem?'whole-item default':'explicit property'} binding, native target/decoded input9, action46 animation70 with real drink clip, stack consumption through exhaustion and automatic canonical shortcut removal; native CC8 identified item-use text through consumption. Known absent plc_w02 walkmesh retained separately from new failures. No scroll/wand/variant rendered acceptance, spell preview or campaign completion claim.`};
   await fs.writeFile(path.join(workspace,`backups/animations/live-${artifact}-ui.json`),JSON.stringify(report,null,2));assert.deepEqual(errors,[]);assert.deepEqual(newFailures,[]);
   console.log('ITEM WHEEL, ACTIVE PROPERTY DRAG/DROP, F2 CASTING, DRINK ANIMATION, CONSUMPTION AND SHORTCUT REMOVAL PASS');app.exit(0);return;
  }
  if(process.argv.includes('--feats')||featRadial){
   await evaluate('window.flushRuntimeDiagnostics()');const baselineCount=(await fs.readFile(log.path,'utf8')).trim().split('\n').length;
   const state=()=>evaluate(`JSON.parse(document.querySelector('${canvas}').dataset.characterAppearance)`),before=await state(),feats=async()=>{await open('spells');await evaluate(`[...document.querySelectorAll('.game-panel-tabs button')].find(b=>b.textContent==='Feats').click()`);};
   await feats();await wait(`Boolean(document.querySelector('[data-feat-id="338"]'))`);const usesBefore=await evaluate(`Number(document.querySelector('[data-feat-id="338"]').dataset.featRemaining)`),binding=await drag('[data-feat-id="338"]',1);assert.equal(binding.binding.type,4);await click('.game-close');
   await key('keyDown','F2','F2',113);await key('keyUp','F2','F2',113);await wait(`document.querySelector('${canvas}').dataset.lastFeatAccepted==='1'`);assert.equal(await evaluate(`document.querySelector('${canvas}').dataset.spellTarget??null`),null);
   await wait(`JSON.parse(document.querySelector('${canvas}').dataset.characterAppearance).polymorphed===1`);await wait(`JSON.parse(document.querySelector('${canvas}').dataset.characterAppearance).model!==${JSON.stringify(before.model)}`);await capture();const transformed=await state();
   const request=await evaluate(`JSON.parse(document.querySelector('${canvas}').dataset.lastFeatRequest)`);assert.equal(request.featId,338);assert.equal(request.targetId,awaitedPlayer);assert.equal(await player(),awaitedPlayer);
   await feats();await wait(`Number(document.querySelector('[data-feat-id="338"]').dataset.featRemaining)===${usesBefore-1}`);await click('.game-close');
   await click('#player-actions','right');await wait(`Boolean(document.querySelector('.radial-entry[aria-label="Cancel polymorph"]'))`);await click('.radial-entry[aria-label="Cancel polymorph"]');
   await wait(`JSON.parse(document.querySelector('${canvas}').dataset.characterAppearance).polymorphed===0`);await wait(`JSON.parse(document.querySelector('${canvas}').dataset.characterAppearance).model===${JSON.stringify(before.model)}`);const restored=await state();assert.equal(restored.id,before.id);assert.equal(await player(),awaitedPlayer);
   let radial=null;
   if(featRadial){
    await click('#player-actions','right');await click('.radial-entry[aria-label="Special abilities"]');
    const root=await evaluate(`[...document.querySelectorAll('.radial-entry')].map(b=>({slot:Number(b.dataset.slot),label:b.getAttribute('aria-label'),action:b.dataset.action}))`);
    assert.equal(root.find(e=>e.label==='Druid')?.slot,5);assert.equal(root.some(e=>e.action==='ability.class'),false);
    await click('.radial-entry[aria-label="Druid"]');await wait(`Boolean(document.querySelector('.radial-entry[data-feat-id="338"][data-action="submenu"]'))`);
    await click('.radial-entry[data-feat-id="338"][data-action="submenu"]');
    await wait(`document.querySelectorAll('.radial-entry[data-feat-id="338"][data-action="feat.use"]').length===5`);
    const choices=await evaluate(`[...document.querySelectorAll('.radial-entry[data-action="feat.use"]')].map(b=>({label:b.getAttribute('aria-label'),slot:Number(b.dataset.slot),auxiliary:Number(b.dataset.featAuxiliary)}))`),choice=choices[0];
    assert.equal(await evaluate(`Number(document.querySelector('.radial-entry[data-action="feat.use"]').dataset.uses)`),usesBefore-1);
    await fs.writeFile(path.join(workspace,'backups/animations/live-feat-radial-choices.png'),(await win.webContents.capturePage()).toPNG());
    assert.ok(choices.every(c=>c.auxiliary>=1008&&c.auxiliary<=1012));await evaluate(`delete document.querySelector('${canvas}').dataset.lastFeatAccepted;true`);
    await click(`.radial-entry[data-feat-auxiliary="${choice.auxiliary}"]`);await wait(`document.querySelector('${canvas}').dataset.lastFeatAccepted==='1'`);
    const selected=await evaluate(`JSON.parse(document.querySelector('${canvas}').dataset.lastFeatRequest)`);assert.equal(selected.featId,338);assert.equal(selected.auxiliary,choice.auxiliary);assert.equal(selected.targetId,awaitedPlayer);
    await wait(`JSON.parse(document.querySelector('${canvas}').dataset.characterAppearance).polymorphed===1`);await wait(`JSON.parse(document.querySelector('${canvas}').dataset.characterAppearance).model!==${JSON.stringify(before.model)}`);const form=await state();await capture();
    await feats();await wait(`Number(document.querySelector('[data-feat-id="338"]').dataset.featRemaining)===${usesBefore-2}`);await click('.game-close');
    await click('#player-actions','right');await click('.radial-entry[aria-label="Cancel polymorph"]');await wait(`JSON.parse(document.querySelector('${canvas}').dataset.characterAppearance).polymorphed===0`);await wait(`JSON.parse(document.querySelector('${canvas}').dataset.characterAppearance).model===${JSON.stringify(before.model)}`);
    assert.equal(await player(),awaitedPlayer);radial={root,choices,selected,form,usesAfter:usesBefore-2,restored:await state()};
   }
   await new Promise(resolve=>setTimeout(resolve,250));await fs.writeFile(path.join(workspace,`backups/animations/live-feat-${featRadial?'radial':'casting'}-ui.png`),(await win.webContents.capturePage()).toPNG());await evaluate('window.flushRuntimeDiagnostics()');
   const diagnostics=(await fs.readFile(log.path,'utf8')).trim().split('\n').map(JSON.parse),failures=diagnostics.slice(baselineCount).filter(r=>r.severity==='error'||r.level==='error'),knownLoadFailures=failures.filter(r=>r.context?.operation==='native-placeable-pwk-missing-empty-mesh'&&r.message==='Resource plc_w02 (type 2053) was not found in the module, loaded HAKs, or KEY.'),newFailures=failures.filter(r=>!knownLoadFailures.includes(r));
   await fs.writeFile(path.join(workspace,`backups/animations/live-feat-${featRadial?'radial':'casting'}-ui.json`),JSON.stringify({playerId:awaitedPlayer,binding,request,usesBefore,usesAfter:usesBefore-1,before,transformed,restored,radial,events,errors,baselineCount,failures,knownLoadFailures,newFailures,diagnostics,limits:'Installed unchanged druid BIC, actual owned338 Wild Shape feat dragged to type4/F2. Native client automatic self targeting, input6, UseFeat variant/spell selection, casting/feat consumption, authored shape script, model rebind and radial restoration. Optional radial branch validates class slot5, WildShape submenu and selected physical variant, second consumption and restoration. Entry-position/startup-off fixture. Known absent plc_w02.pwk retained separately; not all classes/feats or campaign acceptance.'},null,2));assert.equal(errors.length,0);assert.equal(newFailures.length,0);
   console.log('OWNED DRUID FEAT TYPE4/F2, AUTO SELF, CAST PHASES, FEAT USE, LIVE FORM AND RADIAL RESTORATION PASS');app.exit(0);return;
  }
  if(process.argv.includes('--abilities')){
   await evaluate('window.flushRuntimeDiagnostics()');const baselineCount=(await fs.readFile(log.path,'utf8')).trim().split('\n').length;
   const abilities=async()=>{await open('spells');await evaluate(`[...document.querySelectorAll('.game-panel-tabs button')].find(b=>b.textContent==='Abilities').click()`);};
   await abilities();await wait(`document.querySelectorAll('[data-ability-spell-id="126"][data-ability-remaining="1"]').length===2`);
   const binding=await drag('[data-ability-spell-id="126"]',1);assert.equal(binding.binding.type,44);assert.equal(binding.binding.domainLevel,8);await click('.game-close');
   await key('keyDown','F2','F2',113);await key('keyUp','F2','F2',113);await wait(`document.querySelector('${canvas}').dataset.spellTarget==='126'`);await selfTarget();
   await wait(`document.querySelector('${canvas}').dataset.lastSpellAccepted==='0'`);await capture();
   const first=await evaluate(`JSON.parse(document.querySelector('${canvas}').dataset.lastSpellRequest)`);assert.equal(first.action,'spellLike.use');assert.equal(first.targetId,awaitedPlayer);
   await abilities();await wait(`document.querySelectorAll('[data-ability-spell-id="126"][data-ability-remaining="0"]').length===1`);await click('.game-close');
   await click('#player-actions','right');await wait(`!document.querySelector('.radial-overlay').hidden`);await click('.radial-entry[aria-label="Special abilities"]');await click('.radial-entry[aria-label="Innate abilities"]');
   await wait(`document.querySelectorAll('.radial-entry[data-action="spellLike.use"]:not(:disabled)').length===1`);
   await click('.radial-entry[data-action="spellLike.use"]');await capture();
   const second=await evaluate(`JSON.parse(document.querySelector('${canvas}').dataset.lastSpellRequest)`);assert.equal(second.action,'spellLike.use');assert.equal(second.targetId,awaitedPlayer);assert.equal(second.domainLevel,8);
   await abilities();await wait(`document.querySelectorAll('[data-ability-spell-id="126"][data-ability-remaining="0"]').length===2`);await click('.game-close');await capture();
   await click('#player-actions','right');await wait(`!document.querySelector('.radial-overlay').hidden`);await click('.radial-entry[aria-label="Special abilities"]');await click('.radial-entry[aria-label="Innate abilities"]');
   await wait(`document.querySelectorAll('.radial-entry[data-action="spellLike.use"]:disabled').length===1`);
   await new Promise(resolve=>setTimeout(resolve,250)); // Capture the rendered frame after DOM admission.
   await fs.writeFile(path.join(workspace,'backups/animations/live-spell-like-ui.png'),(await win.webContents.capturePage()).toPNG());await evaluate('window.flushRuntimeDiagnostics()');
   const diagnostics=(await fs.readFile(log.path,'utf8')).trim().split('\n').map(JSON.parse),failures=diagnostics.slice(baselineCount).filter(r=>r.severity==='error'||r.level==='error');
   const knownLoadFailures=failures.filter(r=>r.context?.operation==='native-placeable-pwk-missing-empty-mesh'&&r.message==='Resource plc_w02 (type 2053) was not found in the module, loaded HAKs, or KEY.'),newFailures=failures.filter(r=>!knownLoadFailures.includes(r));
   await fs.writeFile(path.join(workspace,'backups/animations/live-spell-like-ui.json'),JSON.stringify({playerId:awaitedPlayer,binding,first,second,events,errors,baselineCount,failures,knownLoadFailures,newFailures,diagnostics,limits:'Owned in-memory BIC copies two original NPC ability126/caster8 entries. Real import, Abilities drag to type44/F2, world self selection, native input35 return0 after dispatch, normal casting/consumption, second duplicate via Special abilities/Innate abilities radial and spent-entry disabling. Existing absent plc_w02.pwk is separately retained/asserted; no new failures allowed. Startup-off entry fixture, not clean whole-area, campaign or full class/feat ability acceptance.'},null,2));assert.equal(errors.length,0);assert.equal(newFailures.length,0);console.log('KNOWN INSTALLED PWK LOAD FAILURES RETAINED',knownLoadFailures.length);
   console.log('SPELL-LIKE BIC IMPORT, TYPE44 DRAG/F2, WORLD TARGET, DUPLICATE CONSUMPTION AND INNATE RADIAL PASS');app.exit(0);return;
  }
  if(polymorphMode){
   await evaluate('window.flushRuntimeDiagnostics()');const baselineCount=(await fs.readFile(log.path,'utf8')).trim().split('\n').length;
   const state=()=>evaluate(`JSON.parse(document.querySelector('${canvas}').dataset.characterAppearance)`),before=await state();
   await open('spells');await evaluate(`[...document.querySelectorAll('.game-panel-tabs button')].find(b=>b.textContent==='Memorized').click()`);
   await wait(`Boolean(document.querySelector('[data-spell-id="130"][data-spell-ready="1"]'))`);const binding=await drag('[data-spell-id="130"][data-spell-ready="1"]',1);await click('.game-close');
   const choose=async slot=>{await key('keyDown',String(slot+1),'Digit'+(slot+1),49+slot);await key('keyUp',String(slot+1),'Digit'+(slot+1),49+slot);};
   if(polymorphHotbar){await key('keyDown','F2','F2',113);await key('keyUp','F2','F2',113);}
   else{
   await click('#player-actions','right');await wait(`!document.querySelector('.radial-overlay').hidden`);assert.equal(await evaluate(`Boolean(document.querySelector('.radial-entry[aria-label="Cancel polymorph"]'))`),false);
   await choose(1);await choose(5);await choose(4);await wait(`Boolean([...document.querySelectorAll('.radial-entry')].find(b=>/polymorph self/i.test(b.getAttribute('aria-label'))))`);
   await evaluate(`[...document.querySelectorAll('.radial-entry')].find(b=>/polymorph self/i.test(b.getAttribute('aria-label'))).click()`);
   await wait(`Boolean([...document.querySelectorAll('.radial-entry')].find(b=>/giant spider/i.test(b.getAttribute('aria-label'))))`);
   await evaluate(`[...document.querySelectorAll('.radial-entry')].find(b=>/giant spider/i.test(b.getAttribute('aria-label'))).click()`);
   }
   await wait(`JSON.parse(document.querySelector('${canvas}').dataset.characterAppearance).polymorphed===1`);await wait(`JSON.parse(document.querySelector('${canvas}').dataset.characterAppearance).model!==${JSON.stringify(before.model)}`);await capture();const transformed=await state();
   assert.notEqual(transformed.id,before.id);assert.equal(await player(),awaitedPlayer);assert.equal(await evaluate(`JSON.parse(document.querySelector('${canvas}').dataset.lastSpellRequest).spellId`),polymorphHotbar?130:387);
   await fs.writeFile(path.join(workspace,'backups/animations/live-polymorph-transformed.png'),(await win.webContents.capturePage()).toPNG());
   await click('#player-actions','right');await wait(`Boolean(document.querySelector('.radial-entry[aria-label="Cancel polymorph"]'))`);await click('.radial-entry[aria-label="Cancel polymorph"]');
   await wait(`JSON.parse(document.querySelector('${canvas}').dataset.characterAppearance).polymorphed===0`);await wait(`JSON.parse(document.querySelector('${canvas}').dataset.characterAppearance).model===${JSON.stringify(before.model)}`);const restored=await state();assert.equal(restored.id,before.id);assert.equal(await player(),awaitedPlayer);
   await open('spells');await evaluate(`[...document.querySelectorAll('.game-panel-tabs button')].find(b=>b.textContent==='Memorized').click()`);assert.equal(await evaluate(`document.querySelectorAll('[data-spell-id="130"][data-spell-ready="0"]').length`),1);await click('.game-close');
   await fs.writeFile(path.join(workspace,'backups/animations/live-polymorph-restored.png'),(await win.webContents.capturePage()).toPNG());await evaluate('window.flushRuntimeDiagnostics()');const diagnostics=(await fs.readFile(log.path,'utf8')).trim().split('\n').map(JSON.parse),failures=diagnostics.slice(baselineCount).filter(r=>r.severity==='error'||r.level==='error');
   await fs.writeFile(path.join(workspace,`backups/animations/live-polymorph-${polymorphHotbar?'hotbar-':''}ui.json`),JSON.stringify({playerId:awaitedPlayer,binding,before,transformed,restored,events,errors,baselineCount,failures,diagnostics,limits:`Real authored spell${polymorphHotbar?'130 through F2 parent activation':'387 through self radial'}/normal cast admission, prepared parent130 slot, conjure/release/impact, canonical form/equipment/stat lifecycle, asynchronous mesh/animation rebind and radial cancellation. All load diagnostics retained; casting-phase failures asserted separately. In-memory wizard spell-selection and entry-position/startup-off fixture; no installed writes or campaign/combat completion claim.`},null,2));assert.equal(errors.length,0);assert.equal(failures.length,0);
   console.log(`AUTHORED POLYMORPH ${polymorphHotbar?'F2 PARENT':'SELF RADIAL'} CAST, PREPARED SLOT, LIVE MESH/ANIMATION REBIND, CANONICAL ID AND RADIAL RESTORATION PASS`);app.exit(0);return;
  }
  if(process.argv.includes('--items')){
   await evaluate(`globalThis.itemVisualFrames=[];globalThis.itemVisualTimer=setInterval(()=>{const canvas=document.querySelector('#model-canvas'),entries=JSON.parse(canvas.dataset.loopingVisuals??'[]').filter(v=>v.transient);if(entries.length&&itemVisualFrames.length<400)itemVisualFrames.push({at:performance.now(),entries,particles:JSON.parse(canvas.dataset.modelParticles??'[]'),pointWinds:JSON.parse(canvas.dataset.pointWinds??'{"records":[]}')});},25)`);
   await fs.writeFile(path.join(workspace,'backups/animations/live-item-light-before.png'),(await win.webContents.capturePage()).toPNG());
   const openSpells=async()=>{await open('spells');await evaluate(`[...document.querySelectorAll('.game-panel-tabs button')].find(b=>b.textContent==='Memorized').click()`);};
   const inventoryTab=async label=>{await open('inventory');await evaluate(`[...document.querySelectorAll('.game-panel-tabs button')].find(b=>b.textContent===${JSON.stringify(label)}).click()`);};
   const latest=()=>evaluate(`({request:JSON.parse(document.querySelector('${canvas}').dataset.lastSpellRequest),accepted:Number(document.querySelector('${canvas}').dataset.lastSpellAccepted)})`);
   const record=[];
   await openSpells();await wait(`Boolean(document.querySelector('[data-spell-id="545"][data-spell-ready="1"]'))`);
   const binding=await drag('[data-spell-id="545"][data-spell-ready="1"]',1);
   // Spellbook -> keep target mode while opening inventory -> equipped robe.
   await click('[data-spell-id="100"][data-spell-ready="1"]');await wait(`document.querySelector('${canvas}').dataset.spellTarget==='100'`);
   await inventoryTab('Equipment');assert.equal(await evaluate(`document.querySelector('${canvas}').dataset.spellTarget`),'100');
   const armorSelector='.game-equipment button[data-object-id]',armorId=await evaluate(`Number(document.querySelector('${armorSelector}').dataset.objectId)`);
   await click(armorSelector);await wait(`document.querySelector('${canvas}').dataset.lastSpellAccepted==='1'`);
   assert.equal((await latest()).request.targetId,armorId);assert.equal(await evaluate(`document.querySelector('#game-ui').dataset.panel`),'inventory');
   record.push({form:'spellbook-equipment',...await latest()});
   await wait(`JSON.parse(document.querySelector('${canvas}').dataset.loopingVisuals??'[]').some(v=>v.objectId===${awaitedPlayer}&&v.ready&&v.presentation?.lights.some(l=>!l.ambient&&l.radius>0&&l.intensity>0)&&!v.presentation.playing)`);
   const lightPresentation=await evaluate(`JSON.parse(document.querySelector('${canvas}').dataset.loopingVisuals)`);
   assert.equal(lightPresentation.filter(v=>v.ready&&v.objectId===awaitedPlayer).length,1);
   assert.ok(lightPresentation.filter(v=>v.ready&&v.objectId===awaitedPlayer).every(v=>v.presentation.nativePose));
   assert.ok(lightPresentation.filter(v=>v.ready&&v.objectId===awaitedPlayer).every(v=>v.attached&&v.presentation.lights.every(l=>l.priority===2)));
   await click('.game-close');await wait(`!document.querySelector('#game-ui').dataset.panel`);await new Promise(r=>setTimeout(r,250));
   await fs.writeFile(path.join(workspace,'backups/animations/live-item-light-after.png'),(await win.webContents.capturePage()).toPNG());
   await openSpells();await wait(`document.querySelectorAll('[data-spell-id="100"][data-spell-ready="0"]').length===1`);
   // Actual F2 binding -> inventory contents -> canonical carried dagger.
   await key('keyDown','F2','F2',113);await key('keyUp','F2','F2',113);await wait(`document.querySelector('${canvas}').dataset.spellTarget==='545'`);
   await inventoryTab('Contents');
   const daggerId=await evaluate(`Number([...document.querySelectorAll('.game-item-slot[data-object-id]')].find(b=>/dagger/i.test(b.textContent))?.dataset.objectId)`);assert.ok(Number.isInteger(daggerId)&&daggerId>0);
   const daggerSelector='.game-item-slot[data-object-id="'+daggerId+'"]';await click(daggerSelector);
   await wait(`document.querySelector('${canvas}').dataset.lastSpellAccepted==='1'`);assert.equal((await latest()).request.targetId,daggerId);
   record.push({form:'hotbar-inventory',...await latest()});
   await openSpells();await wait(`document.querySelectorAll('[data-spell-id="545"][data-spell-ready="0"]').length===1`);
   // Native item radial: Cast spell -> ordinary class entry -> cantrips.
   await inventoryTab('Contents');await click(daggerSelector,'right');await wait(`!document.querySelector('.radial-overlay').hidden`);
   await click('.radial-entry[aria-label="Cast spell"]');
   const classEntries=await evaluate(`[...document.querySelectorAll('.radial-entry')].map(b=>b.getAttribute('aria-label'))`);assert.ok(classEntries.includes('Wizard'));
   await click('.radial-entry[aria-label="Wizard"]');await click('.radial-entry[aria-label="Cantrips"]');await wait(`Boolean(document.querySelector('.radial-entry[aria-label="Light"]:not(:disabled)'))`);
   await new Promise(r=>setTimeout(r,250)); // Wait for the captured compositor frame, not only DOM mutation.
   await fs.writeFile(path.join(workspace,'backups/animations/live-item-spell-wheel-ui.png'),(await win.webContents.capturePage()).toPNG());
   await click('.radial-entry[aria-label="Light"]');await wait(`document.querySelector('${canvas}').dataset.lastSpellAccepted==='1'`);
   assert.equal((await latest()).request.targetId,daggerId);assert.equal(await evaluate(`document.querySelector('${canvas}').dataset.spellTarget??null`),null);
   record.push({form:'item-right-click-radial',...await latest()});
   await openSpells();await wait(`document.querySelectorAll('[data-spell-id="100"][data-spell-ready="0"]').length===2`);
   // OnApplyItemProperty14042e83e gates materialization on equipped lookup.
   // The carried dagger gains the property, but does not add a second actor
   // light. Physical duplicate selection is covered independently against the
   // native selection owner and asynchronous presenter regression.
   const afterCarriedLight=await evaluate(`JSON.parse(document.querySelector('${canvas}').dataset.loopingVisuals??'[]').filter(v=>v.ready&&v.objectId===${awaitedPlayer})`);
   const actorLights=afterCarriedLight.filter(v=>v.presentation.lights.length>0);
   assert.equal(actorLights.length,lightPresentation.filter(v=>v.ready&&v.objectId===awaitedPlayer&&v.presentation.lights.length>0).length);
   assert.equal(actorLights.filter(v=>v.attached).length,1);assert.ok(actorLights.every(v=>v.presentation.lights.every(l=>l.priority===2)));
   // The full loader now also admits the authored positive item buff. Its
   // model has cessation only: it stays dormant while the buff is active.
   const positive=afterCarriedLight.find(v=>v.presentation.models.includes('vce_positive'));
   assert.ok(positive);assert.equal(positive.presentation.playing,false);assert.equal(positive.presentation.time,0);
   await wait(`!JSON.parse(document.querySelector('${canvas}').dataset.loopingVisuals??'[]').some(v=>v.transient)`);
   const instantVisualFrames=await evaluate(`{clearInterval(itemVisualTimer);itemVisualFrames;}`);
   assert.ok(instantVisualFrames.some(f=>f.entries.some(v=>v.ready&&v.presentation.nativePose&&v.attached)),'Authored item cast must deliver and render its one-shot visual');
   const instantModels=[...new Set(instantVisualFrames.flatMap(f=>f.entries.flatMap(v=>v.presentation?.models??[])))];
   assert.ok(instantVisualFrames.some(f=>f.particles.some(p=>instantModels.includes(p.model)&&p.vertices>0)),'Authored one-shot must generate live particle vertices');
   assert.ok(instantVisualFrames.some(f=>f.pointWinds.records.length>0),'Authored Detonate must deliver its helper emitter point-wind burst');
   assert.equal(await evaluate(`JSON.parse(document.querySelector('${canvas}').dataset.pointWinds).records.length`),0);
   // A pending item spell is canceled by right-click without opening a wheel.
   await click('[data-spell-id="100"][data-spell-ready="0"]');await inventoryTab('Contents');await click(daggerSelector,'right');
   assert.equal(await evaluate(`document.querySelector('${canvas}').dataset.spellTarget??null`),null);assert.equal(await evaluate(`document.querySelector('.radial-overlay').hidden`),true);
   assert.equal(await evaluate(`document.querySelector('.game-notice').textContent`),'Spell targeting canceled');await new Promise(r=>setTimeout(r,250));
   assert.equal(errors.length,0);await fs.writeFile(path.join(workspace,'backups/animations/live-item-targeting-ui.png'),(await win.webContents.capturePage()).toPNG());
   await evaluate('window.flushRuntimeDiagnostics()');const diagnostics=(await fs.readFile(log.path,'utf8')).trim().split('\n').map(JSON.parse),engineFailures=diagnostics.filter(r=>r.code==='engine.unimplemented'||r.code==='engine.failed');
   assert.deepEqual(diagnostics.filter(r=>['visual.load-failed','visual.update-failed','visual.selection-failed','visual.stop-failed','visual.message-failed','visual.message-target-stale','visual.message-area-stale'].includes(r.code)||r.code==='particle.runtime-unavailable'&&['fx_light_clr','vce_positive',...instantModels].includes(r.context?.model)||r.code==='combat.presentation-unimplemented'&&r.context?.messageType==='visualEffect'),[]);
   await fs.writeFile(path.join(workspace,'backups/animations/live-item-targeting-ui.json'),JSON.stringify({playerId:awaitedPlayer,armorId,daggerId,binding,record,lightPresentation,afterCarriedLight,instantVisualFrames,used:{light:2,greaterMagicWeapon:1},errors,engineFailures,diagnostics,runtimeLog:path.relative(workspace,log.path),limits:'Real installed wizard memorized slots and UI spellbook/F2/item wheel. Prepared Light on equipped robe asserts canonical duration model/light binding, native local attachment/start, completed authored fade-in and player light priority2. Light on carried dagger does not materialize another actor light before equipment admission. Full loader also admits positive item buff geometry, dormant until its authored cessation phase. Authored one-shot message delivery is observed ready, attached and using native pose, and the transient list empties naturally. Duplicate selection is independently native-compared and presenter tested, not asserted by this carried-item workflow. Before/after screenshots and all runtime diagnostics retained. In-memory entry position/startup fixture, not campaign acceptance.'},null,2));
   assert.deepEqual(engineFailures.filter(r=>/nw_s0_light|x2_s0_grmagweap/i.test(r.context?.script??'')),[]);
   console.log('PREPARED SPELLBOOK EQUIPMENT TARGET, F2 CARRIED ITEM TARGET, NATIVE ITEM SPELL WHEEL, REAL SLOT CONSUMPTION AND RIGHT-CLICK CANCELLATION PASS',armorId,daggerId);console.log('ENGINE OMISSIONS',JSON.stringify(engineFailures.map(r=>r.context?.engineCall)));app.exit(0);return;
  }
  const chooseWheel=async slot=>{await key('keyDown',String(slot+1),`Digit${slot+1}`,49+slot);await key('keyUp',String(slot+1),`Digit${slot+1}`,49+slot);};
  for(const state of ['enabled','disabled']){
    await click('#player-actions','right');await wait(`!document.querySelector('.radial-overlay').hidden`);
    await chooseWheel(1);await chooseWheel(6);await chooseWheel(1);
    await wait(`document.querySelector('#game-ui').innerText.includes('Defensive casting ${state}')`);
  }
  await open('spells');
  await evaluate(`[...document.querySelectorAll('.game-panel-tabs button')].find(b=>b.textContent==='Memorized').click()`);
  await wait(`Boolean(document.querySelector('[data-spell-id="100"][data-spell-ready="1"]'))`);
  const binding=await drag('[data-spell-id="100"][data-spell-ready="1"]',1);assert.equal(binding.binding.classIndex,0);
  await click('[data-spell-id="100"][data-spell-ready="1"]');await wait(`document.querySelector('${canvas}').dataset.spellTarget==='100'`);
  await selfTarget();
  const settle=async()=>{const end=Date.now()+12000;while(Date.now()<end){const o=(await capture()).actors.find(a=>a.id===awaitedPlayer);if(events.some(e=>e.objectId===awaitedPlayer&&[17,18,19,20,61].includes(e.animation))&&o.base<=1)return;await new Promise(r=>setTimeout(r,100));}throw new Error('Cast did not finish');};
  await settle();await open('spells');await evaluate(`[...document.querySelectorAll('.game-panel-tabs button')].find(b=>b.textContent==='Memorized').click()`);
  const used=await evaluate(`document.querySelectorAll('[data-spell-id="100"][data-spell-ready="0"]').length`);assert.equal(used,1);
  await click('.game-close');
  // A real right-button opening on the HUD self target followed by radial
  // selection must submit immediately to that target, without a second pick.
  await click('#player-actions','right');
  await wait(`!document.querySelector('.radial-overlay').hidden`);
  const radialChoose=async slot=>{await key('keyDown',String(slot+1),`Digit${slot+1}`,49+slot);await key('keyUp',String(slot+1),`Digit${slot+1}`,49+slot);};
  await radialChoose(1);await radialChoose(5);await radialChoose(0);
  await wait(`Boolean(document.querySelector('.radial-entry[aria-label="Light"]'))`);
  assert.equal(await evaluate(`document.querySelector('.radial-entry[aria-label="Light"]').disabled`),false);
  await click('.radial-entry[aria-label="Light"]');
  assert.equal(await evaluate(`document.querySelector('${canvas}').dataset.spellTarget??null`),null);
  // A second cast waits for the current six-second combat round; a fixed
  // conjure-only delay would inspect its slot before release.
  await open('spells');await evaluate(`[...document.querySelectorAll('.game-panel-tabs button')].find(b=>b.textContent==='Memorized').click()`);
  await wait(`document.querySelectorAll('[data-spell-id="100"][data-spell-ready="0"]').length===2`);await new Promise(r=>setTimeout(r,1800));await capture();
  assert.equal(await evaluate(`document.querySelectorAll('[data-spell-id="100"][data-spell-ready="0"]').length`),2);
  await click('.game-close');await key('keyDown','F2','F2',113);await key('keyUp','F2','F2',113);
  await wait(`document.querySelector('${canvas}').dataset.spellTarget==='100'`);
  await key('keyDown','Escape','Escape',27);await key('keyUp','Escape','Escape',27);
  assert.equal(await evaluate(`document.querySelector('${canvas}').dataset.spellTarget??null`),null);
  assert.equal(await evaluate(`document.querySelector('#game-ui').dataset.panel`),'');
  await open('spells');await evaluate(`[...document.querySelectorAll('.game-panel-tabs button')].find(b=>b.textContent==='Memorized').click()`);
  await click('[data-spell-id="100"][data-spell-ready="0"]');await wait(`document.querySelector('${canvas}').dataset.spellTarget==='100'`);
  const cancelPoint={x:700,y:400};for(const type of ['mousePressed','mouseReleased'])await win.webContents.debugger.sendCommand('Input.dispatchMouseEvent',{type,...cancelPoint,button:'right',clickCount:1});
  assert.equal(await evaluate(`document.querySelector('${canvas}').dataset.spellTarget??null`),null);assert.equal(await evaluate(`document.querySelector('.radial-overlay').hidden`),true);
  await open('spells');await evaluate(`[...document.querySelectorAll('.game-panel-tabs button')].find(b=>b.textContent==='Memorized').click()`);
  assert.ok(events.some(e=>e.objectId===awaitedPlayer&&e.clip!=='pause1'&&[15,16].includes(e.animation)));assert.equal(errors.length,0);
  await fs.writeFile(path.join(workspace,'backups/animations/live-casting-ui.png'),(await win.webContents.capturePage()).toPNG());
  await fs.writeFile(path.join(workspace,'backups/animations/live-casting-ui.json'),JSON.stringify({binding,events:events.filter(e=>e.objectId===awaitedPlayer),used:2,errors},null,2));
  await click('.game-close');
  let counterTarget=null;
  const candidates=(await snapshot()).actors.filter(a=>a.id!==awaitedPlayer&&a.screen&&a.screen.x>20&&a.screen.x<1400&&a.screen.y>40&&a.screen.y<850);
  for(const candidate of candidates){
   for(const dy of [0,-12,12,-24]){
    for(const type of ['mousePressed','mouseReleased'])await win.webContents.debugger.sendCommand('Input.dispatchMouseEvent',{type,x:Math.round(candidate.screen.x),y:Math.round(candidate.screen.y+dy),button:'right',clickCount:1});
    if(await evaluate(`document.querySelector('.radial-overlay').hidden`))continue;
    await chooseWheel(1);await chooseWheel(6);
    if(await evaluate(`Boolean(document.querySelector('.radial-entry[aria-label="Counterspell"]:not(:disabled)'))`)){
     await click('.radial-entry[aria-label="Counterspell"]');counterTarget=await evaluate(`JSON.parse(document.querySelector('${canvas}').dataset.lastRadialAction).targetId`);break;
    }
    await key('keyDown','Escape','Escape',27);await key('keyUp','Escape','Escape',27);
   }
   if(counterTarget!==null)break;
  }
  assert.ok(counterTarget,'A visible canonical NPC must accept the counterspell radial command');
  await wait(`JSON.parse(document.querySelector('${canvas}').dataset.creatureAnimations).actors.find(a=>a.id===${awaitedPlayer}).combatMode===4`);
  assert.equal((await snapshot()).actors.find(a=>a.id===awaitedPlayer).counterSpellTargetId,counterTarget);
  assert.equal(errors.length,0);console.log('COUNTERSPELL WORLD RADIAL INPUT AND LIVE MODE/TARGET PASS',counterTarget);
  console.log('SPELLBOOK CLICK, RADIAL SELF CAST, SLOT CONSUMPTION, HOTBAR F2 TARGET, CAST ANIMATIONS AND TARGET CANCELLATION PASS');await evaluate('window.flushRuntimeDiagnostics()');app.exit(0);
 }catch(error){await fs.writeFile(path.join(workspace,'backups/animations/live-casting-ui-failed.png'),(await win.webContents.capturePage()).toPNG());console.error(error.stack,errors);app.exit(1);}
});
