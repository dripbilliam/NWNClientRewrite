import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {applyLethalDamage,removeTemporaryHitpoints} from '../src/lethal_damage.js';
import {ModuleSession} from '../src/module_session.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-lethal-damage-observations.json',import.meta.url)));
test('lethal damage creates fresh native death19 separately, with exact gib threshold/blood visuals and application order',async()=>{
 assert.ok(data.rows.length>1000);
 for(const row of data.rows){const c=row.case,s=new ModuleSession(null),o={objectType:c.world?9:5,nativeField771:c.state??0},trace=[];s.effects.nextId=101n;
  await applyLethalDamage(o,c.creator??98,c.amount??10,{create:(...a)=>s.effects.create(...a),maximumHP:(_o,flag)=>{trace.push(['maximum',flag]);return c.maximum??20;},currentHP:(_o,flag)=>{trace.push(['current',flag]);return c.current??-11;},blood:()=>{trace.push(['blood',7]);return c.blood??'R';},apply:(_o,e,loading)=>trace.push(['apply',{id:e.id,type:e.type,subtype:e.subtype,durationType:e.durationType,creatorId:e.creatorId,integers:e.integers.slice()},loading,0])},c.loading??0);
  assert.deepEqual(trace,row.trace,JSON.stringify(c));
 }
});
test('complete temporary-HP removal matches original signed subtraction, repeated life queries and deferred death/dying events',async()=>{
 assert.equal(data.temporary.length,272);
 for(const row of data.temporary){const c=row.case,s=new ModuleSession(null),o={id:99,nativeFieldEc:3,temporaryHP:c.temporaryHP??5,nativeField771:c.state??0},trace=[];let dc=0,hc=0;s.effects.nextId=101n;
  const snapshot=e=>({id:e.id,type:e.type,subtype:e.subtype,durationType:e.durationType,creatorId:e.creatorId,integers:e.integers.slice()});
  const result=await removeTemporaryHitpoints(o,c.nullEffect?null:{integers:[c.removeAmount??3]},{asCreature:()=>{trace.push(['asCreature']);return c.creature===false?null:o;},dying:()=>{trace.push(['dying']);return(c.dying??[0,0])[Math.min(dc++,1)];},dead:()=>{trace.push(['dead']);return(c.dead??[0,1])[Math.min(hc++,1)];},temporaryHP:a=>a.temporaryHP,setTemporaryHP:(a,n)=>{a.temporaryHP=n;},ambient:()=>trace.push(['ambient']),module:()=>{trace.push(['module']);return{id:444};},closePanels:(_o,n)=>trace.push(['closePanels',n]),create:(...a)=>s.effects.create(...a),blood:()=>{trace.push(['blood',7]);return c.blood??'R';},apply:(_o,e,loading)=>trace.push(['apply',snapshot(e),loading,0]),enqueue:(id,caller,target,e)=>trace.push(['event',id,caller,target,id===5?snapshot(e):e])});
  assert.equal(result,row.result,JSON.stringify(c));assert.equal(o.temporaryHP,row.temporaryHP,JSON.stringify(c));assert.equal(o.nativeFieldEc,row.commandable,JSON.stringify(c));assert.deepEqual(trace,row.trace,JSON.stringify(c));
 }
});
