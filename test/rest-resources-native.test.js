import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {readySpellLevel,highestKnownSpellLevel,createSpellClassState} from '../src/spell_book.js';
import {removeRestEffects,clearCasterEffects,restoreCreatureItems,removeDominationEffect} from '../src/rest_resources.js';
import {receiveModuleRestEvent} from '../src/rest.js';
import {restoreActiveProperties} from '../src/item_property_pool.js';
import {NativeIdList} from '../src/native_id_list.js';
const oracle=()=>JSON.parse(fs.readFileSync(new URL('../backups/animations/native-rest-resource-observations.json',import.meta.url)));
const table=rows=>({orderedRows:rows,rows:new Map(rows.map((r,i)=>[i,r]))});
function bookFixture(c){
 const classes=c.classes??[1,0],o={authored:{ClassList:classes.map((_,i)=>({Class:i,bonusSpellSlots:Array(10).fill(c.bonus??0)}))},nativeTalentClasses:classes.map(()=>{
  const state=createSpellClassState();state.perDay.fill(7);state.maximumPerDay.fill(8);state.memorized=Array.from({length:10},()=>Array.from({length:c.count??3},(_,i)=>c.null?null:{id:100+i,ready:c.ready??0,domain:1,metamagic:2}));
  for(const [level,count]of Object.entries(Object.keys(c.known??{}).length?c.known:{3:2}))state.known[Number(level)]=Array(count).fill(100);return state;
 })};return{o,rules:{classes:table(classes.map(m=>({MemorizesSpells:String(m)})))}};
}
test('original ReadySpellLevel refills physical BYTE slots and resets both spontaneous pools using UINT bonus cap',()=>{
 for(const row of oracle().ready){const c=row.case,{o,rules}=bookFixture(c),calls=[];
  readySpellLevel(o,c.level??1,rules,{spellGainWithBonus:(_o,index,level)=>{calls.push(['gain',index,level]);return c.gain??3;}});
  assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.deepEqual(o.nativeTalentClasses.map(s=>({pools:s.memorized.map(p=>p.map(r=>r?.ready??null)),remaining:s.perDay,maximum:s.maximumPerDay})),row.classes,JSON.stringify(c));
  for(const s of o.nativeTalentClasses)for(const pool of s.memorized)for(const r of pool)if(r){assert.equal(r.domain,1);assert.equal(r.metamagic,2);}
 }
});
test('original highest known level uses WORD counts independently of classes and prepared/remaining pools',()=>{
 for(const row of oracle().highest){const {o}=bookFixture(row.case);assert.equal(highestKnownSpellLevel(o),row.result,JSON.stringify(row.case));}
});
function effectsFixture(c,which){
 const calls=[],list=new NativeIdList();for(const id of c.targets??[20,21])list.append(id);
 const o={id:10,masterId:c.masterId??10,nativeCreatedAreaEffects170:list},rows=c.effects??[{type:1,duration:1,subtype:8,creator:10},{type:99,duration:2,subtype:0}],owners=which==='remove'||which==='domination'?[o]:[...new Set(c.targets??[20,21])].map(id=>({id}));
 for(const owner of owners)owner.effects=rows.map((r,i)=>({id:i+1,type:r.type??1,durationType:r.duration??1,subtype:r.subtype??8,creatorId:r.creator??10,integers:[r.value??7]}));
 const p={effects:o=>o.effects,object:id=>{calls.push(['object',id]);return c.missing?null:owners.find(o=>o.id===id);},
  asWorld:o=>{calls.push(['asWorld',o.id]);return c.wrongType?null:o;},asAreaEffect:o=>{calls.push(['asArea',o.id]);return c.areaEffect?o:null;},areaEffectCreator:()=>c.areaCreator??10,
  destroyLater:(o,id)=>calls.push(['destroyLater',o.id,id,11]),remove:(actor,id)=>{calls.push(['remove',actor.id,id]);actor.effects=actor.effects.filter(e=>e.id!==id);if(c.shrink&&actor!==o&&!actor.effects.some(e=>e.creatorId===10))list.remove(actor.id);}};
 return{o,owners,p,calls,list};
}
for(const [key,owner]of [['remove',removeRestEffects],['clear',clearCasterEffects],['domination',removeDominationEffect]])test(`original rest ${key} effects preserves flags, target traversal/removal restarts and delayed area destruction`,async()=>{
 for(const row of oracle()[key]){const f=effectsFixture(row.case,key);
  await owner(f.o,f.p);assert.deepEqual(f.calls,row.calls,JSON.stringify(row.case));assert.deepEqual(f.owners.map(o=>o.effects.map(e=>e.id)),row.remaining,JSON.stringify(row.case));assert.equal(f.list.count,row.targetCount,JSON.stringify(row.case));
 }
});
test('original module rest event35 stores canonical caller and BYTE event history before script12',async()=>{
 for(const row of oracle().event){const c=row.case,module={nativeLastPCRested380:55,nativeLastRestEvent384:7},calls=[];await receiveModuleRestEvent(module,c.caller,{integers:[c.state]},{runEventScript:(_m,...args)=>calls.push(['runEventScript',...args])});assert.deepEqual({pc:module.nativeLastPCRested380,state:module.nativeLastRestEvent384},row.history,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));}
});
test('original bulk item restoration changes cast properties only and preserves charges/stack counters',()=>{
 for(const row of oracle().properties){const c=row.case,item={charges:3,stackSize:2,activeProperties:c.properties.map(r=>({type:r.type??15,costValue:r.cost??8,usesPerDay:r.uses??255,remaining:r.remaining??0}))};
  restoreActiveProperties(item,c.onlyUnset);assert.deepEqual(item.activeProperties.map(p=>({uses:p.usesPerDay,remaining:p.remaining})),row.properties,JSON.stringify(c));assert.equal(item.charges,3);assert.equal(item.stackSize,2);
 }
});
test('original inventory restoration visits 18 equipment masks and carried containers before their own properties',async()=>{
 for(const row of oracle().items){const c=row.case,calls=[],item=id=>({id}),equipment=item(1),bag=item(2),items=new Map([[2,bag],[3,item(3)],[4,item(4)]]),repo=[2,0,3],child=[4],o={},p={
  equipped:(_o,slot)=>{calls.push(['equipped',slot]);return slot===16?equipment:null;},repository:o=>o===bag?child:c.missingRepo?null:repo,
  first:r=>r.length?{at:0}:null,next:(r,n)=>n.at+1<r.length?{at:n.at+1}:null,at:(r,n)=>{const id=r[n.at];calls.push(['at',id]);return items.get(id);},baseInfo:i=>{calls.push(['base',i.id]);return c.missingBase?null:{id:i.id};},container:b=>Number(b.id===2),
  restore:(i,n)=>calls.push(['restore',i.id,n]),update:(i,n)=>calls.push(['update',i.id,n])};
  await restoreCreatureItems(o,p);assert.deepEqual(calls,row.calls,JSON.stringify(c));
 }
});
