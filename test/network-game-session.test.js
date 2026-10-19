import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {EventEmitter} from 'node:events';
import {NetworkGameSession} from '../electron/network_game_session.mjs';
import {writeGff,gffRecord} from '../src/gff_writer.js';
import {RESOURCE_TYPE} from '../src/resource_archive.js';
import {spellCastRequest,spellLikeCastRequest,spellPreparationRequest,spellPreparationClearRequest} from '../src/network_spell_input.js';
import {featUseRequest,modeChangeRequest} from '../src/network_feat_input.js';
import {associateCommandRequest,quickChatRequest} from '../src/network_associate_input.js';
import {itemUseRequest} from '../src/network_item_input.js';
import {restRequest,characterSheetRequest,journalWindowRequest,playerAttitudeRequest} from '../src/network_hud_input.js';

const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-peer-v2.json',import.meta.url)));
const wireMessage=kind=>structuredClone(capture.transport.messages.find(m=>m.kind===kind));
const bic=()=>writeGff('BIC ',gffRecord({}));
const deferred=()=>{let resolve;const promise=new Promise(r=>resolve=r);return{promise,resolve};};

test('HUD requests use controlled session and live player lookup, leaving all canonical resources untouched',async()=>{
 const h=harness(),s=h.session,actor={id:0xffffffff,areaId:0x80000001,objectType:5,playerState:{spellbooks:{0:{memorized:{0:[{spell:1,ready:0}]}}}}};s.phase='playing';s.areaReadySent=true;s.areaGeneration=2;s.world.areaId=actor.areaId;s.world.localObjectId=actor.id;s.world.registry.addObjectAtPos(actor.id,actor);s.world.players.set(7,{playerId:7,objectId:0x80000002});const base={areaId:actor.areaId,areaGeneration:2,actorId:actor.id},before=structuredClone(actor);
 await s.rest(base);assert.deepEqual(h.sent.at(-1),[...restRequest()]);await s.hudPanel({...base,panel:'character',open:true,page:0});assert.deepEqual(h.sent.at(-1),[...characterSheetRequest({targetId:actor.id,page:0})]);await s.hudPanel({...base,panel:'character',open:false});assert.deepEqual(h.sent.at(-1),[...characterSheetRequest({targetId:actor.id,page:-1})]);await s.hudPanel({...base,panel:'journal',open:true});assert.deepEqual(h.sent.at(-1),[...journalWindowRequest(true)]);await s.playerAttitude({...base,playerId:7,likes:false});assert.deepEqual(h.sent.at(-1),[...playerAttitudeRequest({targetId:0x80000002,likes:false})]);assert.deepEqual(actor,before);
 for(const change of [{areaGeneration:1},{actorId:1},{areaId:0}])await assert.rejects(s.rest({...base,...change}));await assert.rejects(s.hudPanel({...base,panel:'map',open:true}));await assert.rejects(s.playerAttitude({...base,playerId:8,likes:false}));assert.equal(h.sent.length,5);
});

test('preparation uses typed server requests and never grants, readies or clears canonical spells locally',async()=>{
 const h=harness(),s=h.session,actor={id:0xffffffff,areaId:0x80000001,objectType:5,playerState:{spellbooks:{0:{memorized:{1:[null,{spell:123,ready:1}]}}}}};s.phase='playing';s.areaReadySent=true;s.areaGeneration=2;s.world.areaId=actor.areaId;s.world.localObjectId=actor.id;s.world.registry.addObjectAtPos(actor.id,actor);
 const base={areaId:actor.areaId,areaGeneration:2,actorId:actor.id,classIndex:0,slot:0},request={...base,spellId:123,domainLevel:0,metamagic:0},before=structuredClone(actor);
 await s.prepareSpell(request);assert.deepEqual(h.sent.at(-1),[...spellPreparationRequest(request)]);await s.prepareSpell({...base,clear:true,level:1});assert.deepEqual(h.sent.at(-1),[...spellPreparationClearRequest({...base,level:1})]);assert.deepEqual(actor,before);
 for(const change of [{actorId:1},{areaGeneration:1},{areaId:0},{classIndex:256},{slot:-1},{spellId:-1},{clear:1}])await assert.rejects(s.prepareSpell({...request,...change}));assert.equal(h.sent.length,2);await s.disconnect();await assert.rejects(s.prepareSpell(request),/not ready/);
});

