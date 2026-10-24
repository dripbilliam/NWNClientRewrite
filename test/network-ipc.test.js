import test from 'node:test';
import assert from 'node:assert/strict';
import {EventEmitter} from 'node:events';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {registerNetworkIpc} from '../electron/network_ipc.cjs';
const url=pathToFileURL(fileURLToPath(new URL('../dist/index.html',import.meta.url))).href;
function setup(factory,options={}){
 const handlers=new Map(),ipc={handle:(name,fn)=>handlers.set(name,fn)},controller=registerNetworkIpc(ipc,{defaultInstall:'/install',userDirectory:null,chooseInstall:async()=>null,createSession:factory,...options});
 const window=new EventEmitter(),sender=new EventEmitter();sender.id=1;sender.mainFrame={};sender.isDestroyed=()=>false;sender.getURL=()=>url;sender.events=[];sender.send=(_channel,event)=>sender.events.push(event);window.webContents=sender;controller.attach(window);
 return{window,sender,controller,handlers,invoke:(name,...args)=>handlers.get(name)({sender,senderFrame:sender.mainFrame},...args)};
}
function fakeSession(){const s=new EventEmitter();s.closed=false;s.disposeCount=0;s.connect=async()=>{s.emit('state',{phase:'connecting'});};s.state=()=>({phase:'resources'});s.disconnect=async()=>{if(s.closed)return;s.closed=true;s.disposeCount++;s.emit('closed');};s.getResource=async(ref,type)=>[ref,type];return s;}

test('native settings invalidate only attached lobby resource caches without replacing a live session',async()=>{const s=fakeSession(),h=setup(async()=>({session:s,metadata:{}}));assert.doesNotThrow(()=>h.controller.invalidateLobbyResources(h.sender));assert.throws(()=>h.controller.invalidateLobbyResources({id:99,isDestroyed:()=>false}),/unavailable/);await h.invoke('network:connect',request());assert.doesNotThrow(()=>h.controller.invalidateLobbyResources(h.sender));assert.equal(s.closed,false);await h.controller.disconnect(h.sender,{saveCharacter:false});assert.doesNotThrow(()=>h.controller.invalidateLobbyResources(h.sender));h.sender.isDestroyed=()=>true;assert.throws(()=>h.controller.invalidateLobbyResources(h.sender),/unavailable/);});

test('scene capture controls require the exact owning frame/session and recorder state omits connection secrets',async()=>{
 const recorded=[],views=[],s=fakeSession(),recorder={contextFor:()=> 'context-1',event:(...args)=>recorded.push(args),message:(...args)=>recorded.push(args),view:(...args)=>views.push(args),status:()=>({recording:true}),close:async()=>({complete:true})};
 const h=setup(async args=>{assert.equal(args.sceneCapture,recorder);return{session:s,metadata:{}};},{sceneCapture:recorder}),result=await h.invoke('network:connect',request()),id=result.value.sessionId;
 assert.equal((await h.invoke('network:scene-capture-status')).value.recording,true);assert.equal((await h.handlers.get('network:scene-capture-finish')({sender:h.sender,senderFrame:{}})).ok,false);
 assert.equal((await h.invoke('network:scene-capture-view','stale',{})).ok,false);assert.equal(views.length,0);assert.equal((await h.invoke('network:scene-capture-view',id,{areaId:7})).ok,true);assert.equal(views.length,1);
 s.emit('state',{phase:'playing',serverInfo:{password:'secret'},credentials:{cdKey:'secret'}});assert.ok(!JSON.stringify(recorded).includes('secret'));await h.controller.disconnect(h.sender,{saveCharacter:false});const count=recorded.length;s.emit('message',{message:{kind:'client-area'}});assert.equal(recorded.length,count);
});

