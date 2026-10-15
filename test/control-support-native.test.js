import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {scriptGetIsImmune} from '../src/effect_immunity.js';
import {recomputeAmbientAnimation} from '../src/combat_lifecycle.js';
import {broadcastEffectFloaty} from '../src/effect_feedback.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-control-support-observations.json',import.meta.url)));
test('Immunity wrapper, ambient body selection and spell floating feedback match original instructions',async()=>{
  for(const row of oracle.rows){const c=row.case,calls=[],actor={id:99,objectType:c.objectType??5,nativeField771:c.state??0,nativeBodyState:c.body??0,chairId:c.chair??0x7f000000,
    position:c.position??[0,0,0],nativeProjectileRange268:c.radius??45},viewers=(c.viewers??[]).map((v,i)=>({id:100+i,objectType:v.type??5,position:v.position??[0,0,0]}));let result=null;
    if(c.mode==='immune')result=scriptGetIsImmune([99,c.category??13,...((c.argc??3)>=3?[98]:[])],{
      creature:id=>id===98?c.sourceExists===false?null:{id}:id!==99||c.exists===false||actor.objectType!==5?null:actor,
      immunity:(_o,id,source,flag)=>{calls.push(['immunity',id,Boolean(source),flag]);return c.immune??1;}})>>>0;
    else if(c.mode==='ambient')recomputeAmbientAnimation(actor,{dead:()=>c.dead??0,dying:()=>c.dying??0,setAnimation:(o,id)=>calls.push(['animation',id,o.nativeBodyState])});
    else await broadcastEffectFloaty(actor,c.strref??2242,{area:()=>c.area===false?null:{id:1},position:o=>o.position,
      firstByX:()=>Object.hasOwn(c,'first')?c.first:0,areaIds:()=>viewers.map(v=>v.id),object:id=>c.viewers[id-100].exists===false?null:viewers[id-100],
      client:id=>c.viewers[id-100].client===false?null:{id},send:(client,data)=>calls.push(['floaty',client.id,data.strref,data.objectId])});
    assert.equal(result,row.result,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.equal(actor.nativeBodyState,row.body,JSON.stringify(c));
  }
});
