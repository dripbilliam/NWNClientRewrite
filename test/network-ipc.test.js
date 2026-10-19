import test from 'node:test';
import assert from 'node:assert/strict';
import {EventEmitter} from 'node:events';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {registerNetworkIpc} from '../electron/network_ipc.cjs';
const url=pathToFileURL(fileURLToPath(new URL('../dist/index.html',import.meta.url))).href;
function setup(factory){
 const handlers=new Map(),ipc={handle:(name,fn)=>handlers.set(name,fn)},controller=registerNetworkIpc(ipc,{defaultInstall:'/install',userDirectory:null,chooseInstall:async()=>null,createSession:factory});
 const window=new EventEmitter(),sender=new EventEmitter();sender.id=1;sender.mainFrame={};sender.isDestroyed=()=>false;sender.getURL=()=>url;sender.events=[];sender.send=(_channel,event)=>sender.events.push(event);window.webContents=sender;controller.attach(window);
 return{sender,controller,handlers,invoke:(name,...args)=>handlers.get(name)({sender,senderFrame:sender.mainFrame},...args)};
}
function fakeSession(){const s=new EventEmitter();s.closed=false;s.disposeCount=0;s.connect=async()=>{s.emit('state',{phase:'connecting'});};s.state=()=>({phase:'resources'});s.disconnect=async()=>{if(s.closed)return;s.closed=true;s.disposeCount++;s.emit('closed');};s.getResource=async(ref,type)=>[ref,type];return s;}
const request=()=>({host:'localhost',port:5121,name:'Tester',credentials:{cdKey:'private-fixture'}});

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
test('closing a window while installation setup is pending closes the resulting session without connecting it',async()=>{
 let resolve,connected=0;const pending=new Promise(r=>resolve=r),s=fakeSession();s.connect=async()=>connected++;
 const h=setup(()=>pending),connection=h.invoke('network:connect',request());h.sender.emit('destroyed');resolve({session:s,metadata:{}});assert.equal((await connection).ok,false);assert.equal(connected,0);assert.equal(s.disposeCount,1);
});
test('native closure releases the owner so the same renderer can reconnect',async()=>{
 const sessions=[],h=setup(async()=>{const session=fakeSession();sessions.push(session);return{session,metadata:{}};});assert.equal((await h.invoke('network:connect',request())).ok,true);await sessions[0].disconnect();assert.equal((await h.invoke('network:connect',request())).ok,true);assert.equal(sessions.length,2);await h.invoke('network:disconnect');
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