test('an explicitly selected local build retains exact-document and main-frame IPC ownership',async()=>{
 const selected=pathToFileURL(fileURLToPath(new URL('../backups/animations/performance-queue/fixture/preview-build/index.html',import.meta.url))).href;
 const s=fakeSession(),h=setup(async()=>({session:s,metadata:{}}),{applicationUrl:selected});
 assert.equal((await h.invoke('network:connect',request())).ok,false);
 h.sender.getURL=()=>selected;const connected=await h.invoke('network:connect',request());assert.equal(connected.ok,true);
 const id=connected.value.sessionId;assert.equal((await h.invoke('network:resource',id,'mesh',2002)).ok,true);
 assert.equal((await h.handlers.get('network:resource')({sender:h.sender,senderFrame:{}},id,'mesh',2002)).ok,false);
 h.sender.getURL=()=>selected+'#other';assert.equal((await h.invoke('network:resource',id,'mesh',2002)).ok,false);
 h.sender.getURL=()=>selected.replace('/preview-build/','/other-build/');assert.equal((await h.invoke('network:resource',id,'mesh',2002)).ok,false);
 await h.controller.disconnect(h.sender,{saveCharacter:false});
});

test('application document configuration rejects remote, network-share and decorated URLs',()=>{
 for(const applicationUrl of ['https://example.invalid/index.html','file://remote/share/index.html',url+'?other',url+'#other',null])assert.throws(()=>setup(async()=>({session:fakeSession()}),{applicationUrl}));
});

test('explicit disconnect delivers the terminal state for renderer cleanup while dropping cancelled work and old-owner closure',async()=>{
 const old=fakeSession(),next=fakeSession();let finish;const peerClosed=new Promise(r=>finish=r);
 old.disconnect=async()=>{if(old.closed)return;old.closed=true;old.emit('state',{phase:'closed',closed:true});old.emit('message',{message:{kind:'cancelled-world-update'}});old.emit('state',{phase:'playing',closed:false});old.emit('closed');await peerClosed;};
 const sessions=[old,next],h=setup(async()=>({session:sessions.shift(),metadata:{}})),id=(await h.invoke('network:connect',request())).value.sessionId;
 const before=h.sender.events.length,closing=h.invoke('network:disconnect',{saveCharacter:false});await new Promise(r=>setImmediate(r));
 assert.deepEqual(h.sender.events.slice(before),[{sessionId:id,kind:'state',state:{phase:'closed',closed:true}}]);
 finish();assert.equal((await closing).ok,true);assert.equal((await h.invoke('network:connect',request())).ok,true);const count=h.sender.events.length;
 old.emit('state',{phase:'closed',closed:true});assert.equal(h.sender.events.length,count);await h.invoke('network:disconnect',{saveCharacter:false});
});

test('portal handoff rotates renderer ownership and drops old-session events and commands',async()=>{
 const old=fakeSession(),next=fakeSession(),connections=[];next.connect=async options=>{connections.push(options);next.emit('state',{phase:'connecting'});};
 const h=setup(async()=>({session:old,metadata:{}})),connected=await h.invoke('network:connect',request()),oldId=connected.value.sessionId;
 old.portalHandoffReady=true;old.closed=true;old.emit('state',{phase:'closed',closed:true});old.emit('closed');old.emit('portal-ready',{session:next,metadata:{name:'Same account'},host:'127.0.0.1',port:5122});
 const newId=h.sender.events.find(e=>e.kind==='state'&&e.state.phase==='connecting'&&e.sessionId!==oldId)?.sessionId;assert.ok(newId);assert.notEqual(newId,oldId);assert.equal(connections.length,1);assert.equal(connections[0].port,5122);assert.equal(connections[0].expectedServerPublicKey,undefined);
 const before=h.sender.events.length;old.emit('message',{message:{kind:'stale-old-world'}});old.emit('state',{phase:'playing'});assert.equal(h.sender.events.length,before);
 assert.equal((await h.invoke('network:resource',oldId,'resource',2002)).ok,false);assert.equal((await h.invoke('network:resource',newId,'resource',2002)).ok,true);
 await h.invoke('network:disconnect',{saveCharacter:false});assert.equal(next.closed,true);
});

