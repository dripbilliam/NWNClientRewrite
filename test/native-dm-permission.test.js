import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {NativeMessageReader,NativeMessageWriter} from '../src/native_message.js';
import {readGameMasterPermission,normalConnectionPermission} from '../src/network_dm_permission.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {NetworkWorld} from '../src/network_world.js';
import {NetworkGameSession} from '../electron/network_game_session.mjs';
import {EventEmitter} from 'node:events';
import {validNativeSkillAdmission,queryNativeSkillAdmission} from '../src/network_skill_admission.js';
import fs from 'node:fs';
const original=JSON.parse(readFileSync(new URL('../godot-client/reports/native-dm-permission-original-v1.json',import.meta.url)));
function body(permission,secondary,parameter){const w=new NativeMessageWriter(1);w.create(32,0xffffffff,1);w.writeBool(permission);w.writeBool(secondary);w.writeInt(parameter);w.setPrefix(Uint8Array.of(80,31,22));return Uint8Array.from(w.getWriteMessage().data).subarray(3);}
function decode(bytes){const errors=[],r=new NativeMessageReader(1,{diagnose:e=>errors.push(e)});if(!r.setReadMessage(bytes,bytes.length,0xffffffff,1))throw Error('Invalid streams');const result=readGameMasterPermission(r);if(r.messageReadOverflow()||r.messageReadUnderflow()||errors.length)throw Error('Invalid permission fields');return result;}
const packet=(permission,secondary,parameter)=>Uint8Array.from([80,31,22,...body(permission,secondary,parameter)]);
const event=(permission=0)=>({kind:'game-master-permission',permission,field114:1,parameter:-2147483648});
const ID=0x80000002,OTHER=0x80000003,AREA=0x80000001;
function updates(w,...records){w.apply({kind:'object-updates',records});}
function create(w,id=ID){updates(w,{action:'create',id,objectType:5,state:{}});}
function player(w,skillFlags,id=ID){updates(w,{action:'player-state',id,objectType:5,state:{skillFlags}});}
test('original complete receiver96 fixtures have exact BOOL BOOL signedINT32 codec',()=>{
 assert.equal(original.success,true);assert.equal(original.cases,96);
 for(const row of original.rows){
  const decoded=decode(body(row.input.permission,row.input.secondary,row.input.parameter));
  assert.deepEqual(decoded,{kind:'game-master-permission',permission:row.input.permission,field114:row.input.secondary,parameter:row.input.parameter});
  assert.deepEqual(decodeServerGameMessage(packet(row.input.permission,row.input.secondary,row.input.parameter)),{...decoded,major:31,minor:22});
  assert.equal(row.connectionPermission,decoded.permission);
  assert.equal(row.override,row.input.actorPresent&&decoded.permission===0?0:row.input.initialOverride);
  assert.equal(row.secondary,row.input.actorPresent?decoded.field114:123);
  assert.deepEqual(row.reads,[['BOOL'],['BOOL'],['INT',32]]);
 }
});
test('reader order is explicit and no control/skill default is invented by decoding',()=>{
 const calls=[],reader={readBool(){calls.push('BOOL');return calls.length===1?0:1;},readInt(){calls.push('INT32');return -2147483648;}};
 const result=readGameMasterPermission(reader);assert.deepEqual(calls,['BOOL','BOOL','INT32']);
 assert.deepEqual(Object.keys(result),['kind','permission','field114','parameter']);assert.equal(Object.hasOwn(result,'actorId'),false);assert.equal(Object.hasOwn(result,'skillOverride'),false);
});
test('owned strict reader rejects empty/truncated streams before publication',()=>{
 const packet=body(0,1,-2147483648);
 for(const size of [0,1,2,3,packet.length-1])assert.throws(()=>decode(packet.slice(0,size)));
 assert.deepEqual(decode(packet),{kind:'game-master-permission',permission:0,field114:1,parameter:-2147483648});
});
test('actual decoder rejects malformed31/22 without default fields',()=>{
 const value=packet(0,1,-2147483648);for(const length of [3,4,5,7,value.length-1])assert.throws(()=>decodeServerGameMessage(value.slice(0,length)));
 assert.equal(decodeServerGameMessage(Uint8Array.from([80,31,21])).kind,'unsupported');
});
test('actual World applies received zero override only to the present controlled creature',()=>{
 const w=new NetworkWorld();w.areaId=AREA;assert.equal(w.gameMasterPermission,null);
 create(w);player(w,0);const actor=w.registry.get(ID);assert.equal(Object.hasOwn(actor.clientSkillAdmission,'override'),false);
 assert.equal(w.apply(decodeServerGameMessage(packet(0,1,-2147483648))),true);
 assert.deepEqual(w.gameMasterPermission,{permission:0,field114:1,parameter:-2147483648,source:'received_game_master_permission_31_22'});
 assert.equal(actor.clientSkillAdmission.override,0);assert.equal(actor.clientSkillAdmission.overrideSource,w.gameMasterPermission.source);assert.equal(validNativeSkillAdmission(actor.clientSkillAdmission),true);
 assert.equal(queryNativeSkillAdmission(actor.clientSkillAdmission,0,14,actor.clientSkillAdmission.override).value,false);
 player(w,8193);updates(w,{action:'inventory-stats',id:ID,objectType:5,state:{skills:[{index:13,value:0,flag:0}]}});assert.equal(actor.clientSkillAdmission.mask,8193);assert.equal(actor.clientSkillAdmission.override,0);
 const before=structuredClone(actor.clientSkillAdmission);w.apply(event(1));assert.deepEqual(actor.clientSkillAdmission,before,'permission true does not invent override1');
 assert.equal(actor.inventoryStats.field114,undefined,'secondary field remains raw permission metadata, not a fabricated stats mirror');
});
test('actual World does not replay a permission event onto a later actor/control/disclosure',()=>{
 const w=new NetworkWorld();w.areaId=AREA;w.apply(event());create(w);player(w,0);const first=w.registry.get(ID);
 assert.equal(Object.hasOwn(first.clientSkillAdmission,'override'),false,'message before actor is not replayed');
 w.apply(event());assert.equal(first.clientSkillAdmission.override,0);
 create(w,OTHER);w.apply({kind:'object-control',major:5,minor:2,playerId:1,objectId:OTHER});player(w,0,OTHER);const second=w.registry.get(OTHER);
 assert.equal(Object.hasOwn(second.clientSkillAdmission,'override'),false,'control switch cannot inherit old actor clear');
 w.apply(event(1));assert.equal(Object.hasOwn(second.clientSkillAdmission,'override'),false,'true only preserves');assert.equal(first.clientSkillAdmission.override,0);
 w.apply(event());assert.equal(second.clientSkillAdmission.override,0);
 updates(w,{action:'delete',id:OTHER,objectType:5,remove:0});assert.equal(second.clientSkillAdmission,null);
 w.apply(event());assert.equal(second.clientSkillAdmission,null,'removed disclosure stays retired');create(w,OTHER);player(w,0,OTHER);assert.equal(Object.hasOwn(second.clientSkillAdmission,'override'),false);
 w.apply(event());assert.equal(second.clientSkillAdmission.override,0);
 w.apply({kind:'client-area',area:{id:0x80000010,mapPins:[],sounds:[],placeableLights:[],staticPlaceables:[],time:{}},position:[0,0,0],facing:0,flag:0});assert.equal(w.gameMasterPermission.permission,0);assert.equal(second.clientSkillAdmission.override,0);
 w.reset();assert.equal(w.gameMasterPermission,null);create(w);player(w,0);assert.equal(Object.hasOwn(w.registry.get(ID).clientSkillAdmission,'override'),false);
});
test('actual World validates all permission fields/cache before either publication',()=>{
 const w=new NetworkWorld();w.areaId=AREA;create(w);player(w,0);w.apply(event());const actor=w.registry.get(ID),before=structuredClone(actor),permission=structuredClone(w.gameMasterPermission);
 for(const change of [{permission:2},{permission:true},{field114:2},{parameter:2147483648},{parameter:0.5}]){assert.throws(()=>w.apply({...event(),...change}));assert.deepEqual(actor,before);assert.deepEqual(w.gameMasterPermission,permission);}
 actor.clientSkillAdmission={version:1};const invalid=structuredClone(actor.clientSkillAdmission);assert.throws(()=>w.apply(event()));assert.deepEqual(actor.clientSkillAdmission,invalid);assert.deepEqual(w.gameMasterPermission,permission);
});
test('actual Session receives typed31/22 without a response packet or DM action',async()=>{
 const peer=new EventEmitter(),sent=[];peer.sendGameMessage=async bytes=>sent.push(bytes);peer.disconnect=async()=>peer.emit('closed');
 const session=new NetworkGameSession({peer,identity:{dispose(){}},build:{build:{number:8193,revision:37,postfix:17},dispose(){}},resources:{},language:0,openModule:async()=>null});session.world.areaId=AREA;create(session.world);player(session.world,0);
 await session.receive(packet(0,1,123));assert.equal(session.world.gameMasterPermission.parameter,123);assert.equal(session.world.registry.get(ID).clientSkillAdmission.override,0);assert.equal(sent.length,0);await session.disconnect();
});
test('host header forwards the canonical received permission view without role inference',()=>{
 const host=fs.readFileSync(new URL('../godot-client/tools/native-session-host.cjs',import.meta.url),'utf8');
 assert.match(host,/ui:\{\.\.\.playerRosterHeader\(session\.world\),guiPanelAccess:/);
});
test('normal16 client initialization follows both complete original connection-start paths',()=>{
 const proof=JSON.parse(readFileSync(new URL('../godot-client/reports/native-connection-permission-start-original-v1.json',import.meta.url)));
 assert.equal(proof.success,true);assert.equal(proof.cases,24);
 for(const row of proof.rows){const view=normalConnectionPermission(row.input.connectionType);if(row.input.connectionType===16){assert.equal(row.permission,0);assert.deepEqual(view,{permission:0,field114:null,parameter:null,source:'native_connection_start_16'});}else assert.equal(view,null,'unsupported app-dependent roles stay unavailable');}
 const first=normalConnectionPermission(16);first.permission=1;assert.equal(normalConnectionPermission(16).permission,0);
 for(const value of [undefined,null,'16',false,32])assert.equal(normalConnectionPermission(value),null);
});
test('Session uses the installed Peer metadata connection type, never a contradictory top-level alias',async()=>{
 for(const options of [{},{connectionType:16},{metadata:{connectionType:16}},{connectionType:32,metadata:{connectionType:16}},{connectionType:16,metadata:{connectionType:32}},{metadata:{connectionType:'16'}},{metadata:{}}]){
  const peer=new EventEmitter();let actualMetadata;peer.connect=async(_identity,{metadata})=>{actualMetadata=metadata;return{build:{number:8193,revision:37,postfix:17}};};peer.sendGameMessage=async()=>{};peer.disconnect=async()=>peer.emit('closed');
  const session=new NetworkGameSession({peer,identity:{dispose(){}},build:{build:{number:8193,revision:37,postfix:17},dispose(){}},resources:{},language:0,openModule:async()=>null});session.world.areaId=AREA;create(session.world);player(session.world,0);const actor=session.world.registry.get(ID);
  await session.connect(options);assert.equal(actualMetadata,options.metadata,'the same metadata owner reaches the actual peer boundary');
  if(options.metadata?.connectionType===16)assert.deepEqual(session.world.gameMasterPermission,{permission:0,field114:null,parameter:null,source:'native_connection_start_16'});else assert.equal(session.world.gameMasterPermission,null);
  assert.equal(Object.hasOwn(actor.clientSkillAdmission,'override'),false,'connection permission initialization is not a stats clear');
  await session.receive(packet(1,1,123));assert.equal(session.world.gameMasterPermission.source,'received_game_master_permission_31_22');assert.equal(session.world.gameMasterPermission.permission,1);assert.equal(Object.hasOwn(actor.clientSkillAdmission,'override'),false);
  await session.receive(packet(0,1,123));assert.equal(actor.clientSkillAdmission.override,0);
  session.world.reset();assert.equal(session.world.gameMasterPermission,null);create(session.world);player(session.world,0);assert.equal(Object.hasOwn(session.world.registry.get(ID).clientSkillAdmission,'override'),false);
  await session.disconnect();
 }
});