test('item powers send native requests for the controlled inventory and preserve authoritative charges/actions',async()=>{
 const h=harness(),s=h.session,actor={id:0xffffffff,objectType:5,areaId:0x80000001,replicated:{}},item={id:0x80000002,objectType:6,item:{propertyUses:[3],properties:[{type:15,remaining:1}]},inventoryLocation:{ownerId:actor.id,channel:'R'}};s.phase='playing';s.areaReadySent=true;s.areaGeneration=2;s.world.areaId=actor.areaId;s.world.localObjectId=actor.id;for(const o of [actor,item])s.world.registry.addObjectAtPos(o.id,o);
 const r={areaId:actor.areaId,areaGeneration:2,itemId:item.id,propertyIndex:0,variant:255,targetId:actor.id,position:[0,0,0]},before=structuredClone([...s.world.registry.objects]);assert.deepEqual(await s.useItem(r),{sent:true});assert.deepEqual(h.sent.at(-1),[...itemUseRequest(r)]);assert.deepEqual([...s.world.registry.objects],before);
 for(const change of [{areaGeneration:1},{areaId:2},{itemId:123},{propertyIndex:256},{targetId:123},{position:[0,NaN,0]}])await assert.rejects(s.useItem({...r,...change}));item.inventoryLocation.ownerId=123;await assert.rejects(s.useItem(r),/source/);assert.equal(h.sent.length,1);await s.disconnect();await assert.rejects(s.useItem(r),/not ready/);
});

test('inventory panel request clears only GUI repository entries before transport can deliver the fresh page',async()=>{
 const h=harness(),s=h.session,actor={id:0xffffffff,objectType:5,areaId:0x80000001,replicated:{}};s.phase='playing';s.areaReadySent=true;s.areaGeneration=2;s.world.areaId=actor.areaId;s.world.localObjectId=actor.id;s.world.registry.addObjectAtPos(actor.id,actor);s.world.inventories.set('R',{entries:[{id:0x80000002,x:0,y:0}]});const before=structuredClone([...s.world.registry.objects]);let observed=false;h.peer.sendGameMessage=async()=>{observed=true;assert.deepEqual(s.world.inventories.get('R').entries,[]);};await s.inventoryPanel({areaId:actor.areaId,areaGeneration:2,panel:0});assert.ok(observed);assert.deepEqual([...s.world.registry.objects],before);s.world.inventories.get('R').entries=[{id:0x80000002}];await assert.rejects(s.inventoryPanel({areaId:actor.areaId,areaGeneration:2,panel:256}));assert.equal(s.world.inventories.get('R').entries.length,1,'invalid input does not clear the current panel');
});

test('associate requests require current control and canonical targets but leave ownership, AI and unpossession to the server',async()=>{
 const h=harness(),s=h.session,actor={id:0x80000002,areaId:0x80000001,objectType:5,replicated:{master:0xffffffff,field908:3}},target={id:0xffffffff,areaId:0x80000003,objectType:5,replicated:{}};
 s.phase='playing';s.areaReadySent=true;s.areaGeneration=2;s.world.areaId=actor.areaId;s.world.localObjectId=actor.id;for(const o of [actor,target])s.world.registry.addObjectAtPos(o.id,o);
 const r={areaId:actor.areaId,areaGeneration:2,actorId:actor.id,targetId:actor.id,command:-13},before=structuredClone([...s.world.registry.objects]);
 assert.deepEqual(await s.associateCommand(r),{sent:true});assert.deepEqual(h.sent.at(-1),[...associateCommandRequest(r)]);assert.equal(s.world.localObjectId,actor.id);
 await s.associateCommand({...r,targetId:target.id,command:-5});assert.deepEqual([...s.world.registry.objects],before,'no native ownership/AI/control result is synthesized');
 const n=h.sent.length;for(const change of [{areaId:actor.areaId+1},{areaGeneration:1},{actorId:target.id},{targetId:0x7f000000},{command:2147483648}])await assert.rejects(s.associateCommand({...r,...change}));assert.equal(h.sent.length,n);
 target.replicationRemoved=true;await assert.rejects(s.associateCommand({...r,targetId:target.id}));await s.disconnect();await assert.rejects(s.associateCommand(r),/not ready/);
});
function harness(overrides={}){
 const peer=new EventEmitter(),sent=[],diagnostics=[],events=[],states=[];let identityDisposals=0,buildDisposals=0,disconnects=0;
 peer.connect=async()=>({kind:'test-peer'});peer.sendGameMessage=async bytes=>{sent.push(Array.from(bytes));};peer.disconnect=async()=>{disconnects++;peer.emit('closed');};
 const resolver={getResource:async()=>Uint8Array.of(7).buffer};
 const session=new NetworkGameSession({peer,identity:{dispose:()=>identityDisposals++},build:{build:capture.clientBuild,dispose:()=>buildDisposals++},resources:{findFile:async()=>'/private/module.nwm'},language:0,openModule:async()=>resolver,loadRules:async()=>({}),decodeMessage:m=>m,onDiagnostic:d=>diagnostics.push(d),...overrides});
 session.on('message',m=>events.push(m));session.on('state',s=>states.push(s));
 const deliver=async m=>{peer.emit('message',m);await session.delivery;};
 return{session,peer,sent,diagnostics,events,states,deliver,disposals:()=>[identityDisposals,buildDisposals,disconnects]};
}

