const {app,BrowserWindow}=require('electron'),assert=require('node:assert/strict'),fs=require('node:fs/promises'),path=require('node:path'),{build}=require('esbuild');
const workspace=path.resolve(__dirname,'..'),install=path.resolve('../FullDecomp/NwnRootInstall'),folder=path.join(workspace,`backups/voice-renderer-${process.pid}`);
app.setPath('userData',folder);app.setPath('logs',folder);app.setPath('crashDumps',folder);
app.whenReady().then(async()=>{
 await fs.mkdir(folder,{recursive:true});
 await build({stdin:{resolveDir:__dirname,sourcefile:'voice-renderer-fixture.mjs',contents:`
 import {ResourceResolver} from '../src/resource_archive.js';import {ModuleSession} from '../src/module_session.js';import {VoicePresentation} from '../src/voice_presentation.js';
 import {GameAudio} from '../src/game_audio.js';import {GameText,parseTalkTable} from '../src/talk_table.js';import {creatureRoot} from '../src/creature_rules.js';import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
 const status=document.querySelector('#status'),captions=[],packets=[];
 document.querySelector('#play').onclick=async()=>{try{
  const context=new AudioContext();await context.resume();status.textContent='Loading installed campaign and character';
  const data=[...document.querySelector('#data').files],language=[...document.querySelector('#language').files],module=document.querySelector('#module').files[0],
   resolver=await ResourceResolver.create(module,data,[]),character=data.find(f=>f.name==='wizard.bic'&&f.webkitRelativePath.includes('/lcv/'));if(!character)throw new Error('Installed wizard preset missing');
  const text=new GameText({base:parseTalkTable(await language.find(f=>f.name==='dialog.tlk').arrayBuffer())});let voice=null;
  const session=await new ModuleSession(resolver,{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:e=>{packets.push(e);if(voice)void voice.receive(e);}}).initialize(['m0q1a'],{character:await character.arrayBuffer()});
  await session.enterArea('m0q1a',[24,0,-14]);session.scheduler.events=[];
  const audio=new GameAudio(resolver,{getObject:id=>session.registry.get(id),getPlayer:()=>session.player,createContext:()=>context});await audio.unlock();
  voice=new VoicePresentation(resolver,{getObject:id=>session.registry.get(id),getPlayer:()=>session.player,getText:()=>text,
   onCaption:e=>{captions.push({actorId:e.actorId,strRef:e.strRef,textLength:e.text.length});document.querySelector('#caption').textContent=e.text;},onSound:e=>audio.play(e)});
  const start=runtimeDiagnostics.records.length,setId=creatureRoot(session.player).SoundSetFile&65535,set=await voice.soundSet(setId),preferred=set.get(22),code=preferred?.resRef?22:Array.from({length:set.count},(_,i)=>i).find(i=>set.get(i)?.resRef);
  await session.commands.PlayVoiceChat([code,0x7f000000],{self:session.player.id});await voice.tail;
  window.result={setId,code,packets,captions,audio:audio.state,diagnostics:runtimeDiagnostics.records.slice(start)};status.textContent='Voice command delivered; browser decoded and started audio';
 }catch(error){window.failure=error.stack;status.textContent=error.message;}};
 `},bundle:true,format:'esm',platform:'browser',outfile:path.join(folder,'fixture.js')});
 await fs.writeFile(path.join(folder,'index.html'),`<!doctype html><html><head><meta charset="utf-8"><style>body{font:18px sans-serif;background:#172126;color:#e2d9bc;padding:32px}input{display:block;margin:16px 0}button{padding:12px}#caption{padding:20px;border:1px solid #9c9067;min-height:30px}</style></head><body><p>Installed voice casting support check</p><input id="data" type="file" webkitdirectory><input id="language" type="file" webkitdirectory><input id="module" type="file"><button id="play">Play installed character voice</button><p id="status">Choose installed files</p><div id="caption"></div><script type="module" src="fixture.js"></script></body></html>`);
 const win=new BrowserWindow({show:false,width:1000,height:650,webPreferences:{contextIsolation:true,nodeIntegration:false,sandbox:true,offscreen:true,backgroundThrottling:false}});win.webContents.setAudioMuted(true);const errors=[];
 win.webContents.on('console-message',(_e,level,message)=>{if(level>=3)errors.push(message);});
 try{
  await win.loadFile(path.join(folder,'index.html'));win.webContents.debugger.attach('1.3');
  const evaluate=code=>win.webContents.executeJavaScript(code),files=async(selector,paths)=>{const {root}=await win.webContents.debugger.sendCommand('DOM.getDocument'),{nodeId}=await win.webContents.debugger.sendCommand('DOM.querySelector',{nodeId:root.nodeId,selector});await win.webContents.debugger.sendCommand('DOM.setFileInputFiles',{nodeId,files:paths});};
  await evaluate(`for(const id of ['data','language']){const input=document.getElementById(id);input.multiple=true;input.setAttribute('directory','');}`);
  const waitFiles=async(id,name)=>{const end=Date.now()+30000;while(!await evaluate(`[...document.getElementById('${id}').files].some(f=>f.name.toLowerCase()==='${name}')`)){
    if(Date.now()>end)throw new Error('Directory enumeration failed: '+await evaluate(`JSON.stringify({id:'${id}',files:[...document.getElementById('${id}').files].filter(f=>/key|tlk/i.test(f.name)).map(f=>f.name),count:document.getElementById('${id}').files.length})`));await new Promise(r=>setTimeout(r,100));}};
  await files('#data',[path.join(install,'data')]);await waitFiles('data','nwn_base.key');
  await files('#language',[path.join(install,'lang/en/data')]);await waitFiles('language','dialog.tlk');
  await files('#module',[path.join(install,'data/nwm/Prelude.nwm')]);
  const point=await evaluate(`{const r=document.querySelector('#play').getBoundingClientRect();({x:r.x+r.width/2,y:r.y+r.height/2})}`);
  for(const type of ['mousePressed','mouseReleased'])await win.webContents.debugger.sendCommand('Input.dispatchMouseEvent',{type,...point,button:'left',clickCount:1});
  const deadline=Date.now()+90000;while(!await evaluate('Boolean(window.result||window.failure)')){if(Date.now()>deadline)throw new Error('Timeout: '+await evaluate('document.body.innerText'));await new Promise(r=>setTimeout(r,100));}
  assert.equal(await evaluate('window.failure??null'),null);const result=await evaluate('window.result');
  await fs.writeFile(path.join(workspace,'backups/animations/live-voice-ui.json'),JSON.stringify({...result,consoleErrors:errors,limits:'Isolated real Chromium audio context, muted output, installed campaign/preset/voice and actual file/input clicks. Caption display is a fixture; production HUD is a separate adapter.'},null,2));
  await fs.writeFile(path.join(workspace,'backups/animations/live-voice-ui.png'),(await win.webContents.capturePage()).toPNG());
  assert.equal(result.audio.played,1);assert.equal(result.audio.pending,0);assert.equal(result.audio.context,'running');assert.ok(result.captions.length);assert.deepEqual(result.diagnostics.filter(d=>d.severity==='error'),[]);assert.deepEqual(errors,[]);
  console.log('INSTALLED VOICE COMMAND, SSF/TLK, ACTUAL CHROMIUM AUDIO DECODE/START AND CAPTION PASS',JSON.stringify(result.audio));app.exit(0);
 }catch(error){console.error(error.stack,errors);app.exit(1);}
});