test('a cancelled portal owner disposes a late handoff without reconnecting',async()=>{
 const old=fakeSession(),next=fakeSession();let logins=0;next.connect=async()=>logins++;
 const h=setup(async()=>({session:old,metadata:{}}));await h.invoke('network:connect',request());await h.invoke('network:disconnect',{saveCharacter:false});old.emit('portal-ready',{session:next,metadata:{},host:'127.0.0.1',port:5122});await new Promise(r=>setImmediate(r));assert.equal(logins,0);assert.equal(next.closed,true);
});
test('saved credentials stay in main-process login and mods changes cannot cross an active session',async()=>{
 let decrypted=0,updates=0;const status={modsDirectory:'chosen-mods',hasSavedCdKey:true,protectedStorageAvailable:true},clientSettings={status:async()=>status,cdKey:async()=>{decrypted++;return'private-fixture';},update:async()=>{updates++;return status;}},h=setup(async args=>{assert.equal(args.credentials.cdKey,'private-fixture');assert.equal(args.modsDirectory,'chosen-mods');return{session:fakeSession(),metadata:{}};},{clientSettings,chooseMods:async()=>'/chosen'});
 const metadata=await h.invoke('network:settings');assert.equal(metadata.value.hasSavedCdKey,true);assert.equal(decrypted,0);assert.ok(!JSON.stringify(metadata).includes('private-fixture'));assert.equal((await h.handlers.get('network:settings')({sender:h.sender,senderFrame:{}})).ok,false);
 const r=request();r.credentials.cdKey='';assert.equal((await h.invoke('network:connect',r)).ok,true);assert.equal(decrypted,1);assert.equal((await h.invoke('network:settings-save',{modsDirectory:'/other'})).ok,false);assert.equal(updates,0);assert.equal((await h.invoke('network:mods-folder')).ok,false);await h.invoke('network:disconnect');const save={cdKey:'input-fixture'};assert.equal((await h.invoke('network:settings-save',save)).ok,true);assert.equal(save.cdKey,'');assert.equal(updates,1);
});
test('base lobby texture endpoint rejects other frames and unbounded paths before opening resources',async()=>{
 const h=setup(async()=>({session:fakeSession(),metadata:{}}));assert.equal((await h.invoke('network:lobby-texture','../other')).ok,false);assert.equal((await h.invoke('network:lobby-texture','x'.repeat(33))).ok,false);assert.equal((await h.handlers.get('network:lobby-texture')({sender:h.sender,senderFrame:{}},'icon')).ok,false);
});
test('resource misses retain their typed fallback signal across IPC without copying arbitrary error fields',async()=>{
 const s=fakeSession();s.getResource=async()=>{throw Object.assign(Error('Missing optional texture'),{code:'RESOURCE_NOT_FOUND',privateValue:'not exported'});};const h=setup(async()=>({session:s,metadata:{}})),id=(await h.invoke('network:connect',request())).value.sessionId;
 assert.deepEqual(await h.invoke('network:resource',id,'optional',6),{ok:false,message:'Missing optional texture',code:'RESOURCE_NOT_FOUND'});s.getResource=async()=>{throw Object.assign(Error('Other error'),{code:'SENSITIVE_PATH'});};assert.deepEqual(await h.invoke('network:resource',id,'optional',6),{ok:false,message:'Other error'});await h.invoke('network:disconnect');
});
const request=()=>({host:'localhost',port:5121,name:'Tester',credentials:{cdKey:'private-fixture'}});

test('prepared model IPC reads authoritative bytes, checks main-frame ownership and rejects retired results',async()=>{
 const s=fakeSession(),calls=[];s.getResource=async(ref,type)=>{calls.push([ref,type]);return Uint8Array.of(1,2,3);};
 let finish;const cache={prepare:async bytes=>{assert.deepEqual([...bytes],[1,2,3]);return new Promise(resolve=>finish=resolve);}};
 const h=setup(async()=>({session:s,metadata:{}}),{modelCache:cache}),id=(await h.invoke('network:connect',request())).value.sessionId;
 assert.equal((await h.invoke('network:model-source','old','fixture')).ok,false);
 assert.equal((await h.invoke('network:model-source',id,'../file')).ok,false);
 assert.equal((await h.handlers.get('network:model-source')({sender:h.sender,senderFrame:{}},id,'fixture')).ok,false);
 assert.deepEqual(calls,[]);const pending=h.invoke('network:model-source',id,'fixture');await new Promise(r=>setImmediate(r));assert.deepEqual(calls,[['fixture',2002]]);
 await h.controller.disconnect(h.sender,{saveCharacter:false});finish({nodes:[]});assert.equal((await pending).ok,false);
});