test('global quickchat and server-owned associate shortcuts use current control without local AI or ownership mutation',async()=>{
 const h=harness(),s=h.session,actor={id:0xffffffff,areaId:0x80000001,objectType:5,replicated:{},familiarId:0x80000002};s.phase='playing';s.areaReadySent=true;s.areaGeneration=2;s.world.areaId=actor.areaId;s.world.localObjectId=actor.id;s.world.registry.addObjectAtPos(actor.id,actor);
 const r={areaId:actor.areaId,areaGeneration:2,actorId:actor.id},before=structuredClone(actor);await s.quickChat({...r,quickChat:22});assert.deepEqual(h.sent.at(-1),[...quickChatRequest({quickChat:22})]);
 for(const change of [{actorId:0x80000002},{areaGeneration:1},{quickChat:65536}])await assert.rejects(s.quickChat({...r,quickChat:22,...change}));
 for(const [button,expected]of [[{type:38},[112,6,19]],[{type:42,intParam:65558},[...quickChatRequest({quickChat:22})]],[{type:39,intParam:65528,associateType:3,associateId:123},[...associateCommandRequest({targetId:actor.familiarId,command:-8})]],[{type:39,intParam:-9,associateType:2},[...associateCommandRequest({targetId:0x7f000000,command:-9})]]]){s.world.quickbar[10]=button;assert.deepEqual(await s.activateQuickbar({...r,index:10}),{sent:true});assert.deepEqual(h.sent.at(-1),expected);}
 s.world.quickbar[10]={type:39,intParam:-8,associateType:0};const n=h.sent.length;assert.deepEqual(await s.activateQuickbar({...r,index:10}),{sent:false});assert.equal(h.sent.length,n);assert.deepEqual(actor,before);await s.disconnect();await assert.rejects(s.quickChat({...r,quickChat:22}),/not ready/);
});

test('server character rejection retains its native reason and never admits or exposes the character payload',async()=>{
 const h=harness();await h.session.selectCharacter(bic());await h.deliver({kind:'character-rejected',major:2,minor:18,reason:66222});assert.equal(h.session.phase,'character-rejected');assert.equal(h.session.state().characterConfirmed,false);assert.equal(h.session.state().areaReady,false);assert.deepEqual(h.diagnostics,[{code:'network.character-rejected',reason:'The server rejected the selected character',strRef:66222}]);await h.session.disconnect();
});
test('spell input uses module metadata, current canonical targets and no local gameplay or slot mutation',async()=>{
 const h=harness(),s=h.session,id=0xffffffff,areaId=0x80000001;s.phase='playing';s.areaReadySent=true;s.areaGeneration=2;s.world.areaId=areaId;s.world.localObjectId=id;s.world.registry.addObjectAtPos(id,{id,objectType:5,areaId,replicated:{},playerState:{spellbooks:{0:{memorized:{0:[{spell:123,ready:1}]}}}}});s.objectRules.spellInputInfo=n=>n===123?{targetType:9}:null;
 const itemId=0x80000002;s.world.registry.addObjectAtPos(itemId,{id:itemId,objectType:6,areaId:0x7f000000,inventoryLocation:{channel:'R',ownerId:id}});const before=structuredClone([...s.world.registry.objects]),r={areaId,areaGeneration:2,spellId:123,classIndex:0,domainLevel:0,metamagic:0,spontaneous:false,targetId:id,position:[1,2,3],targetType:0};
 for(const targetId of [id,itemId,0x7f000000]){assert.deepEqual(await s.castSpell({...r,targetId}),{sent:true});assert.deepEqual(h.sent.at(-1),[...spellCastRequest({...r,targetId,targetType:9})]);}assert.deepEqual([...s.world.registry.objects],before);
 for(const change of [{areaGeneration:1},{areaId:areaId+1},{targetId:0x80000003},{spellId:124},{classIndex:256},{position:[0,0,Infinity]}])await assert.rejects(s.castSpell({...r,...change}));assert.equal(h.sent.length,3);await s.disconnect();await assert.rejects(s.castSpell(r),/not ready/);
});

