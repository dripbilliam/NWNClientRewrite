import test from 'node:test';
import assert from 'node:assert/strict';
import {EventEmitter} from 'node:events';
import {NativeMessageReader} from '../src/native_message.js';
import {NetworkGameSession} from '../electron/network_game_session.mjs';
import {GUI_CONTEXT_SOURCES,guiContextOpenRequest} from '../src/network_gui_context_input.js';
const INVALID=0x7f000000,build=revision=>({number:8193,revision,postfix:0});
function fields(bytes,position=true){const r=new NativeMessageReader(1),body=bytes.subarray(3);assert.deepEqual([...bytes.subarray(0,3)],[112,53,1]);assert.equal(r.setReadMessage(body,body.length,0xffffffff,1),1);const value={event:r.readWord(),selection:r.readWord(),targetId:r.readObjectIdClient()};if(position)value.position=[r.readFloat(),r.readFloat(),r.readFloat()];assert.equal(r.messageReadOverflow(),0);assert.equal(r.messageReadUnderflow(),0);return value;}
function harness(){const peer=new EventEmitter(),sent=[];peer.sendGameMessage=async bytes=>sent.push(Uint8Array.from(bytes));peer.disconnect=async()=>peer.emit('closed');const session=new NetworkGameSession({peer,identity:{dispose(){}},build:{build:build(37),dispose(){}},resources:{},language:0,openModule:async()=>null});session.phase='playing';session.areaReadySent=true;session.areaGeneration=2;const actor={id:0xffffffce,objectType:5,areaId:0x80000001};session.world.localObjectId=actor.id;session.world.areaId=actor.areaId;session.world.registry.addObjectAtPos(actor.id,actor);const targets={};let id=0x80000010;for(const [name,source]of Object.entries(GUI_CONTEXT_SOURCES))if(source.objectType!==null){const target={id:id++,objectType:source.objectType,areaId:actor.areaId};targets[name]=target;session.world.registry.addObjectAtPos(target.id,target);}const request=(sourceKind,attemptSerial=1)=>({areaId:actor.areaId,areaGeneration:2,actorId:actor.id,panel:'context-attempt',open:true,sourceKind,guiPanelId:GUI_CONTEXT_SOURCES[sourceKind].panelId,targetId:sourceKind==='ground'?INVALID:targets[sourceKind].id,position:sourceKind==='ground'?[1.25,-2.5,3.75]:[0,0,0],accessRevision:session.world.guiPanelAccess.sequence,attemptSerial});return{session,peer,sent,actor,targets,request};}
const disable=(panelId,targetId=INVALID,disabled=true)=>({kind:'gui-panel-disabled',panelId,targetId,disabled,targetSource:'received'});
test('typed original GUI26 writes six verified selections, exact targets and versioned NWN XYZ',()=>{
 for(const includePosition of [false,true])for(const [sourceKind,source]of Object.entries(GUI_CONTEXT_SOURCES)){
  const targetId=sourceKind==='ground'?INVALID:0xffffffce,position=sourceKind==='ground'?[1.25,-2.5,3.75]:[0,0,0];
  assert.deepEqual(fields(guiContextOpenRequest({sourceKind,targetId,position,includePosition}),includePosition),{event:26,selection:source.selection,targetId,...(includePosition?{position}: {})});
 }
 assert.ok(Object.isFrozen(GUI_CONTEXT_SOURCES)&&Object.isFrozen(GUI_CONTEXT_SOURCES.creature));
});
test('typed context serializer rejects prototype names, missing/null/coerced fields and object XYZ',()=>{
 const base={sourceKind:'ground',targetId:INVALID,position:[1,2,3],includePosition:true};
 for(const sourceKind of [undefined,null,'toString','__proto__','constructor','portrait',16,{}])assert.throws(()=>guiContextOpenRequest({...base,sourceKind}));
 for(const position of [undefined,null,[],[0,0],[0,0,0,0],[0,null,0],[0,'1',0],[0,NaN,0],[Infinity,0,0],[1e100,0,0]])assert.throws(()=>guiContextOpenRequest({...base,position}));
 for(const change of [{targetId:0},{includePosition:undefined},{sourceKind:'creature'},{sourceKind:'creature',targetId:42,position:[1,0,0]}])assert.throws(()=>guiContextOpenRequest({...base,...change}));
});
test('real Session chooses GUI26 when admitted and GUI14 for every fresh matching blocked attempt',async()=>{
 const h=harness();let serial=0;
 for(const [name,source]of Object.entries(GUI_CONTEXT_SOURCES)){
  const request=h.request(name,++serial);let result=await h.session.hudPanel(request);assert.equal(result.blocked,false);assert.equal(result.serverAcknowledged,false);assert.equal(fields(h.sent.at(-1)).selection,source.selection);
  h.session.world.apply(disable(source.panelId,request.targetId));
  for(let repeat=0;repeat<2;repeat++){result=await h.session.hudPanel(h.request(name,++serial));assert.equal(result.blocked,true);assert.deepEqual(fields(h.sent.at(-1)),{event:14,selection:source.panelId,targetId:request.targetId,position:[0,0,0]});}
  h.session.world.apply(disable(source.panelId,request.targetId,false));
 }
 assert.equal(h.sent.length,18);await h.session.disconnect();
});
test('real Session validates context source/type/area/lifecycle and preserves unavailable fields',async()=>{
 const h=harness(),base=h.request('creature');
 for(const change of [{sourceKind:'portrait'},{sourceKind:'constructor'},{sourceKind:null},{sourceKind:'item'},{guiPanelId:16},{targetId:INVALID},{position:[1,0,0]},{position:null},{accessRevision:null},{attemptSerial:0},{attemptSerial:'1'},{areaGeneration:1},{areaId:0},{actorId:0},{open:'true'}])await assert.rejects(h.session.hudPanel({...base,...change}));
 for(const change of [{areaId:0},{areaId:undefined},{objectType:6},{destroyed:true},{replicationRemoved:true}]){const target=h.targets.creature,saved={...target};Object.assign(target,change);await assert.rejects(h.session.hudPanel(base));for(const key of Object.keys(target))delete target[key];Object.assign(target,saved);}
 assert.equal(h.sent.length,0);await h.session.disconnect();
});
test('global/exact removal and shared native attempt serial retain5..8 semantics',async()=>{
 const h=harness();h.session.world.apply(disable(18,h.targets.creature.id));h.session.world.apply(disable(18));h.session.world.apply(disable(18,h.targets.creature.id,false));assert.equal((await h.session.hudPanel(h.request('creature',1))).blocked,true);
 h.session.world.apply(disable(18,h.targets.creature.id));h.session.world.apply(disable(18,INVALID,false));assert.equal((await h.session.hudPanel(h.request('creature',2))).blocked,true);
 const other={id:0x80000020,objectType:5,areaId:h.actor.areaId};h.session.world.registry.addObjectAtPos(other.id,other);assert.equal((await h.session.hudPanel({...h.request('creature',3),targetId:other.id})).blocked,false);
 const revision=h.session.world.guiPanelAccess.sequence;assert.throws(()=>h.session.world.apply(disable(18,false)));assert.equal(h.session.world.guiPanelAccess.sequence,revision);
 h.session.world.apply(disable(18,h.targets.creature.id,false));assert.equal((await h.session.hudPanel(h.request('creature',4))).blocked,false);assert.equal(h.sent.length,4);await h.session.disconnect();
});
test('shared attempt serial rejects replays across ordinary and context branches',async()=>{
 const h=harness();h.session.world.apply(disable(6));await h.session.hudPanel({...h.request('ground'),panel:'blocked-attempt',guiPanelId:6,targetId:INVALID,attemptSerial:10});
 await assert.rejects(h.session.hudPanel(h.request('ground',10)));await h.session.hudPanel(h.request('ground',11));await assert.rejects(h.session.hudPanel(h.request('ground',11)));assert.equal(h.sent.length,2);await h.session.disconnect();
});
test('old builds omit XYZ and typed object event remains zero on newer versions',async()=>{
 const h=harness();h.session.serverBuild=build(34);await h.session.hudPanel(h.request('ground'));assert.deepEqual(fields(h.sent.at(-1),false),{event:26,selection:1,targetId:INVALID});h.session.serverBuild=build(37);await h.session.hudPanel(h.request('door',2));assert.deepEqual(fields(h.sent.at(-1)),{event:26,selection:6,targetId:h.targets.door.id,position:[0,0,0]});await h.session.disconnect();
});
test('post-await target replacement, removal or same-object area mutation reject without retry/disconnect',async()=>{
 for(const change of ['replace','remove','move','destroy']){const h=harness();let release;const gate=new Promise(resolve=>release=resolve);h.peer.sendGameMessage=async bytes=>{h.sent.push(bytes);await gate;};const pending=h.session.hudPanel(h.request('creature'));await new Promise(resolve=>setImmediate(resolve));const target=h.targets.creature;if(change==='replace'){h.session.world.registry.delete(target.id);h.session.world.registry.addObjectAtPos(target.id,{...target});}else if(change==='remove')h.session.world.registry.delete(target.id);else if(change==='move')target.areaId++;else target.destroyed=true;release();await assert.rejects(pending);assert.equal(h.sent.length,1);assert.equal(h.session.closed,false);await h.session.disconnect();}
});