test('texture selection IPC is limited to the current owner and trusted main frame',async()=>{
 const s=fakeSession(),calls=[];s.getTextureResource=async ref=>{calls.push(ref);return{type:2033,extension:'dds',bytes:new ArrayBuffer(4)};};
 const h=setup(async()=>({session:s,metadata:{}})),id=(await h.invoke('network:connect',request())).value.sessionId;
 assert.equal((await h.invoke('network:texture-resource','stale','stone')).ok,false);
 assert.equal((await h.handlers.get('network:texture-resource')({sender:h.sender,senderFrame:{}},id,'stone')).ok,false);
 assert.equal((await h.invoke('network:texture-resource',id,'stone')).value.type,2033);
 assert.deepEqual(calls,['stone']);await h.controller.disconnect(h.sender,{saveCharacter:false});
});

test('saved previews and Play require the owning local-vault session and zero main-process copies',async()=>{
 const s=fakeSession(),copies=[],selected=[];s.localVaultAllowed=true;s.previewLocalCharacter=async b=>({name:'Preview',byteCount:b.length});s.selectCharacter=async b=>selected.push([...b]);const h=setup(async()=>({session:s,metadata:{}}),{characterVault:{read:async()=>{const b=Uint8Array.of(1,2,3);copies.push(b);return b;}}}),id=(await h.invoke('network:connect',request())).value.sessionId;
 assert.equal((await h.invoke('network:saved-character-preview','stale','saved')).ok,false);assert.equal((await h.handlers.get('network:saved-character-play')({sender:h.sender,senderFrame:{}},id,'saved')).ok,false);assert.equal((await h.invoke('network:saved-character-preview',id,'saved')).value.byteCount,3);assert.equal((await h.invoke('network:saved-character-play',id,'saved')).ok,true);assert.deepEqual(selected,[[1,2,3]]);assert.ok(copies.every(b=>b.every(x=>x===0)));s.localVaultAllowed=false;assert.equal((await h.invoke('network:saved-character-play',id,'saved')).ok,false);assert.equal(copies.length,2);await h.controller.disconnect(h.sender,{saveCharacter:false});
});

test('saved-character selection reads only the owned vault entry and export IPC requires the owning frame/session',async()=>{
 const s=fakeSession(),bytes=Uint8Array.of(1,2,3),selected=[],saves=[];let options;s.selectCharacter=async b=>selected.push([...b]);s.exportCharacter=async()=>options.persistCharacter({data:Uint8Array.of(4)});
 const h=setup(async args=>{options=args;return{session:s,metadata:{}};},{characterVault:{list:async()=>[{id:'saved'}],read:async id=>{assert.equal(id,'saved');return bytes;},save:async(m,{id})=>{saves.push({id,data:[...m.data]});return{id:'saved',name:'Native Hero'};}}});
 assert.deepEqual((await h.invoke('network:characters')).value,[{id:'saved'}]);const connected=await h.invoke('network:connect',{...request(),vaultId:'saved'}),id=connected.value.sessionId;assert.deepEqual(selected,[[1,2,3]]);assert.deepEqual([...bytes],[0,0,0]);
 assert.equal((await h.invoke('network:character-export','stale')).ok,false);assert.equal((await h.handlers.get('network:character-export')({sender:h.sender,senderFrame:{}},id)).ok,false);assert.equal((await h.invoke('network:character-export',id)).value.id,'saved');assert.deepEqual(saves,[{id:'saved',data:[4]}]);await h.controller.disconnect(h.sender,{saveCharacter:false});
});
test('normal disconnect and window close wait for character persistence; failed saves leave the connection open',async()=>{
 const s=fakeSession();s.phase='playing';let commit,rejectSave;s.exportCharacter=()=>new Promise((resolve,reject)=>{commit=resolve;rejectSave=reject;});const h=setup(async()=>({session:s,metadata:{}}),{characterVault:{}});await h.invoke('network:connect',request());
 const disconnect=h.invoke('network:disconnect');await Promise.resolve();assert.equal(s.disposeCount,0);rejectSave(Error('disk full'));assert.equal((await disconnect).ok,false);assert.equal(s.closed,false);
 let actualCloses=0;h.window.close=()=>{const e={prevented:false,preventDefault(){this.prevented=true;}};h.window.emit('close',e);if(!e.prevented){actualCloses++;h.sender.emit('destroyed');}};h.window.close();assert.equal(actualCloses,0);assert.equal(s.disposeCount,0);commit({id:'saved'});await new Promise(r=>setImmediate(r));assert.equal(s.disposeCount,1);assert.equal(actualCloses,1);
});
test('explicit unsaved disconnect can close during a pending save and ambiguous upload/vault selections reject',async()=>{
 const s=fakeSession();s.phase='playing';let release;s.exportCharacter=()=>new Promise(r=>release=r);const h=setup(async()=>({session:s,metadata:{}}),{characterVault:{read:async()=>Uint8Array.of(1)}});const r=request(),credentials=r.credentials;assert.equal((await h.invoke('network:connect',{...r,vaultId:'saved',character:Uint8Array.of(1)})).ok,false);assert.equal(credentials.cdKey,'');await h.invoke('network:connect',request());
 const waiting=h.invoke('network:disconnect');await Promise.resolve();assert.equal((await h.invoke('network:disconnect',{saveCharacter:false})).ok,true);assert.equal(s.closed,true);release({id:'saved'});await waiting;
});