test('feat/mode input uses only the current controlled session and never spends or grants replicated resources',async()=>{
 const h=harness(),s=h.session,id=0xffffffff,areaId=0x80000001;s.phase='playing';s.areaReadySent=true;s.areaGeneration=2;s.world.areaId=areaId;s.world.localObjectId=id;s.world.registry.addObjectAtPos(id,{id,objectType:5,areaId,replicated:{},playerState:{feats:[303],featUses:{303:1}}});s.objectRules.featInputInfo=n=>n===303?{}:null;
 const base={areaId,areaGeneration:2},r={...base,featId:303,targetId:id},before=structuredClone([...s.world.registry.objects]);await s.useFeat(r);assert.deepEqual(h.sent.at(-1),[...featUseRequest(r)]);await s.changeMode({...base,modeId:3});assert.deepEqual(h.sent.at(-1),[...modeChangeRequest({modeId:3})]);assert.deepEqual([...s.world.registry.objects],before);
 for(const change of [{areaGeneration:1},{areaId:areaId+1},{targetId:123},{featId:304},{auxiliary:65536}])await assert.rejects(s.useFeat({...r,...change}));await assert.rejects(s.changeMode({...base,modeId:256}));await assert.rejects(s.changeMode({...base,modeId:5,targetId:123}));assert.equal(h.sent.length,2);await assert.rejects(s.possessFamiliar({...base,areaGeneration:1}));await s.possessFamiliar(base);assert.deepEqual(h.sent.at(-1),[112,6,19]);assert.deepEqual([...s.world.registry.objects],before);await s.disconnect();await assert.rejects(s.useFeat(r),/not ready/);
});

test('innate input requires current canonical targets and leaves server ability pools untouched',async()=>{
 const h=harness(),s=h.session,id=0xffffffff,areaId=0x80000001;s.phase='playing';s.areaReadySent=true;s.areaGeneration=2;s.world.areaId=areaId;s.world.localObjectId=id;s.world.registry.addObjectAtPos(id,{id,objectType:5,areaId,replicated:{},playerState:{specialAbilities:[{spell:123,level:7,state:1}]}});s.objectRules.spellInputInfo=n=>n===123?{targetType:1}:null;
 const r={areaId,areaGeneration:2,spellId:123,casterLevel:7,targetId:id,position:[1,2,3]},before=structuredClone([...s.world.registry.objects]);
 for(const targetId of [id,0x7f000000]){assert.deepEqual(await s.castSpellLike({...r,targetId}),{sent:true});assert.deepEqual(h.sent.at(-1),[...spellLikeCastRequest({...r,targetId})]);}assert.deepEqual([...s.world.registry.objects],before);
 for(const change of [{areaGeneration:1},{areaId:areaId+1},{targetId:0x80000003},{spellId:124},{casterLevel:256},{position:[0,0,Infinity]}])await assert.rejects(s.castSpellLike({...r,...change}));assert.equal(h.sent.length,2);await s.disconnect();await assert.rejects(s.castSpellLike(r),/not ready/);
});
test('quickbar assignment and paired activation use only the controlled session and never create a local gameplay action',async()=>{
 const h=harness(),s=h.session,id=0xffffffff,areaId=0x80000001;s.phase='playing';s.areaReadySent=true;s.areaGeneration=2;s.world.areaId=areaId;s.world.localObjectId=id;s.world.registry.addObjectAtPos(id,{id,objectType:5,areaId,replicated:{}});
 s.objectRules.quickbarItemInfo=()=>({container:0,equipableSlots:16});
 for(const itemId of [0x80000002,0x80000003])s.world.registry.addObjectAtPos(itemId,{id:itemId,objectType:6,item:{},inventoryLocation:{ownerId:id,channel:'R'}});
 const request={areaId,areaGeneration:2,index:4,button:{type:1,itemId:0x80000002,secondaryItemId:0x80000003,intParam:255}};assert.equal((await s.assignQuickbar(request)).sent,true);assert.deepEqual(h.sent[0].slice(0,3),[112,30,2]);assert.equal(s.world.quickbar[4].secondaryItemId,0x80000003);
 assert.equal((await s.activateQuickbar({areaId,areaGeneration:2,index:4})).sent,true);assert.deepEqual(h.sent[1].slice(0,3),[112,12,11]);assert.equal(s.world.registry.get(id).objectActionState,undefined);
 await assert.rejects(s.assignQuickbar({...request,areaGeneration:1}),/not ready/);await assert.rejects(s.assignQuickbar({...request,button:{...request.button,itemId:0x80000009}}),/item is unavailable/);await assert.rejects(s.activateQuickbar({areaId,areaGeneration:2,index:36}),/index/);assert.equal(h.sent.length,2);
 await s.assignQuickbar({...request,index:5,button:{type:2,classIndex:0,intParam:1,metamagic:0,domainLevel:0}});await assert.rejects(s.activateQuickbar({areaId,areaGeneration:2,index:5}),/not connected/);assert.ok(h.diagnostics.some(d=>d.code==='network.quickbar-action-unhandled'));assert.equal(h.sent.length,3);
 for(const info of [{container:1,equipableSlots:16},{container:0,equipableSlots:0},null]){s.objectRules.quickbarItemInfo=()=>info;await assert.rejects(s.activateQuickbar({areaId,areaGeneration:2,index:4}),/not connected/);assert.equal(h.sent.length,3);}
 h.peer.sendGameMessage=async()=>{s.areaGeneration++;};await assert.rejects(s.assignQuickbar({...request,index:7}),/not ready/);assert.equal(s.world.quickbar[7].type,0);
});

