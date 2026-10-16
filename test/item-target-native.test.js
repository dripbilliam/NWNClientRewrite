import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {prepareItemTarget,itemCreatureTargetVeto,confirmItemTarget,sendItemUse} from '../src/item_targeting.js';
const oracle=()=>JSON.parse(fs.readFileSync(new URL('../backups/animations/native-item-target-observations.json',import.meta.url)));
const packed=c=>(c.index??0)|((c.variant??255)<<16);
function fixture(c,kind){const calls=[],item={baseItem:50},target={id:c.self?99:100,possessorId:77},p={
 item:id=>{calls.push(['item',id]);return kind==='confirm'?c.targetItem?target:null:c.item===false?null:item;},
 property:(_i,n)=>{calls.push(['property',n]);return c.property===false?null:{type:c.type??15};},
 propertySpell:(_i,n)=>{calls.push(['propertySpell',n]);return 100;},spell:id=>{calls.push(['spell',id>>>0]);return id===100&&c.spell!==false?{id,targetType:c.mask??3,children:Array(c.children??0).fill(201)}:id===201&&!c.childMissing?{id,targetType:c.childMask??9,children:[]}:null;},
 subRadialSpell:(s,n)=>{calls.push(['subRadialSpell',n]);return s.children[n]??-1;},baseInfo:()=>{calls.push(['baseInfo']);return c.base===false?null:{qbBehaviour:c.behavior??0};},
 controlledId:()=>{calls.push(['controlledId']);return 99;},preview:spell=>calls.push(['preview',spell.id]),warning:()=>calls.push(['warning']),
 creature:id=>{calls.push(['creature',id]);return c.targetCreature===false?null:target;},
 player:()=>{calls.push(['player']);return c.actor===false?null:{};},position:o=>o===target&&kind==='confirm'&&!c.targetCreature?[10,20,30]:[40,50,60],
 use:(_o,id,selection,targetId,point)=>calls.push(['use',id,selection>>>0,targetId,point]),clearPreview:n=>calls.push(['clearPreview',n]),clearRange:n=>calls.push(['clearRange',n]),dispose:()=>{calls.push(['dispose'],['free',360]);}};
 return{p,calls};}
test('native item target setup matches property families, selected child, QBBehaviour and modal auto-self gates',()=>{
 for(const row of oracle().activate){const c=row.case,f=fixture(c,'activate'),state=prepareItemTarget(55,packed(c),f.p,c),label=JSON.stringify(c);
  if(!row.reset){assert.equal(state.mode,'unavailable',label);assert.deepEqual(f.calls,row.calls,label);continue;}
  assert.deepEqual(state.targetTypes,row.calls.filter(v=>v[0]==='type').map(v=>v.slice(1)),label);assert.equal(state.flags,row.flags,label);assert.deepEqual(state.point,row.point,label);assert.equal(state.targetId,row.targetId,label);
  assert.equal(state.mode,row.activated?'target':'self',label);assert.deepEqual(f.calls,row.calls.filter(v=>!['type','reset','activate','confirm'].includes(v[0])),label);
 }
});
test('native item creature veto uses the selected variant and controlled identity',()=>{
 for(const row of oracle().veto){const c=row.case,f=fixture(c,'veto');assert.equal(itemCreatureTargetVeto(55,packed(c),c.targetId??100,f.p),row.result,JSON.stringify(c));assert.deepEqual(f.calls,row.calls,JSON.stringify(c));}
});
test('native item confirmation resolves carried target position and disposes after submission',async()=>{
 for(const row of oracle().confirm){const c=row.case,f=fixture(c,'confirm'),state={itemId:55,packed:packed(c),targetId:c.targetId??100,point:[1.25,2.5,3.75]};
  // Creature lookup returns an owner distinct from the carried item.
  const creature=f.p.creature;f.p.creature=id=>{const result=creature(id);return result?{}:null;};f.p.position=o=>o.possessorId===77?[10,20,30]:[40,50,60];
  await confirmItemTarget(state,f.p);assert.deepEqual(f.calls,row.calls,JSON.stringify(c));assert.deepEqual(state.point,row.point,JSON.stringify(c));
 }
});
test('native client item use wrapper narrows property BYTE and preserves signed high-WORD transport argument',async()=>{
 for(const row of oracle().transport){const c=row.case,calls=[];await sendItemUse(55,packed(c),100,[1.25,2.5,3.75],{transport:()=>c.transport===false?null:{},send:(_t,id,index,variant,target,point)=>calls.push(['transport',id,index,variant>>>0,target,point])});assert.deepEqual(calls,row.calls,JSON.stringify(c));}
});