test('action cancellation IPC requires the owning session and trusted main frame',async()=>{
 const s=fakeSession(),calls=[];s.cancelAction=async r=>{calls.push(r);return{sent:true};};const h=setup(async()=>({session:s,metadata:{}})),id=(await h.invoke('network:connect',request())).value.sessionId,r={actionId:4,groupId:321,actorId:0xffffffff,areaId:0x80000001,areaGeneration:1};
 assert.equal((await h.invoke('network:action-cancel','stale',r)).ok,false);assert.equal((await h.handlers.get('network:action-cancel')({sender:h.sender,senderFrame:{}},id,r)).ok,false);assert.deepEqual((await h.invoke('network:action-cancel',id,r)).value,{sent:true});assert.deepEqual(calls,[r]);await h.invoke('network:disconnect');assert.equal((await h.invoke('network:action-cancel',id,r)).ok,false);
});

test('chat IPC requires the current owner and trusted main frame',async()=>{
 const s=fakeSession(),calls=[];s.chat=async r=>{calls.push(r);return{sent:true};};const h=setup(async()=>({session:s,metadata:{}})),id=(await h.invoke('network:connect',request())).value.sessionId,r={channel:4,text:'Hello',playerId:7,actorId:0xffffffff,areaId:0x80000001,areaGeneration:1};
 assert.equal((await h.invoke('network:chat','stale',r)).ok,false);assert.equal((await h.handlers.get('network:chat')({sender:h.sender,senderFrame:{}},id,r)).ok,false);assert.deepEqual((await h.invoke('network:chat',id,r)).value,{sent:true});assert.deepEqual(calls,[r]);await h.invoke('network:disconnect');assert.equal((await h.invoke('network:chat',id,r)).ok,false);
});

test('item-use IPC requires the trusted frame and its current owning session',async()=>{
 const s=fakeSession(),calls=[];s.useItem=async r=>{calls.push(r);return{sent:true};};const h=setup(async()=>({session:s,metadata:{}})),id=(await h.invoke('network:connect',request())).value.sessionId,r={itemId:0x80000002,propertyIndex:0,variant:255};
 assert.equal((await h.invoke('network:item-use','stale',r)).ok,false);assert.equal((await h.handlers.get('network:item-use')({sender:h.sender,senderFrame:{}},id,r)).ok,false);assert.deepEqual((await h.invoke('network:item-use',id,r)).value,{sent:true});assert.deepEqual(calls,[r]);await h.controller.disconnect(h.sender);
});

test('associate command IPC requires its owning session and trusted main frame',async()=>{
 const s=fakeSession(),calls=[];s.associateCommand=async r=>{calls.push(r);return{sent:true};};const h=setup(async()=>({session:s,metadata:{}})),id=(await h.invoke('network:connect',request())).value.sessionId,r={actorId:0x80000002,targetId:0x80000002,command:-13,areaId:0x80000001,areaGeneration:1};
 assert.equal((await h.invoke('network:associate-command','stale',r)).ok,false);assert.equal((await h.handlers.get('network:associate-command')({sender:h.sender,senderFrame:{}},id,r)).ok,false);assert.deepEqual((await h.invoke('network:associate-command',id,r)).value,{sent:true});assert.deepEqual(calls,[r]);await h.invoke('network:disconnect');assert.equal((await h.invoke('network:associate-command',id,r)).ok,false);assert.equal(calls.length,1);
});