test('admission waits for resources and unchanged character; area entry waits for renderer acknowledgement',async()=>{
 const h=harness();const input=bic(),unchanged=Uint8Array.from(input);await h.session.selectCharacter(input);assert.deepEqual(input,unchanged);assert.equal(h.sent.length,0);
 await h.session.connect({});assert.deepEqual(h.sent,[[112,1,0]]);
 await h.deliver(wireMessage('server-resources'));assert.equal(h.sent.length,2);assert.deepEqual(h.sent[1].slice(0,3),[112,2,1]);assert.equal(h.session.character,null);
 await h.deliver({kind:'character-needed'});assert.equal(h.sent.length,2);
 await h.deliver(wireMessage('character-confirmed'));await h.deliver(wireMessage('module-info'));assert.deepEqual(h.sent.at(-1),[112,3,2]);
 await h.deliver(wireMessage('client-area'));assert.equal(h.sent.length,3);assert.equal(h.session.phase,'area-loading');assert.equal(h.events.at(-1).areaGeneration,1);
 await assert.rejects(h.session.areaReady(0),/stale/);assert.equal(h.sent.length,3);await h.session.areaReady(1);assert.deepEqual(h.sent.at(-1),[112,4,3]);assert.equal(h.session.phase,'playing');
 await assert.rejects(h.session.areaReady(1),/stale/);assert.equal(h.sent.length,4);
 assert.equal(JSON.stringify([h.states,h.events]).includes('/private'),false);
 await h.session.disconnect();await h.session.disconnect();assert.deepEqual(h.disposals(),[1,1,1]);assert.equal(h.session.phase,'closed');
});

test('unavailable content cannot admit a character or report resource readiness',async()=>{
 for(const resources of [{findFile:async()=>null},{findFile:async()=>'/private/module.nwm'}]){
  const h=harness({resources});await h.session.connect({});await h.session.selectCharacter(bic());
  const message=wireMessage('server-resources');if(await resources.findFile())message.requirements.nwmResourceName='';
  await h.deliver(message);assert.equal(h.sent.length,1);assert.equal(h.session.state().resourcesReady,false);assert.equal(h.session.phase,'resources-unavailable');assert.ok(h.diagnostics.length);
  await h.session.disconnect();
 }
});

test('disconnect during resource lookup cancels pending admission and renderer publication',async()=>{
 const lookup=deferred(),h=harness({resources:{findFile:()=>lookup.promise}});await h.session.connect({});await h.session.selectCharacter(bic());
 h.peer.emit('message',wireMessage('server-resources'));await Promise.resolve();await h.session.disconnect();const count=h.states.length;
 lookup.resolve('/private/module.nwm');await h.session.delivery;assert.equal(h.sent.length,1);assert.equal(h.events.length,0);assert.equal(h.states.length,count);assert.equal(h.session.resolver,null);assert.deepEqual(h.disposals(),[1,1,1]);
});

