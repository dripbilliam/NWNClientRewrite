import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {addCastSpellActions,computeSpellRange,waitForCastRound,spellActionPending,loadSpellRanges} from '../src/spell_queue.js';
import {parse2da} from '../src/area.js';
import {faceObjectAction,facePointAction,normalizeNativeFacing} from '../src/facing_actions.js';
import {createObjectAction,setActionParameter} from '../src/object_actions.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-spell-queue-observations.json',import.meta.url)));
for(const mode of ['queue','range','wait'])test(`native spell ${mode} matches untouched original owner`,async()=>{
  for(const row of oracle.rows.filter(r=>r.case.mode===mode)){
    const c=row.case,calls=[],area={id:88},otherArea={id:89},actor={id:99,nativeField771:c.activity??0,nativeEquipmentLock97c:c.override??0,
      nativeSpellOverride9e8:c.overrideId??1,nativeSpellOverride9ec:2,nativeSpellOverride9f0:3,nativeFieldEc:c.commandable??1,
      spellActionTargetId:123,nativeTarget740:456,position:c.position??[0,0,0],combatRound:{started:c.started??0}},
      target={id:100,objectType:c.targetType??5,position:c.targetPosition??[2,0,0]},point=[...(c.point??[2,0,0])];
    const p={feedback:(_o,id)=>calls.push(['feedback',id]),abilityReady:()=>{calls.push(['ability']);return c.ability??1;},
      uses:(_o,id,index,domain,meta)=>{calls.push(['uses',id,index,domain,meta]);return c.uses??1;},
      object:id=>id===100&&c.targetExists!==false?target:null,dm:()=>c.dm??0,asCreature:o=>o.objectType===5?o:null,
      visibility:()=>c.visible===false?null:c.visibilityFlags??3,area:o=>o===actor?c.actorArea===false?null:area:c.sameArea===false?c.targetArea===false?null:otherArea:area,
      position:o=>o.position,possessor:()=>c.possessor??99,spell:()=>c.spellExists===false?null:{},range:(_o,_s,id)=>{calls.push(['range',id]);return c.range??3;},
      queue:(_o,id,group,params,front)=>calls.push(['queue',front?'front':'tail',id,group,params.map(v=>[v.type,v.value>>>0])]),
      move:(_o,...args)=>calls.push(['move',args[0],...args[1],...args.slice(2)]),setLock:(_o,id)=>calls.push(['lock',id]),
      ranges:c.ranges??[1,2,3,4,5],personalSpace:o=>o===actor?c.space??.5:c.targetSpace??.5,
      creature:id=>id===100&&c.targetExists!==false&&(c.targetType??5)===5?target:null,
      dead:()=>{calls.push(['dead']);return c.dead??0;},dying:()=>{calls.push(['dying']);return c.dying??0;},spellPending:()=>{calls.push(['pending']);return c.pending??0;}};
    let result;
    if(mode==='queue')result=await addCastSpellActions(actor,{spellId:1,classIndex:c.class??0,domainLevel:c.domain??0,metamagic:c.meta??0,spontaneous:c.spontaneous??0,
      position:point,targetId:c.target??100,location:c.location??0,front:c.front??0,cheat:c.cheat??0,path:c.path??0,instant:c.instant??0,featId:c.feat??-1,casterLevel:c.casterLevel??255},p);
    if(mode==='range')result=computeSpellRange(actor,c.text,c.target??100,p);
    if(mode==='wait')result=await waitForCastRound(actor,p);
    const label=JSON.stringify(c);assert.equal(result,row.result,label);assert.deepEqual(calls,row.calls,label);
    if(mode==='queue'){assert.equal(actor.spellActionTargetId,row.target73c,label);assert.equal(actor.nativeTarget740,row.target740,label);assert.deepEqual(point,row.point,label);}
  }
});
test('range cache uses physical rows and rejects missing whole table; round gate scans every due spell',()=>{
  const warnings=[],ranges=parse2da('2DA V2.0\n\nPrimaryRange\n9 1\n8 ****\n7 3\n6 4\n5 5');
  assert.deepEqual(loadSpellRanges({ranges},{warning:m=>warnings.push(m)}),[1,0,3,4,5]);assert.equal(warnings.length,1);assert.throws(()=>loadSpellRanges({}),/unavailable/);
  const r={timer:30,actions:[{time:0,nativeActionType:1},{time:31,nativeActionType:2}]};assert.equal(spellActionPending(r),0);r.actions[1].time=30;assert.equal(spellActionPending(r),1);
});
for(const mode of ['faceObject','facePoint'])test(`native ${mode} follows original plane, area and life gates`,async()=>{
  for(const row of oracle.rows.filter(r=>r.case.mode===mode)){
    const c=row.case,calls=[],actor={position:c.position??[0,0,0]},target={objectType:c.targetType??5,position:c.targetPosition??[2,0,0]},area={},other={};
    const node=createObjectAction(mode==='faceObject'?19:49,0);
    if(mode==='faceObject')setActionParameter(node,0,3,100);
    else(c.point??[2,0,0]).forEach((v,i)=>{const data=new DataView(new ArrayBuffer(4));data.setFloat32(0,v,true);setActionParameter(node,i,2,data.getInt32(0,true));});
    const p={dead:()=>{calls.push(['dead']);return c.dead??0;},dying:()=>{calls.push(['dying']);return c.dying??0;},object:()=>c.targetExists===false?null:target,
      area:o=>o===actor?c.actorArea===false?null:area:c.sameArea===false?c.targetArea===false?null:other:area,
      position:o=>o.position,triggerPoint:()=>c.triggerPoint??[3,4,5],
      normalize:v=>{calls.push(['normalize',...v]);return normalizeNativeFacing(v);},orientation:(_o,v)=>calls.push(['orientation',...v])};
    assert.equal(await(mode==='faceObject'?faceObjectAction:facePointAction)(actor,node,p),row.result,JSON.stringify(c));
    assert.deepEqual(JSON.parse(JSON.stringify(calls)),row.calls,JSON.stringify(c));
  }
});
