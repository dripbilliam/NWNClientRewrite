import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {applyWounding,applyVampiricRegeneration,applyWoundingTick,updateWounding} from '../src/wounding_effect.js';
import {ModuleSession} from '../src/module_session.js';
import {subtractWorldTimes} from '../src/world_timer.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-wounding-observations.json',import.meta.url)));
const snapshot=e=>({id:e.id,type:e.type,subtype:e.subtype,durationType:e.durationType,duration:e.duration,creatorId:e.creatorId,spellId:e.spellId,casterLevel:e.casterLevel,exposed:Number(e.exposed),showIcon:Number(e.showIcon),integers:e.integers.slice()});
test('wounding application/tick/poll and vampiric healing match complete original owners and strict native clocks',async()=>{
 assert.equal(data.rows.length,275);
 for(const row of data.rows){const c=row.case,s=new ModuleSession(null),actor={id:99,areaId:500,nativeField771:c.state??0},source={id:98,areaId:c.sourceArea??500},effect=s.effects.create(84,98,c.integers??[4,3,500,0,0,0,0,0],8),trace=[];
  Object.assign(effect,{id:'000000000000004d',durationType:c.durationType??2,duration:3.25,spellId:11,casterLevel:7,showIcon:c.showIcon??1});s.effects.nextId=101n;
  const p={asCreature:()=>{trace.push(['asCreature']);return c.creature===false?null:actor;},dead:()=>{trace.push(['dead']);return c.dead??0;},creature:id=>{trace.push(['creature',id]);return c.source===false?null:source;},copyConstruct:(...args)=>s.effects.copyConstruct(...args),
   create:(...args)=>{const e=s.effects.create(...args);e.spellId=c.spell??-1;e.casterLevel=c.casterLevel??-1;return e;},apply:(o,e,loading)=>trace.push(['apply',o.id,snapshot(e),loading]),enqueue:(id,caller,target,e)=>trace.push(['event',id,caller,target,snapshot(e)]),damageIndex:flags=>{trace.push(['damageIndex',flags]);return flags<=1?0:31-Math.clz32(flags);},
   blood:()=>{trace.push(['blood',(c.appearance??7)&65535,'BLOODCOLR']);return c.blood??'R';},warning:()=>trace.push(['warning']),tick:()=>{trace.push(['tick']);return 1;},subtractTime:(a,b)=>{trace.push(['subtract',a.day,a.time,b.day,b.time]);return subtractWorldTimes(a,b,c.length??1000000);}};
  let result;
  if(c.mode==='apply')result=await applyWounding(actor,c.nullEffect?null:effect,p,c.loading??0);
  else if(c.mode==='vampiric')result=await applyVampiricRegeneration(actor,effect,p,c.loading??0);
  else if(c.mode==='tick')result=await applyWoundingTick(actor,effect,p);
  else{const scratch=structuredClone(c.scratch??{day:0,time:0});assert.equal(await updateWounding(actor,effect,c.now??{day:3,time:6501},scratch,p),false);assert.deepEqual(scratch,row.scratch,JSON.stringify(c));result=null;}
  assert.equal(result,row.result,JSON.stringify(c));assert.deepEqual(trace,row.trace,JSON.stringify(c));assert.deepEqual(snapshot(effect),row.effect,JSON.stringify(c));
 }
});
