import test from 'node:test';
import assert from 'node:assert/strict';
import {EventEmitter} from 'node:events';
import {NetworkGameSession} from '../electron/network_game_session.mjs';
import {NetworkWorld} from '../src/network_world.js';
import {characterSheetRequest,skillDescriptionGuiRequest,featDescriptionGuiRequest} from '../src/network_hud_input.js';
import {guiPanelAttemptRequest} from '../src/network_gui_panel_access.js';

const BUILD={number:8193,revision:37,postfix:0};
function harness(){
 const peer=new EventEmitter(),sent=[];peer.sendGameMessage=async bytes=>sent.push(Uint8Array.from(bytes));peer.disconnect=async()=>peer.emit('closed');
 const s=new NetworkGameSession({peer,identity:{dispose(){}},build:{build:BUILD,dispose(){}},resources:{},language:0,openModule:async()=>null});
 const actor={id:0xffffffce,objectType:5,areaId:0x80000001,inventoryStats:{skills:[{index:7,value:0,flag:1}],fields118:[51],fields128:[]}};
 const target={id:0x80000044,objectType:5,areaId:actor.areaId,replicated:{master:actor.id,field908:1},inventoryStats:{skills:[{index:9,value:-1,flag:1},{index:10,value:0,flag:0}],fields118:[3],fields128:[4]},playerState:{feats:[99],bonusFeats:[98]}};
 s.phase='playing';s.areaReadySent=true;s.areaGeneration=2;s.world.areaId=actor.areaId;s.world.localObjectId=actor.id;
 s.world.gameMasterPermission={permission:0,field114:null,parameter:null,source:'native_connection_start_16'};
 for(const object of [actor,target])s.world.registry.addObjectAtPos(object.id,object);
 const request={areaId:actor.areaId,areaGeneration:2,actorId:actor.id,targetId:target.id,recordActorLifetime:s.world.entityDisclosures.token(actor),recordTargetLifetime:s.world.entityDisclosures.token(target),panel:'character',open:true,page:0};
 return{s,world:s.world,peer,sent,actor,target,request};
}
const bytes=value=>Uint8Array.from(value);

test('legacy self record/skill/feat packets retain exact bytes without foreign permission or tokens',async()=>{
 const h=harness();h.s.world.gameMasterPermission=null;
 const base={areaId:h.actor.areaId,areaGeneration:2,actorId:h.actor.id};
 for(const page of [0,1,2]){await h.s.hudPanel({...base,panel:'character',open:true,page});assert.deepEqual(h.sent.at(-1),characterSheetRequest({targetId:h.actor.id,page}));}
 await h.s.hudPanel({...base,panel:'character',open:false,page:2});assert.deepEqual(h.sent.at(-1),characterSheetRequest({targetId:h.actor.id,page:-1}));
 await h.s.hudPanel({...base,panel:'skill',open:true,targetId:h.actor.id,skillId:7});assert.deepEqual(h.sent.at(-1),skillDescriptionGuiRequest({skillId:7,targetId:h.actor.id,includePosition:true}));
 await h.s.hudPanel({...base,panel:'feat',open:true,targetId:h.actor.id,featId:51});assert.deepEqual(h.sent.at(-1),featDescriptionGuiRequest({featId:51,targetId:h.actor.id,includePosition:true}));
 await h.s.disconnect();
});

test('actual Session targets disclosed owned associate pages and signed close without actor mutation',async()=>{
 const h=harness(),before=structuredClone([h.actor,h.target]);
 for(const type of [1,2,3,4]){h.target.replicated.field908=type;for(const page of [0,1,2]){await h.s.hudPanel({...h.request,page});assert.deepEqual(h.sent.at(-1),characterSheetRequest({targetId:h.target.id,page}));}}
 await h.s.hudPanel({...h.request,open:false});assert.deepEqual(h.sent.at(-1),characterSheetRequest({targetId:h.target.id,page:-1}));
 for(const page of [-1,3,1.5,'1'])await assert.rejects(h.s.hudPanel({...h.request,page}));
 h.target.replicated.field908=1;assert.deepEqual([h.actor,h.target],before);await h.s.disconnect();
});

test('target skill and feat help admit only this target raw rows with empty-list precedence',async()=>{
 const h=harness();
 for(const revision of [34,37]){h.s.serverBuild={...BUILD,revision};
  await h.s.hudPanel({...h.request,panel:'skill',skillId:9});assert.deepEqual(h.sent.at(-1),skillDescriptionGuiRequest({skillId:9,targetId:h.target.id,includePosition:revision>=35}));
  for(const featId of [3,4]){await h.s.hudPanel({...h.request,panel:'feat',featId});assert.deepEqual(h.sent.at(-1),featDescriptionGuiRequest({featId,targetId:h.target.id,includePosition:revision>=35}));}
 }
 for(const change of [{panel:'skill',skillId:7},{panel:'skill',skillId:10},{panel:'feat',featId:51},{panel:'feat',featId:99},{panel:'feat',featId:98}])await assert.rejects(h.s.hudPanel({...h.request,...change}));
 h.target.inventoryStats.fields118=[];await assert.rejects(h.s.hudPanel({...h.request,panel:'feat',featId:3}));
 h.target.inventoryStats.fields118=null;await assert.rejects(h.s.hudPanel({...h.request,panel:'feat',featId:99}));
 delete h.target.inventoryStats.fields118;await h.s.hudPanel({...h.request,panel:'feat',featId:99});
 await h.s.disconnect();
});

