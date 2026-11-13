import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {NATIVE_SKILL_SOURCE as source,validNativeSkillAdmission as valid,mergeNativeSkillAdmission as merge,queryNativeSkillAdmission as query} from '../src/network_skill_admission.js';
import {NetworkWorld} from '../src/network_world.js';
const original=JSON.parse(readFileSync(new URL('../godot-client/reports/native-skill-admission-original-v1.json',import.meta.url)));

test('complete original getter body: 1320 scalar cache decisions',()=>{
 assert.equal(original.success,true);assert.equal(original.getterCases,1320);
 for(const row of original.getter){
  const view=merge(null,{skillFlags:row.mask},'player');
  const result=query(view,row.skill,row.count,row.override);
  assert.equal(result.available,true,JSON.stringify(row));
  assert.equal(result.value,row.result!==0,JSON.stringify(row));
  assert.equal(result.nativeResult,row.result,JSON.stringify(row));
 }
});
test('complete original InventoryStats body: 270 ordered true-only merges',()=>{
 assert.equal(original.inventoryCases,270);
 for(const row of original.inventory){
  const view=merge(merge(null,{skillFlags:row.initial},'player'),{skills:row.incoming},'inventory');
  assert.equal(view.mask,row.result,JSON.stringify(row));
  assert.equal(view.knownMask,0xffffffff);assert.equal(view.inventoryUpdateSeen,true);
 }
});
test('ordered sources preserve replacement after sticky inventory evidence',()=>{
 const raw={skills:[{index:13,value:50,flag:1}]};
 const a=merge(null,raw,'inventory');
 const b=merge(a,{skillFlags:0},'player');
 const c=merge(b,{skills:[{index:13,value:-128,flag:0}]},'inventory');
 assert.equal(a.mask,8192);assert.equal(a.knownMask,8192);
 assert.equal(c.mask,0);assert.equal(query(c,13,14,0).value,false);
 assert.equal(query(a,13,14).value,true);
 assert.equal(query(a,0,14,0).available,false);
 assert.equal(query(c,13,14).available,false);
 assert.equal(query(null,0,0).nativeResult,0);
 assert.equal(query(null,0,14,-1).nativeResult,1);
 assert.deepEqual(raw,{skills:[{index:13,value:50,flag:1}]});
 assert.notEqual(a,b);assert.notEqual(b,c);c.mask=8192;assert.equal(b.mask,0);
});
test('unknowns, signed override, widths and aliasing are explicit',()=>{
 const unknown=merge(null,{},'player');
 assert.equal(unknown.mask,null);assert.equal(unknown.knownMask,0);
 for(const key of ['playerUpdateSeen','inventoryUpdateSeen'])assert.equal(unknown[key],false);
 assert.equal(query(unknown,13,14,0).available,false);
 assert.equal(query(unknown,13,14,null).available,false);
 assert.equal(query(unknown,13,null,1).available,false);
 assert.equal(query(unknown,13,14,'yes').available,false);
 assert.equal(query(unknown,13,14,2147483648).available,false);
 assert.equal(query(unknown,-1,14,1).available,false);
 assert.equal(query(unknown,65536,14,1).available,false);
 assert.equal(query(unknown,13,256,1).available,false);
 const aliases=merge(null,{skills:[{index:32,flag:true},{index:63,flag:true}]},'inventory');
 assert.equal(aliases.mask,0x80000001);assert.equal(query(aliases,0,255,0).value,true);assert.equal(query(aliases,31,255,0).nativeResult,0x80000000);
 const falseOnly=merge(null,{skills:[{index:0,flag:false}]},'inventory');assert.equal(falseOnly.mask,null);
 for(const bits of [-1,4294967296,0.5,undefined,null,'1'])assert.throws(()=>merge(null,{skillFlags:bits},'player'));
 for(const row of [{index:255,flag:1},{index:-1,flag:1},{index:13,flag:2},{index:1.5,flag:1},null])assert.throws(()=>merge(null,{skills:[row]},'inventory'));
 assert.throws(()=>merge(null,{skills:null},'inventory'));
 assert.throws(()=>merge(null,{},'rank'));
 assert.throws(()=>merge({version:1,source,knownMask:1,mask:2,playerUpdateSeen:false,inventoryUpdateSeen:false},{},'player'));
 assert.equal(valid({...unknown,mask:0}),false);assert.equal(valid(unknown),true);
});
const ID=0x80000002,OTHER=0x80000003,AREA=0x80000001;
const create=(id=ID)=>({action:'create',id,objectType:5,state:{}});
const player=(skillFlags,id=ID)=>({action:'player-state',id,objectType:5,state:{skillFlags}});
const inventory=(skills,id=ID)=>({action:'inventory-stats',id,objectType:5,state:{skills}});
const removed=(id=ID)=>({action:'delete',id,objectType:5,remove:0});
const apply=(world,...records)=>world.apply({kind:'object-updates',records});
function world(){const value=new NetworkWorld({onDiagnostic:()=>{}});value.areaId=AREA;apply(value,create());return value;}
test('actual World consumes both sources in wire order, before sticky raw array merge',()=>{
 const w=world(),row={index:13,value:3,flag:1};apply(w,inventory([row]));
 const proxy=w.registry.get(ID);assert.equal(proxy.clientSkillAdmission.mask,8192);assert.equal(proxy.clientSkillAdmission.knownMask,8192);
 apply(w,player(0),inventory([{index:13,value:-1,flag:0}]));
 assert.equal(proxy.clientSkillAdmission.mask,0);assert.equal(proxy.inventoryStats.skills[0].flag,1,'raw historical owner is preserved independently');
 assert.equal(query(proxy.clientSkillAdmission,13,14,0).value,false);
 assert.equal(proxy.playerState.skillFlags,0);assert.deepEqual(row,{index:13,value:3,flag:1});
 apply(w,inventory([{index:0,value:127,flag:1}]),player(0));assert.equal(proxy.clientSkillAdmission.mask,0);
 apply(w,player(0),inventory([{index:0,value:-128,flag:1}]));assert.equal(proxy.clientSkillAdmission.mask,1);
 const before=structuredClone(proxy.clientSkillAdmission);apply(w,{action:'update',id:ID,objectType:5,state:{position:[1,2,3]}});assert.deepEqual(proxy.clientSkillAdmission,before);
});
test('actual World D+A retires old compact disclosure without reusing sticky arrays',()=>{
 const w=world();apply(w,player(8193),inventory([{index:13,value:10,flag:1}]));const proxy=w.registry.get(ID),token=w.entityDisclosures.token(proxy);
 apply(w,create());assert.equal(proxy.clientSkillAdmission.mask,8193);assert.equal(w.entityDisclosures.token(proxy),token,'repeated A alone retains same disclosure');
 apply(w,removed());assert.equal(proxy.clientSkillAdmission,null);assert.equal(proxy.replicationRemoved,true);
 apply(w,create(),inventory([{index:13,value:1,flag:0}]));assert.equal(w.registry.get(ID),proxy);assert.equal(proxy.clientSkillAdmission.mask,null);assert.equal(proxy.clientSkillAdmission.knownMask,0);
 assert.equal(proxy.inventoryStats.skills[0].flag,1,'old raw fields cannot seed the new projection');
 assert.notEqual(w.entityDisclosures.token(proxy),token);
 apply(w,player(0xffffffff),removed(),create(),inventory([{index:0,value:1,flag:1}]));assert.equal(proxy.clientSkillAdmission.mask,1);assert.equal(proxy.clientSkillAdmission.knownMask,1);
 apply(w,removed(),create());assert.equal(proxy.clientSkillAdmission,null,'D+A with no new skill disclosure stays missing');
});
test('actual World rejects malformed incoming updates atomically, including staged retirement',()=>{
 const w=world();apply(w,player(8193));const proxy=w.registry.get(ID),before=structuredClone(proxy),token=w.entityDisclosures.token(proxy);
 assert.throws(()=>apply(w,removed(),create(),player(0),inventory([{index:13,value:1,flag:2}])));
 assert.equal(w.registry.get(ID),proxy);assert.deepEqual(proxy,before);assert.equal(w.entityDisclosures.token(proxy),token);
 assert.throws(()=>apply(w,player(1),create(1)));
 assert.deepEqual(proxy,before);assert.equal(w.localObjectId,ID);
 assert.throws(()=>apply(w,player(-1)));assert.deepEqual(proxy,before);
});
test('actual World retains surviving caches over area/control changes and resets on reconnect',()=>{
 const w=world();apply(w,player(8193),create(OTHER),inventory([{index:0,value:4,flag:1}],OTHER));
 const first=w.registry.get(ID),second=w.registry.get(OTHER),a=structuredClone(first.clientSkillAdmission),b=structuredClone(second.clientSkillAdmission);
 w.apply({kind:'object-control',major:5,minor:2,playerId:1,objectId:OTHER});assert.equal(w.localObjectId,OTHER);
 w.apply({kind:'client-area',area:{id:0x80000010,mapPins:[],sounds:[],placeableLights:[],staticPlaceables:[],time:{}},position:[1,2,3],facing:0,loadingScreen:0,flag:0});
 assert.equal(w.registry.get(ID),first);assert.equal(w.registry.get(OTHER),second);assert.deepEqual(first.clientSkillAdmission,a);assert.deepEqual(second.clientSkillAdmission,b);
 assert.equal(second.areaId,0x80000010);w.reset();assert.equal(w.registry.get(ID),undefined);apply(w,create(),inventory([{index:13,value:4,flag:0}]));assert.equal(w.registry.get(ID).clientSkillAdmission.mask,null);
});
