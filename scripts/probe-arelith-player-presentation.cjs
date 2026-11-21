// Owned-client diagnostic harness. Ordinary admission of one existing server
// character only. Optional keyboardCheck exercises ordinary renderer key events.
// No chat, character creation, raw packets, BICs or credentials are written.
// Leaves the successful window open for testing.
const {app,BrowserWindow,ipcMain}=require('electron'),fs=require('node:fs/promises'),path=require('node:path');
const root=path.resolve(__dirname,'..');app.setName('nwn-model-viewer-research');
function appearanceMetadata(session){return[...session.world.registry.objects.values()].filter(o=>o.objectType===5&&o.appearance&&!o.replicationRemoved).map(o=>{const a=o.appearance;return{id:o.id,appearance:a.appearance,phenotype:a.phenotype,gender:a.gender,head:a.head,skin:a.skin,hair:a.hair,tattoo1:a.tattoo1,tattoo2:a.tattoo2,bodyParts:a.bodyParts,fieldAA4:a.fieldAA4,fieldAA8:a.fieldAA8,equipment:a.equipment?.map(e=>({id:e.id,slot:e.slot,baseItem:e.item?.baseItem,parts:e.item?.parts,colors:e.item?.colors,partColors:e.item?.partColors}))};});}
app.whenReady().then(async()=>{
 const report={scope:'Arelith existing-character presentation; no gameplay commands or raw packet storage',startedAt:new Date().toISOString(),states:[],invalid:[],diagnostics:[],rendererErrors:[],samples:[]};let window,controller,session,input,timer,controlTimer;
 const output=path.join(root,'backups/animations/creation-experience-player-validation-v4.json');
 const save=()=>fs.writeFile(output,JSON.stringify(report,null,2));
 try{
  const {readPrivateProbeInput}=await import('./read-private-probe-input.mjs'),{createInstalledNetworkSession}=await import('../electron/installed_network_session.mjs'),{NativeMessageReader}=await import('../src/native_message.js');input=await readPrivateProbeInput();
  if(input.options.keyboardCheck||input.options.keyboardSmoothCheck)report.scope='Arelith existing-character keyboard input and server feedback; no chat, raw packet bodies or credentials recorded';
  const runtime=require('../electron/runtime_log.cjs').registerRuntimeLog(ipcMain,path.join(root,'runtime-logs'));report.runtimeLog=runtime.path;
  controller=require('../electron/network_ipc.cjs').registerNetworkIpc(ipcMain,{defaultInstall:input.options.install,userDirectory:path.join(app.getPath('documents'),'Neverwinter Nights'),cacheDirectory:path.join(app.getPath('appData'),'nwn-model-viewer-research/server-content'),chooseInstall:async()=>null,createSession:async args=>{
   const result=await createInstalledNetworkSession(args);session=result.session;const decode=session.decodeMessage;
   session.decodeMessage=(bytes,options)=>{try{return decode(bytes,options);}catch(error){
    if(bytes[1]===5&&bytes[2]===1&&report.invalid.length<10){
     const trace=[],originals=new Map();for(const name of Object.getOwnPropertyNames(NativeMessageReader.prototype).filter(n=>/^read[A-Z]/.test(n))){const original=NativeMessageReader.prototype[name];originals.set(name,original);NativeMessageReader.prototype[name]=function(...args){const start=this.byteCursor44;const value=original.apply(this,args);trace.push({method:name,start,end:this.byteCursor44,bit:this.curReadBit5c,...(typeof value==='number'?{value}:{})});return value;};}
     try{decode(bytes,options);}catch{}finally{for(const [name,original]of originals)NativeMessageReader.prototype[name]=original;}
     report.invalid.push({length:bytes.length,reason:error.message,context:error.objectUpdate,skillCount:options.objectRules.skillCount,clientBuild:options.clientBuild,serverBuild:options.serverBuild,trace:trace.slice(-2000)});void save();
    }throw error;
   }};return result;
  }});
  window=new BrowserWindow({show:true,width:1440,height:960,title:'NWN Model Lab',webPreferences:{preload:path.join(root,'electron/preload.cjs'),contextIsolation:true,nodeIntegration:false,sandbox:true}});controller.attach(window);window.setMenuBarVisibility(false);
  const send=window.webContents.send.bind(window.webContents);window.webContents.send=(channel,event)=>{if(channel==='network:event'){if(event.kind==='state'&&report.states.at(-1)?.phase!==event.state.phase)report.states.push({phase:event.state.phase,at:Date.now()});if(event.kind==='diagnostic'&&report.diagnostics.length<300)report.diagnostics.push(event.diagnostic);}return send(channel,event);};
  window.webContents.on('console-message',(_e,level,message)=>{if(level>=3)report.rendererErrors.push(message);});
  const js=code=>window.webContents.executeJavaScript(code),wait=async(fn,label,timeout=120000)=>{const end=Date.now()+timeout;while(!await fn()){if(Date.now()>end)throw Error(label+' timed out');await new Promise(r=>setTimeout(r,100));}};
  await window.loadFile(path.join(root,'dist/index.html'));window.show();window.focus();await wait(()=>js('Boolean(window.nativeNetwork)&&!document.querySelector("#multiplayer-button").disabled'),'Renderer');
  // Owned test-run lifecycle channel, so future normal disconnect/restarts
  // need no desktop automation. No gameplay or arbitrary code is accepted.
  if(input.options.controlFile){const target=path.resolve(root,input.options.controlFile);if(!target.toLowerCase().startsWith((path.join(root,'backups','animations')+path.sep).toLowerCase()))throw Error('Probe lifecycle file must stay in its capture directory');controlTimer=setInterval(async()=>{try{const command=JSON.parse(await fs.readFile(target,'utf8'));if(command.close===true){clearInterval(controlTimer);window.close();}}catch(error){if(error.code!=='ENOENT')console.log(JSON.stringify({lifecycleError:error.message}));}},250);controlTimer.unref();}
  await controller.connect(window.webContents,{host:input.options.host,port:input.options.port,name:'ReplacementTest',credentials:input.credentials});
  await wait(()=>session?.serverCharacters?.length,'Server characters');const matches=session.serverCharacters.filter(c=>c.name===input.options.character||c.resref===input.options.character);let entry=matches[0];
  if(!entry){await wait(()=>js(`[...document.querySelectorAll('.nw-character-row')].some(b=>b.textContent.includes(${JSON.stringify(input.options.character)}))`),'Existing character row');await js(`[...document.querySelectorAll('.nw-character-row')].find(b=>b.textContent.includes(${JSON.stringify(input.options.character)})).click()`);await wait(()=>session.selectedServerCharacter,'Existing character selection');entry=session.selectedServerCharacter;}
  await session.playServerCharacter({...entry,generation:session.characterListGeneration});
  await wait(()=>session.phase==='playing','World admission');report.clientBuild=session.build.build;report.serverBuild=session.serverBuild;
  if(input.options.keyboardSmoothCheck){
   await wait(()=>js(`Boolean(JSON.parse(document.querySelector('#model-canvas').dataset.networkScene??'null')?.controlled?.rendered)`),'Keyboard controlled presentation');
   report.keyboardSmooth=await require('./probe-smooth-keyboard.cjs')(window,session);await save();console.log(JSON.stringify({keyboardSmooth:report.keyboardSmooth.sections}));
  }
  if(input.options.keyboardCheck){
   await wait(()=>js(`Boolean(JSON.parse(document.querySelector('#model-canvas').dataset.networkScene??'null')?.controlled?.rendered)`),'Keyboard controlled presentation');
   report.keyboardCheck=await require('./probe-live-keyboard.cjs')(window,session);await save();console.log(JSON.stringify({keyboardCheck:report.keyboardCheck}));
  }
  if(input.options.openInventory){
   await wait(()=>js(`(()=>{const c=document.querySelector('#model-canvas'),s=JSON.parse(c.dataset.networkScene??'null');return Boolean(s?.controlled?.rendered)&&!document.querySelector('#network-inventory-button').disabled;})()`),'Controlled actor presentation');
   await js(`document.querySelector('#network-inventory-button').click()`);
   await wait(()=>session.world.inventories.has('I')&&js(`(()=>{const v=document.querySelector('.network-inventory');return v&&!v.hidden&&v.dataset.state&&v.dataset.state!=='null';})()`),'Replicated inventory presentation');
   report.inventory=await js(`(()=>{const v=document.querySelector('.network-inventory');return{title:v.querySelector('h2').textContent,slots:v.querySelectorAll('.network-equipment li').length,items:v.querySelectorAll('.network-item').length,icons:v.querySelectorAll('.network-item img').length,creatureToggleInInventory:Boolean(v.querySelector('input[type=checkbox]')),footer:v.querySelector('footer').textContent,state:JSON.parse(v.dataset.state)};})()`);
   await fs.writeFile(path.join(root,'backups/animations/creation-experience-inventory-live-v1.png'),(await window.webContents.capturePage()).toPNG());await save();
  }
  let tick=0;timer=setInterval(async()=>{try{if(window.isDestroyed())return;const actor=session.world.registry.get(session.world.localObjectId),data=await js(`(()=>{const c=document.querySelector('#model-canvas'),s=JSON.parse(c.dataset.networkScene??'null'),p=JSON.parse(document.querySelector('#performance-debug').dataset.state??'null');return{controlled:s?.controlled,objects:s?.objects.length,failed:s?.failedObjects,models:s?.objects.map(o=>({id:o.id,objectType:o.objectType,appearance:o.appearance,resources:o.resources,clip:o.clip,visualTransforms:o.visualTransforms})),performance:p,camera:JSON.parse(c.dataset.networkCamera??'null')};})()`);report.samples.push({at:Date.now(),appearances:appearanceMetadata(session),canonical:actor?{id:actor.id,areaId:actor.areaId,appearance:actor.appearance,position:actor.replicated?.position,removed:actor.replicationRemoved}:null,...data});if(report.samples.length>120)report.samples.shift();report.ready=Boolean(data.controlled?.rendered);if(report.ready&&!report.firstPlayerAt)report.firstPlayerAt=Date.now();await save();if(++tick%10===0)console.log(JSON.stringify({ready:report.ready,invalid:report.invalid.length,controlled:data.controlled,objects:data.objects}));}catch(error){console.log(JSON.stringify({sampleError:error.message}));}},1000);
  window.on('close',event=>{if(window.closing)return;event.preventDefault();window.closing=true;clearInterval(timer);void controller.disconnect(window.webContents,{saveCharacter:false}).finally(async()=>{report.finishedAt=new Date().toISOString();await save();window.destroy();app.quit();});});
 }catch(error){report.failure=error.message;await save();console.log(JSON.stringify({failure:report.failure}));await session?.disconnect();window?.destroy();app.exit(1);}
});app.on('window-all-closed',()=>app.quit());