test('old renderer acknowledgement cannot change the phase of a newer area',async()=>{
 const h=harness(),send=deferred();await h.deliver(wireMessage('client-area'));h.peer.sendGameMessage=()=>send.promise;
 const ready=h.session.areaReady(1);await h.deliver(wireMessage('client-area'));send.resolve();await ready;
 assert.equal(h.session.areaGeneration,2);assert.equal(h.session.phase,'area-loading');assert.equal(h.session.areaReadySent,false);await h.session.disconnect();
});

test('archive resource IPC permits resource keys and rejects paths, unknown types and closed sessions',async()=>{
 const h=harness();await h.deliver(wireMessage('server-resources'));assert.deepEqual(new Uint8Array(await h.session.getResource('a_model',RESOURCE_TYPE.MDL)),Uint8Array.of(7));
 assert.equal(RESOURCE_TYPE.SHD,2069);assert.deepEqual(new Uint8Array(await h.session.getResource('inc_keyhole',RESOURCE_TYPE.SHD)),Uint8Array.of(7));
 for(const name of ['../key','C:\\secret','a/b','','a'.repeat(33)])await assert.rejects(h.session.getResource(name,RESOURCE_TYPE.MDL),/Invalid/);
 await assert.rejects(h.session.getResource('model',999999),/Invalid/);await h.session.disconnect();await assert.rejects(h.session.getResource('model',RESOURCE_TYPE.MDL),/unavailable/);
});

test('unsupported envelopes and malformed wire messages remain observable',async()=>{
 const h=harness({decodeMessage:m=>{if(m.invalid)throw new Error('not exposed');return m;}});
 await h.deliver({invalid:true,length:9});await h.deliver({kind:'unsupported',major:18,minor:11,length:20});
 assert.deepEqual(h.diagnostics.map(d=>d.code),['network.game-message-invalid','network.game-message-unhandled']);assert.equal(h.events.length,1);await h.session.disconnect();
});

test('original local-server session run admits the caster and preserves authoritative spell state through logout',()=>{
 const report=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-session-v1.json',import.meta.url)));
 assert.equal(report.loginAccepted,true);assert.equal(report.failure,undefined);assert.equal(report.beforeDisconnect.phase,'playing');assert.equal(report.beforeDisconnect.resourcesReady,true);assert.equal(report.beforeDisconnect.characterConfirmed,true);
 assert.equal(report.beforeDisconnect.world.objects,33);assert.equal(report.beforeDisconnect.world.localObjectId,0xffffffff);assert.equal(report.afterDisconnect.closed,true);assert.equal(report.peer.admitted,false);
 const books=Object.values(report.playerState.spellbooks);assert.equal(books.reduce((n,b)=>n+b.known.length,0),43);assert.equal(books.flatMap(b=>Object.values(b.memorized).flat()).filter(Boolean).length,34);
 assert.equal(report.messages.filter(m=>m.kind==='object-updates').every(m=>m.complete),true);assert.equal(report.diagnostics.some(d=>/failed|invalid|record-unhandled/.test(d.code)),false);
 assert.ok(report.packets.some(p=>p.direction==='out'&&p.tag==='BNDM'&&!p.encrypted));assert.ok(report.packets.some(p=>p.tag==='M'&&p.encrypted));
});

test('movement requires the current area and controlled creature; requests never mutate authoritative state',async()=>{
 const h=harness();for(const message of capture.transport.messages)await h.deliver(message);await h.session.areaReady(h.session.areaGeneration);
 const areaId=h.session.world.areaId,actor=h.session.world.registry.get(h.session.world.localObjectId),before=structuredClone(actor),areaGeneration=h.session.areaGeneration;
 await assert.rejects(h.session.walkTo({areaId:areaId+1,areaGeneration,position:[6,2,0]}),/not ready/);
 await assert.rejects(h.session.walkTo({areaId,areaGeneration:areaGeneration-1,position:[6,2,0]}),/not ready/);
 const start=h.sent.length;assert.deepEqual(await h.session.walkTo({areaId,areaGeneration,position:[6,2,0],run:true}),{sequence:1});assert.deepEqual(h.sent.at(-1).slice(0,3),[112,6,1]);assert.equal(h.sent.length,start+1);assert.deepEqual(actor,before);
 h.session.movementSequences.set(actor.id,255);assert.deepEqual(await h.session.walkTo({areaId,areaGeneration,position:[6,3,0],run:false}),{sequence:0});assert.deepEqual(actor,before);
 await h.session.disconnect();await assert.rejects(h.session.walkTo({areaId,areaGeneration,position:[6,3,0]}),/not ready/);
});