test('blocked target8 sends repeated exact GUI14 attempts and retires old access revisions/serials',async()=>{
 const h=harness();h.s.world.apply({kind:'gui-panel-disabled',panelId:8,disabled:true,targetId:h.target.id,targetSource:'received'});
 for(const attemptSerial of [1,2]){await h.s.hudPanel({...h.request,panel:'blocked-attempt',guiPanelId:8,accessRevision:1,attemptSerial});assert.deepEqual(h.sent.at(-1),guiPanelAttemptRequest({panelId:8,targetId:h.target.id,includePosition:true}));}
 await assert.rejects(h.s.hudPanel({...h.request,panel:'blocked-attempt',guiPanelId:8,accessRevision:1,attemptSerial:2}));
 h.s.world.apply({kind:'gui-panel-disabled',panelId:8,disabled:false,targetId:h.target.id,targetSource:'received'});
 await assert.rejects(h.s.hudPanel({...h.request,panel:'blocked-attempt',guiPanelId:8,accessRevision:1,attemptSerial:3}));assert.equal(h.sent.length,2);await h.s.disconnect();
});

test('missing/malformed permission, ownership, target and disclosure tokens never produce a packet',async()=>{
 const mutations=[h=>h.s.world.gameMasterPermission=null,h=>h.s.world.gameMasterPermission.permission=1,h=>h.s.world.gameMasterPermission.source='invented',h=>h.s.world.gameMasterPermission.field114=0,
  h=>delete h.target.replicated.master,h=>h.target.replicated.master=42,h=>h.target.replicated.field908=0,h=>h.target.replicated.field908=5,h=>delete h.target.replicated.field908,
  h=>h.target.objectType=6,h=>h.target.areaId=42,h=>h.target.replicationRemoved=true,h=>h.target.destroyed=true,
  h=>delete h.request.recordActorLifetime,h=>delete h.request.recordTargetLifetime,h=>h.request.recordActorLifetime=null,h=>h.request.recordTargetLifetime=0,h=>h.request.recordTargetLifetime='2',h=>h.request.recordTargetLifetime=1.5,
  h=>h.request.areaGeneration=1,h=>h.request.actorId=42,h=>h.request.targetId=0x7f000000];
 for(const mutate of mutations){const h=harness();mutate(h);await assert.rejects(h.s.hudPanel(h.request));assert.equal(h.sent.length,0);assert.equal(h.s.closed,false);await h.s.disconnect();}
 for(const recordTargetLifetime of [undefined,null,0,'1']){const h=harness();await assert.rejects(h.s.hudPanel({...h.request,targetId:h.actor.id,recordTargetLifetime}));assert.equal(h.sent.length,0);await h.s.disconnect();}
 const h=harness();h.s.world.gameMasterPermission={permission:0,field114:1,parameter:-2147483648,source:'received_game_master_permission_31_22'};await h.s.hudPanel(h.request);assert.equal(h.sent.length,1);await h.s.disconnect();
});

test('coalesced disclosure D+A on the same retained proxy rejects previous target scope',async()=>{
 const h=harness(),old=h.request.recordTargetLifetime;
 h.s.world.entityDisclosures.observeAccepted([{action:'delete',id:h.target.id}],h.s.world.registry);
 assert.notEqual(h.s.world.entityDisclosures.token(h.target),old);
 await assert.rejects(h.s.hudPanel(h.request));assert.equal(h.sent.length,0);
 await h.s.hudPanel({...h.request,recordTargetLifetime:h.s.world.entityDisclosures.token(h.target)});assert.equal(h.sent.length,1);await h.s.disconnect();
});

test('after-await foreign scope retirement is nonfatal, sends once and never retries',async()=>{
 const mutations=[h=>h.s.world.registry.delete(h.target.id),h=>h.s.world.entityDisclosures.observeAccepted([{action:'delete',id:h.target.id}],h.s.world.registry),h=>h.target.replicated.master=42,
  h=>h.target.replicationRemoved=true,h=>h.target.destroyed=true,h=>h.s.world.gameMasterPermission.permission=1,h=>h.s.areaGeneration++,h=>h.s.world.localObjectId=h.target.id,
  h=>h.s.world.entityDisclosures.observeAccepted([{action:'delete',id:h.actor.id}],h.s.world.registry),h=>h.s.peer=new EventEmitter(),h=>{
   const world=new NetworkWorld();world.areaId=h.actor.areaId;world.localObjectId=h.actor.id;world.gameMasterPermission=h.world.gameMasterPermission;
   for(const object of [h.actor,h.target]){world.registry.addObjectAtPos(object.id,object);world.entityDisclosures.token(object);}h.s.world=world;
  }];
 for(const mutate of mutations){const h=harness();let release;const gate=new Promise(resolve=>release=resolve);h.peer.sendGameMessage=async value=>{h.sent.push(bytes(value));await gate;};
  const pending=h.s.hudPanel(h.request);await new Promise(resolve=>setImmediate(resolve));mutate(h);release();await assert.rejects(pending);assert.equal(h.sent.length,1);assert.equal(h.s.closed,false);h.s.world=h.world;h.s.peer=h.peer;await h.s.disconnect();}
 for(const [change,mutate] of [[{panel:'skill',skillId:9},h=>h.target.inventoryStats.skills[0].flag=0],[{panel:'feat',featId:3},h=>h.target.inventoryStats.fields118=[]]]){
  const h=harness();let release;const gate=new Promise(resolve=>release=resolve);h.peer.sendGameMessage=async value=>{h.sent.push(bytes(value));await gate;};
  const pending=h.s.hudPanel({...h.request,...change});await new Promise(resolve=>setImmediate(resolve));mutate(h);release();await assert.rejects(pending);assert.equal(h.sent.length,1);assert.equal(h.s.closed,false);await h.s.disconnect();
 }
});