test('quick-chat IPC requires the owning session and trusted main frame',async()=>{
 const s=fakeSession(),calls=[];s.quickChat=async r=>{calls.push(r);return{sent:true};};const h=setup(async()=>({session:s,metadata:{}})),id=(await h.invoke('network:connect',request())).value.sessionId,r={actorId:0xffffffff,quickChat:22,areaId:0x80000001,areaGeneration:1};assert.equal((await h.invoke('network:quick-chat','stale',r)).ok,false);assert.equal((await h.handlers.get('network:quick-chat')({sender:h.sender,senderFrame:{}},id,r)).ok,false);assert.deepEqual((await h.invoke('network:quick-chat',id,r)).value,{sent:true});assert.deepEqual(calls,[r]);await h.invoke('network:disconnect');assert.equal((await h.invoke('network:quick-chat',id,r)).ok,false);
});
test('spell-cast IPC admits only the trusted frame of the current owning session',async()=>{
 const s=fakeSession(),calls=[];s.castSpell=async r=>{calls.push(r);return{sent:true};};const h=setup(async()=>({session:s,metadata:{}})),id=(await h.invoke('network:connect',request())).value.sessionId,r={spellId:100,targetId:0xffffffff,areaId:0x80000001,areaGeneration:1};assert.equal((await h.invoke('network:spell-cast','stale',r)).ok,false);assert.equal((await h.handlers.get('network:spell-cast')({sender:h.sender,senderFrame:{}},id,r)).ok,false);assert.deepEqual((await h.invoke('network:spell-cast',id,r)).value,{sent:true});assert.deepEqual(calls,[r]);await h.invoke('network:disconnect');assert.equal((await h.invoke('network:spell-cast',id,r)).ok,false);
});

test('feat/mode IPC requires the current owning session and trusted main frame',async()=>{
 const s=fakeSession(),calls=[];s.useFeat=async r=>{calls.push(['feat',r]);return{sent:true};};s.changeMode=async r=>{calls.push(['mode',r]);return{sent:true};};s.possessFamiliar=async r=>{calls.push(['possess',r]);return{sent:true};};const h=setup(async()=>({session:s,metadata:{}})),id=(await h.invoke('network:connect',request())).value.sessionId,r={featId:303,modeId:3,areaId:0x80000001,areaGeneration:1};
 for(const channel of ['network:feat-use','network:mode-change','network:familiar-possess']){assert.equal((await h.invoke(channel,'stale',r)).ok,false);assert.equal((await h.handlers.get(channel)({sender:h.sender,senderFrame:{}},id,r)).ok,false);assert.deepEqual((await h.invoke(channel,id,r)).value,{sent:true});}assert.deepEqual(calls,[['feat',r],['mode',r],['possess',r]]);await h.invoke('network:disconnect');assert.equal((await h.invoke('network:feat-use',id,r)).ok,false);
});

test('innate-cast IPC admits only the trusted frame of the current owning session',async()=>{
 const s=fakeSession(),calls=[];s.castSpellLike=async r=>{calls.push(r);return{sent:true};};const h=setup(async()=>({session:s,metadata:{}})),id=(await h.invoke('network:connect',request())).value.sessionId,r={spellId:100,casterLevel:7,targetId:0xffffffff,areaId:0x80000001,areaGeneration:1};assert.equal((await h.invoke('network:spell-like-cast','stale',r)).ok,false);assert.equal((await h.handlers.get('network:spell-like-cast')({sender:h.sender,senderFrame:{}},id,r)).ok,false);assert.deepEqual((await h.invoke('network:spell-like-cast',id,r)).value,{sent:true});assert.deepEqual(calls,[r]);await h.invoke('network:disconnect');assert.equal((await h.invoke('network:spell-like-cast',id,r)).ok,false);
});

