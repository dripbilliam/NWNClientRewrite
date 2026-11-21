import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {broadcastSpellData,spellReleaseData,releaseSpellProjectile} from '../src/spell_release_presentation.js';
import {castSpellAndImpact} from '../src/spell_cast_impact.js';
import {ModuleSession} from '../src/module_session.js';
const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-spell-release-presentation-observations.json',import.meta.url))),invalid=0x7f000000,f=Math.fround;
const message=d=>({objects:Object.fromEntries(d.objects.map((v,i)=>[String(i),v>>>0])),integers:Object.fromEntries(d.integers.map((v,i)=>[String(i),v>>>0]))});
function fixture(c,calls){
 const render=v=>[f(v[0]),f(v[2]),f(-v[1])],actor={id:99,objectType:c.actorType??5,areaId:88,position:render([0,0,0]),animationState:c.animation??0,orientation:[1.25,-.5,2],nativeSpellPoint208:[7,8,9],nativeSpellProjectileTime220:150,nativeSpellImpact224:0,nativeSpellFeat23c:65535};
 const objects=new Map([[99,actor],...[100,101,102,103].map(id=>[id,{id,objectType:5,position:render(id<102?c.position??[30,0,0]:[1,2,3]),masterId:c.master??99}])]),area={id:88,objectType:4},items=new Map([[200,{id:200,ownerId:c.owner??99,baseItem:c.base??24}],[201,{id:201,ownerId:c.containerOwner??99,baseItem:c.base??24}]]);
 const p={object:id=>{calls.push(['object',id]);return c.areaObject===false?null:area;},asArea:()=>c.areaCast===false?null:area,asCreature:o=>o.objectType===5?o:null,
  creature:id=>{calls.push(['creature',id]);return id===99&&actor.objectType!==5||id===103&&c.targetExists===false?null:objects.get(id);},
  item:id=>{calls.push(['item',id]);return id===200&&c.itemMissing?null:items.get(id);},
  dm:o=>{calls.push(['dm',o.id]);return o.id===99?c.casterDM??0:c.ownerDM??0;},area:()=>{calls.push(['area']);return c.area===false?null:area;},ids:()=>c.ids??[100,999,101],
  visibility:(o,id)=>{calls.push(['node',o.id,id]);return c.visibility===undefined?1:c.visibility;},client:id=>{calls.push(['client',id]);return c.clients===false?null:{id};},
  identified:(_o,id)=>{calls.push(['identified',id]);return c.identified??1;},send:(cl,type,data)=>calls.push(['send',cl.id,type,message(data)]),
  position:o=>[o.position[0],-o.position[2],o.position[1]],equipped:(_o,item)=>{calls.push(['equipped',item.id]);return c.equipped??0;},repository:(_o,item,n)=>{calls.push(['repository',item.id,n]);return c.repository??0;},
  broadcastProjectile:(_o,data)=>{const {from,...rest}=data;calls.push(['projectile',{...rest,from_:from}]);}};
 return{actor,area,p};
}

test('release broadcasts match original recipient gates, payload resets, identification and item/associate/container ownership',async()=>{
 for(const row of capture.rows.filter(r=>r.case.mode==='broadcast')){
  const c=row.case,calls=[],{actor,p}=fixture(c,calls),data={objects:[99,c.item??invalid],integers:[1,11,12,13]};
  await broadcastSpellData(actor,{},data,p);const label=JSON.stringify(c);assert.deepEqual(calls,row.calls,label);assert.deepEqual(message(data),row.message,label);
 }
});

test('ordinary release matches original source IDs, float projectile origins/endpoints, owned-item suppression and event area',async()=>{
 for(const row of capture.rows.filter(r=>r.case.mode==='release')){
  const c=row.case,calls=[],{actor,p}=fixture(c,calls),spell={id:1,hasProjectile:c.hasProjectile??1,impactScript:'impact'};
  await castSpellAndImpact(actor,1,[1.25,-2,3],c.target??103,0,c.item??invalid,0,0,c.path??0,c.instant??0,{spell:()=>spell,area:p.area,
   broadcast:(o,s,itemId,targetId)=>calls.push(['broadcast',message(spellReleaseData(o,s,itemId,targetId,p))]),
   projectile:(o,s,targetId,path)=>releaseSpellProjectile(o,s,targetId,path,p),
   enqueue:(_event,_caller,_target,_delay,data)=>{const {script,...payload}=data;assert.equal(script,'impact');calls.push(['event',payload]);}});
  assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.equal(actor.nativeSpellImpact224,row.impact,JSON.stringify(c));
 }
 assert.equal(capture.rows.length,3922);
});

test('canonical creature construction preserves original seen/heard self node and empty identified-observer list',()=>{
 const rows=capture.rows.filter(r=>r.case.mode.startsWith('ctor'));assert.equal(rows.length,2);
 assert.deepEqual(rows.find(r=>r.case.mode==='ctorSelf').calls,[['selfNode',99,1,1,0,0]]);assert.equal(rows.find(r=>r.case.mode==='ctorCache').identifiedStorage,'00'.repeat(16));
 const s=new ModuleSession(null),actor=s.register('creature','self',{}),cursor=s.registry.nextObjectId[0];assert.equal(actor.perception.get(actor.id),3);assert.deepEqual(actor.nativeSpellIdentified808,[]);assert.equal(s.registry.nextObjectId[0],cursor);
});
