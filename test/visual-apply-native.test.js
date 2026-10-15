import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {applyVisualEffect} from '../src/visual_effect.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-visual-apply-observations.json',import.meta.url)));
test('visual application classification, constant channels, recipients and consumption match native instructions',async()=>{
  for(const row of oracle.rows){
    const c=row.case,calls=[],actor={id:99,position:[0,0,0],nativeDestroyableF0:c.destroyable??1,nativeProjectileRange268:c.range??45},
      effect={integers:[c.id??1,c.flag??0,c.miss??0],objectIds:[c.override??0x7f000000],creatorId:c.creator??88,durationType:c.durationType??0,duration:c.duration??2,
        floats:[c.scale??1],vectors:[c.translate??[1,2,3],c.rotate??[4,5,6]]},viewers=(c.viewers??[[-1,0,0],[46,0,0],[48,0,0]]).map((position,i)=>({id:100+i,position}));
    const p={plot:()=>c.plot??0,missPoint:()=>c.missPoint??[2,3,1],position:o=>o.position,visualType:()=>({found:c.found!==0,value:c.kind??'B'}),
      addLoop:(_o,...args)=>calls.push(['loop',...args]),area:()=>c.area===false?null:{},firstByX:()=>c.indexSuccess===0?null:c.first??0,
      areaIds:()=>viewers.map(v=>v.id),object:id=>viewers.find(v=>v.id===id),client:id=>c.clients===false?null:{id},send:(client,data)=>calls.push(['send',client.id,data])};
    const result=await applyVisualEffect(c.actor===false?null:actor,c.effect===false?null:effect,p);
    assert.equal(result,row.result,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));
  }
});