test('native interactions reject stale areas and targets and leave all canonical actors unchanged',async()=>{
 const h=harness();for(const message of capture.transport.messages)await h.deliver(message);await h.session.areaReady(h.session.areaGeneration);
 const {world}=h.session,areaId=world.areaId,areaGeneration=h.session.areaGeneration,door=[...world.registry.objects.values()].find(o=>o.objectType===10),npc=[...world.registry.objects.values()].find(o=>o.objectType===5&&o.id!==world.localObjectId),placeable=[...world.registry.objects.values()].find(o=>o.objectType===9);
 const before=structuredClone([...world.registry.objects.values()]);
 for(const [targetId,action,minor] of [[door.id,'door.open',3],[door.id,'door.close',3],[npc.id,'conversation.start',8],[npc.id,'combat.attack',2],[placeable.id,'object.use',11]]){
  assert.deepEqual(await h.session.interact({areaId,areaGeneration,targetId,action}),{sent:true});assert.deepEqual(h.sent.at(-1).slice(0,3),[112,6,minor]);
 }
 assert.deepEqual([...world.registry.objects.values()],before);
 for(const change of [{areaId:areaId+1},{areaGeneration:areaGeneration-1},{targetId:0x80001234},{targetId:npc.id},{action:'spell.fake'}])await assert.rejects(h.session.interact({areaId,areaGeneration,targetId:door.id,action:'door.open',...change}));
 npc.replicationRemoved=true;await assert.rejects(h.session.interact({areaId,areaGeneration,targetId:npc.id,action:'conversation.start'}),/unavailable/);
 await h.session.disconnect();await assert.rejects(h.session.interact({areaId,areaGeneration,targetId:door.id,action:'door.open'}),/not ready/);
});

test('dialog replies echo server-owned choices and entry IDs and reject stale UI selections',async()=>{
 const h=harness();for(const message of capture.transport.messages)await h.deliver(message);await h.session.areaReady(h.session.areaGeneration);
 const areaId=h.session.world.areaId,areaGeneration=h.session.areaGeneration,ownerId=0x80000013,request={areaId,areaGeneration,entryId:32,replyId:0};
 await assert.rejects(h.session.replyDialog(request),/unavailable/);
 await h.deliver({kind:'dialog-entry',ownerId,speakerId:ownerId,text:{text:'server text'}});await h.deliver({kind:'dialog-replies',entryId:32,end:0,secondCount:0,replies:[{id:0,text:{text:'server reply'}}]});
 for(const change of [{entryId:31},{replyId:99},{abort:2},{areaGeneration:areaGeneration-1}])await assert.rejects(h.session.replyDialog({...request,...change}));
 const before=structuredClone([...h.session.world.registry.objects.values()]);assert.deepEqual(await h.session.replyDialog(request),{sent:true});assert.deepEqual(h.sent.at(-1).slice(0,3),[112,20,3]);assert.deepEqual([...h.session.world.registry.objects.values()],before);
 await h.deliver({kind:'dialog-replies',entryId:33,end:1,secondCount:1,replies:[{id:7,text:{text:'end'}}]});await h.session.replyDialog({...request,entryId:33,abort:true,replyId:0xffffffff});
 const p=h.sent.at(-1);assert.equal(new DataView(Uint8Array.from(p).buffer).getUint32(11,true),7);assert.equal(p[15],0);
 await h.deliver({kind:'dialog-close'});await assert.rejects(h.session.replyDialog({...request,entryId:33}),/unavailable/);await h.session.disconnect();
});