test('quickbar IPC requires the owning session and trusted frame for assignment and activation',async()=>{
 const s=fakeSession(),calls=[];s.assignQuickbar=async r=>{calls.push(['assign',r]);return{sent:true,button:r.button};};s.activateQuickbar=async r=>{calls.push(['use',r]);return{sent:true};};const h=setup(async()=>({session:s,metadata:{}})),connected=await h.invoke('network:connect',request()),id=connected.value.sessionId,r={areaId:0x80000001,areaGeneration:1,index:3,button:{type:0}};
 for(const channel of ['network:quickbar-assign','network:quickbar-use']){assert.equal((await h.invoke(channel,'stale',r)).ok,false);assert.equal((await h.handlers.get(channel)({sender:h.sender,senderFrame:{}},id,r)).ok,false);assert.equal((await h.invoke(channel,id,r)).value.sent,true);}
 assert.deepEqual(calls,[['assign',r],['use',r]]);await h.invoke('network:disconnect');assert.equal((await h.invoke('network:quickbar-assign',id,r)).ok,false);
});

test('IPC rejects other frames/documents and does not expose arbitrary transport or filesystem methods',async()=>{
 const s=fakeSession(),h=setup(async()=>({session:s,metadata:{}}));
 assert.equal((await h.handlers.get('network:connect')({sender:h.sender,senderFrame:{}},request())).ok,false);
 h.sender.getURL=()=> 'file:///untrusted.html';assert.equal((await h.invoke('network:connect',request())).ok,false);
 assert.equal([...h.handlers.keys()].some(k=>/raw|send|read-file/.test(k)),false);await h.controller.disconnect(h.sender);
});
test('renderer access requires the owning session ID and connection events omit credentials',async()=>{
 const s=fakeSession(),h=setup(async()=>({session:s,metadata:{}})),r=request();const result=await h.invoke('network:connect',r);assert.equal(result.ok,true);assert.equal(r.credentials,undefined);
 assert.equal((await h.invoke('network:resource','wrong','model',2002)).ok,false);assert.deepEqual((await h.invoke('network:resource',result.value.sessionId,'model',2002)).value,['model',2002]);
 assert.equal(JSON.stringify(h.sender.events).includes('private-fixture'),false);await h.invoke('network:disconnect');assert.equal(s.disposeCount,1);
});
test('streaming audio IPC requires the current owner and trusted frame, and exposes only a resource key/type',async()=>{
 const s=fakeSession(),calls=[];s.getAudioResource=async(ref,type)=>{calls.push([ref,type]);return{type,bytes:Uint8Array.of(8)};};const h=setup(async()=>({session:s,metadata:{}})),id=(await h.invoke('network:connect',request())).value.sessionId;
 assert.equal((await h.invoke('network:audio-resource','stale','track',8)).ok,false);assert.equal((await h.handlers.get('network:audio-resource')({sender:h.sender,senderFrame:{}},id,'track',8)).ok,false);assert.equal((await h.invoke('network:audio-resource',id,'track',8)).value.type,8);assert.deepEqual(calls,[['track',8]]);await h.invoke('network:disconnect');assert.equal((await h.invoke('network:audio-resource',id,'track',8)).ok,false);
});
test('closing a window while installation setup is pending closes the resulting session without connecting it',async()=>{
 let resolve,connected=0;const pending=new Promise(r=>resolve=r),s=fakeSession();s.connect=async()=>connected++;
 const h=setup(()=>pending),connection=h.invoke('network:connect',request());h.sender.emit('destroyed');resolve({session:s,metadata:{}});assert.equal((await connection).ok,false);assert.equal(connected,0);assert.equal(s.disposeCount,1);
});
test('native closure releases the owner so the same renderer can reconnect',async()=>{
 const sessions=[],h=setup(async()=>{const session=fakeSession();sessions.push(session);return{session,metadata:{}};});assert.equal((await h.invoke('network:connect',request())).ok,true);await sessions[0].disconnect();assert.equal((await h.invoke('network:connect',request())).ok,true);assert.equal(sessions.length,2);await h.invoke('network:disconnect');
});

