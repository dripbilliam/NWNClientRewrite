import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {learnScroll,selectLearnScroll,receiveLearnScrollInput,receiveLearnScrollReply} from '../src/scroll_learning.js';
import {ModuleSession} from '../src/module_session.js';
const oracle=()=>JSON.parse(fs.readFileSync(new URL('../backups/animations/native-scroll-learning-observations.json',import.meta.url)));
function fixture(c){
 const calls=[],actor={id:10},item={baseItem:c.baseItem??75,possessorId:30,stackSize:c.stackSize??2,nativeItemPending240:7},owner={objectType:c.ownerType??5,possessorId:c.bagOwner??10},repo={},spell={id:c.spellId??100},
  classes=c.classes??[{learn:c.canLearn??1,level:c.level??2,gain:c.gain??1,ability:c.ability??1,school:c.school??0,known:c.known??[]}],known=classes.map(r=>[...r.known??[]]);
 const p={item:id=>{calls.push(['item',id]);return c.missingItem?null:item;},activeProperty:(_i,n)=>{calls.push(['activeProperty',n]);return c.missingProperty?null:{subtype:(c.subtype??77)&65535};},
  propertySpell:prop=>{calls.push(['table','SpellIndex',prop.subtype]);return c.spellId??100;},spell:id=>{calls.push(['spell',id]);return c.missingSpell?null:spell;},
  object:id=>{calls.push(['owner',id]);return c.missingOwner?null:owner;},asCreature:o=>{calls.push(['asCreature']);return o;},asItem:o=>{calls.push(['asItem']);return o;},repository:()=>repo,
  contains:(r,_i,n)=>{calls.push(['contains',Boolean(r),n]);return c.contains??1;},classCount:()=>classes.length,classType:(_o,n)=>n,canLearn:id=>classes[id].learn??1,
  spellLevel:(_s,id)=>{calls.push(['level',id]);return classes[id].level??2;},spellGain:(_o,n,l)=>{calls.push(['gain',n,l]);return classes[n].gain??1;},
  minimumAbility:(_o,n,l)=>{calls.push(['ability',n,l]);return classes[n].ability??1;},classSchool:(_o,n)=>{calls.push(['school',n]);return classes[n].school??0;},
  opposition:school=>{calls.push(['table','Opposition',school]);return{status:c.oppositionStatus??1,value:c.opposition??2};},spellSchool:()=>c.spellSchool??2,
  knownCount:(_o,n,l)=>{calls.push(['knownCount',n,l]);return known[n].length;},known:(_o,n,l,index)=>{calls.push(['known',n,l,index]);return known[n][index];},
  addKnown:(_o,n,id)=>{calls.push(['addKnown',n,id]);known[n].push(id);},removeItem:(_o,_i,...args)=>{calls.push(['remove',...args]);return c.removeResult??1;},destroyItem:(_i,flag)=>calls.push(['destroyItem',flag]),
  feedbackData:()=>({}),feedbackInteger:(d,n,value)=>{calls.push(['feedbackInteger',n,value>>>0]);d.value=value>>>0;},feedback:(_o,code,data)=>calls.push(['feedback',code,data?.value??null]),
  transport:()=>{calls.push(['transport']);return c.missingTransport?null:{};},send:(_t,id)=>calls.push(['send',id])};
 return{actor,item,p,calls,known};
}
test('LearnScroll matches full original gates, multiclass duplicate/add order, uint widths, consumption and feedback',async()=>{
 for(const row of oracle().learn){const f=fixture(row.case),result=await learnScroll(f.actor,20,f.p);assert.deepEqual({result,calls:f.calls,known:f.known,stackSize:f.item.stackSize},{result:row.result,calls:row.calls,known:row.known,stackSize:row.stackSize},JSON.stringify(row.case));}
});
test('item menu learning sets pending before independent transport lookup',async()=>{
 for(const row of oracle().menu){const f=fixture(row.case);await selectLearnScroll(20,f.p);assert.deepEqual(f.calls,row.calls,JSON.stringify(row.case));assert.equal(f.item.nativeItemPending240,row.pending);}
});
test('inventory input13 preserves decode guards and reply14 even when learning is rejected',async()=>{
 for(const row of oracle().input){const c=row.case,calls=[];let index=0;const p={overflow:()=>{const value=c.overflows[Math.min(index++,c.overflows.length-1)];calls.push(['overflow',value]);return value;},underflow:()=>{calls.push(['underflow',c.underflow]);return c.underflow;},
  readObjectId:()=>{calls.push(['readObject']);return 20;},message:()=>{calls.push(['message']);return{};},clientObject:()=>{calls.push(['clientObject']);return{};},asCreature:()=>{calls.push(['asCreature']);return c.missingCreature?null:{};},
  learn:(_o,id)=>{calls.push(['learn',id]);return c.learnResult;},clientId:()=>123,reply:(_m,...args)=>calls.push(['reply',...args])};
  assert.equal(await receiveLearnScrollInput(p),row.result,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));
 }
});
test('inventory reply14 refreshes and releases pending state after native lookup/decode guards',()=>{
 for(const row of oracle().reply){const c=row.case,calls=[],item={nativeItemPending240:7};let index=0;
  const p={readObjectId:()=>{calls.push(['readObject']);return 20;},readBool:()=>{calls.push(['readBool']);return c.alternate;},inventory:()=>{calls.push(['inventory']);return{};},controlled:()=>calls.push(['controlled']),alternateInventory:()=>{calls.push(['alternateInventory']);return{};},inventoryOwner:()=>10,creature:id=>calls.push(['creature',id]),repositoryUI:()=>true,
   overflow:()=>{const value=c.overflows[Math.min(index++,c.overflows.length-1)];calls.push(['overflow',value]);return value;},underflow:()=>{calls.push(['underflow',c.underflow]);return c.underflow;},objectArray:()=>{calls.push(['objectArray']);return !c.missingArray;},object:id=>{calls.push(['object',id]);return c.missingItem?null:item;},asItem:()=>{calls.push(['asItem']);return c.wrongType?null:item;},refreshItem:()=>calls.push(['refreshItem'])};
  assert.equal(receiveLearnScrollReply(p),row.result,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.equal(item.nativeItemPending240,row.pending,JSON.stringify(c));
 }
});
test('queued local learning cannot cross control/area/session cancellation or strand a pending item',async()=>{
 for(const change of ['control','area','cancel']){
  const s=new ModuleSession(null),actor=s.register('creature','actor',{}),other=s.register('creature','other',{}),item=s.register('item','item',{});s.player=actor;actor.areaId=1;item.nativeItemPending240=1;
  s.items.inputLearn=()=>assert.fail('Discarded input reached authority');
  const result=s.queuePlayerLearnScroll({actorId:actor.id,areaId:actor.areaId,itemId:item.id});
  if(change==='control')s.player=other;else if(change==='area')actor.areaId=2;else s.cancelPendingPlayerInputs();
  await s.drainPlayerInputs();assert.equal(await result,0);assert.equal(item.nativeItemPending240,0);
 }
});
