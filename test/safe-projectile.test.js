import test from 'node:test';
import assert from 'node:assert/strict';
import {createAttackData} from '../src/combat_attack_data.js';
import {parse2da} from '../src/area.js';
import {receiveSafeProjectile as receive,broadcastSafeProjectile as broadcast} from '../src/safe_projectile.js';
const table=(value='6')=>parse2da(`2DA V2.0\n\nDamageRangedProjectile\n0 ${value}\n1 ****\n2 ****\n3 ****\n4 ****\n5 ****\n6 ****\n7 ****\n8 ****\n9 ****\n10 ****\n11 ****\n12 ****\n`);
test('projectile receiver resolves captured ammunition but uses caller current position and preserves canonical IDs',async()=>{
  const actor={id:1},caller={id:0x80000001,position:[1,2,3]},ammo={id:0x80000002},data=createAttackData(),trace=[];
  data.raw.setUint32(0x8c,ammo.id,true);data.targetId=0x80000003;data.reactionDelay=100;data.result=4;data.deflected=1;
  const p={creature:id=>{assert.equal(id,caller.id);return caller;},item:id=>{assert.equal(id,ammo.id);return ammo;},position:o=>o.position,
    property:(item,type)=>{trace.push(type);return type===17?{PropertyName:17,CostValue:7}:null;},broadcast:(o,d)=>trace.push(d)};
  await receive(actor,caller.id,data,{damagetypes:table()},p);assert.deepEqual(trace.slice(0,2),[16,17]);
  assert.deepEqual(trace.at(-1),{sourceId:caller.id,targetId:0x80000003,from:[1,2,3],to:[0,0,0],duration:100,appearance:2,flags:0,result:4,deflection:13});
});
test('successful projectile table values6/7 suppress visual and failed cells select original legacy fallback',async()=>{
  for(const [value,index,expected] of [['6',0,0],['7',0,0],['264',0,8],['****',4,1],['****',7,3],['****',12,0]]){
    const data=createAttackData();data.raw.setUint32(0x8c,2,true);let appearance;
    await receive({id:1},1,data,{damagetypes:table(value)}, {creature:()=>({}),item:()=>({}),position:()=>[0,0,0],
      property:()=>({PropertyName:16,Subtype:index>2?index+2:index}),broadcast:(o,d)=>appearance=d.appearance});
    assert.equal(appearance,expected);
  }
});
test('invalid caller or unavailable ammo retain native warning/drop branches',async()=>{
  const data=createAttackData(),warnings=[];let lookup=0;
  await receive({},1,data,{}, {creature:()=>null,item:()=>lookup++,warning:m=>warnings.push(m)});assert.equal(lookup,0);
  await receive({},1,data,{}, {creature:()=>({}),item:()=>null,warning:m=>warnings.push(m)});assert.equal(warnings.length,2);
});
test('projectile broadcast keeps live spatial order, actual clients and inclusive endpoint range without faction filters',async()=>{
  const actor={id:1,nativeProjectileRange268:45},objects=[actor,{id:2,position:[45,0,0]},{id:3,position:[100,45,0]},{id:4,position:[0,0,46]},{id:5,position:[0,0,0]}],sent=[];
  const p={creature:id=>objects.find(o=>o.id===id)??null,equippedItem:()=>({}),baseItem:()=>264,area:()=>({}),areaIds:()=>Uint32Array.of(5,4,3,2),
    client:id=>id===5?null:{object:objects.find(o=>o.id===id)},position:o=>o.position,send:(c,d)=>sent.push([c.object.id,d])};
  const data={sourceId:1,targetId:9,from:[0,0,0],to:[100,0,0]};await broadcast(actor,data,p);
  assert.deepEqual(sent.map(([id,d])=>[id,d.baseItem]),[[3,8],[2,8]]);assert.notEqual(sent[0][1],data);
});