test('door transition sends the original targeted waypoint and never changes the area or canonical actor locally',async()=>{
 const h=harness();for(const message of capture.transport.messages)await h.deliver(message);await h.session.areaReady(h.session.areaGeneration);
 const world=h.session.world,areaId=world.areaId,areaGeneration=h.session.areaGeneration,door=[...world.registry.objects.values()].find(o=>o.objectType===10),r={areaId,areaGeneration,targetId:door.id,action:'door.transition'};
 await assert.rejects(h.session.interact(r),/unavailable/);await h.deliver({kind:'object-updates',complete:true,records:[{action:'update',objectType:10,id:door.id,state:{animation:50,hasTransition:1}}]});const before=structuredClone([...world.registry.objects.values()]);
 assert.deepEqual(await h.session.interact(r),{sent:true});assert.deepEqual(h.sent.at(-1).slice(0,3),[112,6,1]);assert.equal(world.areaId,areaId);assert.deepEqual([...world.registry.objects.values()],before);assert.equal(h.session.movementSequences.size,0);
 await h.deliver({...wireMessage('client-area'),area:{...wireMessage('client-area').area,id:areaId+1}});await assert.rejects(h.session.interact(r),/not ready/);await h.session.disconnect();
});

test('inventory window and panel requests require the current controlled PC and never mutate server state',async()=>{
 const h=harness();for(const message of capture.transport.messages)await h.deliver(message);await h.session.areaReady(h.session.areaGeneration);
 const areaId=h.session.world.areaId,areaGeneration=h.session.areaGeneration,r={areaId,areaGeneration},before=structuredClone([...h.session.world.registry.objects]);
 for(const open of [true,false]){assert.deepEqual(await h.session.inventoryWindow({...r,open}),{sent:true});assert.deepEqual(h.sent.at(-1).slice(0,3),[112,13,1]);}
 assert.deepEqual(await h.session.inventoryPanel({...r,panel:3}),{sent:true});assert.deepEqual(h.sent.at(-1).slice(0,3),[112,13,2]);assert.deepEqual([...h.session.world.registry.objects],before);
 for(const change of [{ownerId:0x80000013},{areaId:areaId+1},{areaGeneration:areaGeneration-1},{open:1}])await assert.rejects(h.session.inventoryWindow({...r,open:true,...change}));
 await assert.rejects(h.session.inventoryPanel({...r,panel:256}));await h.session.disconnect();await assert.rejects(h.session.inventoryWindow({...r,open:true}),/not ready/);
});

test('item actions require canonical current PC items and send requests without local equipment or repository mutation',async()=>{
 const h=harness();for(const message of capture.transport.messages)await h.deliver(message);await h.session.areaReady(h.session.areaGeneration);
 const world=h.session.world,areaId=world.areaId,areaGeneration=h.session.areaGeneration,base={areaId,areaGeneration},repository=0x800f0001,equipped=0x800f0002,ground=0x800f0003;
 await h.deliver({kind:'object-updates',complete:true,records:[{action:'inventory',channel:'R',operation:'A',id:repository,x:0,y:0,item:{}},{action:'inventory',channel:'I',operation:'A',id:equipped,slot:16,item:{}},{action:'create',id:ground,objectType:6,state:{}}]});const before=structuredClone([...world.registry.objects]),views=structuredClone(world.inventories);
 for(const [itemId,operation,minor,fields]of [[repository,'equip',1,{slot:16}],[repository,'drop',3,{}],[ground,'pickup',5,{}],[equipped,'unequip',7,{}],[repository,'move',9,{x:2,y:3}],[repository,'toggle',11,{}]]){assert.deepEqual(await h.session.itemAction({...base,itemId,operation,...fields}),{sent:true});assert.deepEqual(h.sent.at(-1).slice(0,3),[112,12,minor]);}
 assert.deepEqual([...world.registry.objects],before);assert.deepEqual(world.inventories,views);
 for(const change of [{areaGeneration:areaGeneration-1},{areaId:areaId+1},{itemId:0x800f0004},{itemId:world.localObjectId},{slot:3},{slot:0x40000},{operation:'fake'}])await assert.rejects(h.session.itemAction({...base,itemId:repository,operation:'equip',slot:16,...change}));
 await assert.rejects(h.session.itemAction({...base,itemId:ground,operation:'equip',slot:16}));await assert.rejects(h.session.itemAction({...base,itemId:repository,operation:'unequip'}));await assert.rejects(h.session.itemAction({...base,itemId:repository,operation:'pickup'}));
 await h.deliver({kind:'object-updates',complete:true,records:[{action:'delete',id:ground,objectType:6,remove:1}]});await assert.rejects(h.session.itemAction({...base,itemId:ground,operation:'pickup'}));await h.session.disconnect();await assert.rejects(h.session.itemAction({...base,itemId:repository,operation:'drop'}),/not ready/);
});