test('keyboard IPC uses the current owner and trusted frame for drive and stop',async()=>{
 const s=fakeSession(),calls=[];s.keyboardMove=async r=>{calls.push(r);return{sent:true};};
 const h=setup(async()=>({session:s,metadata:{}})),id=(await h.invoke('network:connect',request())).value.sessionId,r={areaId:0x80000001,areaGeneration:1,actorId:0xffffffff,operation:'stop'};
 assert.equal((await h.invoke('network:keyboard','stale',r)).ok,false);assert.equal((await h.handlers.get('network:keyboard')({sender:h.sender,senderFrame:{}},id,r)).ok,false);
 assert.deepEqual((await h.invoke('network:keyboard',id,r)).value,{sent:true});assert.deepEqual(calls,[r]);await h.controller.disconnect(h.sender,{saveCharacter:false});assert.equal((await h.invoke('network:keyboard',id,r)).ok,false);
});
test('movement uses the owning session and cannot cross renderer or stale session boundaries',async()=>{
 const s=fakeSession(),calls=[];s.walkTo=async r=>{calls.push(r);return{sequence:1};};
 const h=setup(async()=>({session:s,metadata:{}})),connected=await h.invoke('network:connect',request()),id=connected.value.sessionId;
 const move={areaId:0x80000001,areaGeneration:1,position:[6,5,0],run:true};
 assert.equal((await h.invoke('network:walk','stale',move)).ok,false);
 assert.equal((await h.handlers.get('network:walk')({sender:h.sender,senderFrame:{}},id,move)).ok,false);
 assert.deepEqual((await h.invoke('network:walk',id,move)).value,{sequence:1});assert.deepEqual(calls,[move]);
 await h.invoke('network:disconnect');assert.equal((await h.invoke('network:walk',id,move)).ok,false);assert.equal(calls.length,1);
});

test('interaction IPC requires the current owning session and trusted main frame',async()=>{
 const s=fakeSession(),calls=[];s.interact=async r=>{calls.push(r);return{sent:true};};const h=setup(async()=>({session:s,metadata:{}})),connected=await h.invoke('network:connect',request()),id=connected.value.sessionId,r={areaId:0x80000001,areaGeneration:1,targetId:0x80000002,action:'door.close'};
 assert.equal((await h.invoke('network:interact','stale',r)).ok,false);assert.equal((await h.handlers.get('network:interact')({sender:h.sender,senderFrame:{}},id,r)).ok,false);assert.equal(calls.length,0);
 assert.deepEqual((await h.invoke('network:interact',id,r)).value,{sent:true});assert.deepEqual(calls,[r]);await h.invoke('network:disconnect');assert.equal((await h.invoke('network:interact',id,r)).ok,false);
});

test('inventory IPC is scoped to the current session and its trusted main frame',async()=>{
 const s=fakeSession(),calls=[];s.inventoryWindow=async r=>{calls.push(['window',r]);return{sent:true};};s.inventoryPanel=async r=>{calls.push(['panel',r]);return{sent:true};};const h=setup(async()=>({session:s,metadata:{}})),connected=await h.invoke('network:connect',request()),id=connected.value.sessionId;
 for(const [name,r]of [['window',{areaId:0x80000001,areaGeneration:1,open:true}],['panel',{areaId:0x80000001,areaGeneration:1,panel:0}]]){
  const channel=`network:inventory-${name}`;assert.equal((await h.invoke(channel,'stale',r)).ok,false);assert.equal((await h.handlers.get(channel)({sender:h.sender,senderFrame:{}},id,r)).ok,false);assert.deepEqual((await h.invoke(channel,id,r)).value,{sent:true});
 }
 assert.equal(calls.length,2);await h.invoke('network:disconnect');assert.equal((await h.invoke('network:inventory-window',id,{open:true})).ok,false);assert.equal(calls.length,2);
});

test('item action IPC rejects stale session IDs and foreign frames before reaching the game owner',async()=>{
 const s=fakeSession(),calls=[];s.itemAction=async r=>{calls.push(r);return{sent:true};};const h=setup(async()=>({session:s,metadata:{}})),connected=await h.invoke('network:connect',request()),id=connected.value.sessionId,r={areaId:0x80000001,areaGeneration:1,itemId:0x80000002,operation:'equip',slot:16};
 assert.equal((await h.invoke('network:item-action','stale',r)).ok,false);assert.equal((await h.handlers.get('network:item-action')({sender:h.sender,senderFrame:{}},id,r)).ok,false);assert.deepEqual((await h.invoke('network:item-action',id,r)).value,{sent:true});assert.deepEqual(calls,[r]);await h.invoke('network:disconnect');assert.equal((await h.invoke('network:item-action',id,r)).ok,false);
});
