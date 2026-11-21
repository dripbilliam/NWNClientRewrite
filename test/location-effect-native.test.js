import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {applyLocationEffect,broadcastLocationVisual} from '../src/location_effect.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-location-effect-observations.json',import.meta.url)));
test('location wrapper and point visual radius, constant channels and recipient traversal match native instructions',async()=>{
  for(const row of oracle.rows){const c=row.case,calls=[],packed=c.packed??8,effect={type:30,durationType:packed&7,subtype:packed&~7,duration:7,integers:[c.id??1],floats:[c.scale??1],vectors:[c.translate??[1,2,3],c.rotate??[4,5,6]]},
    location={areaId:99,position:c.point??[0,0,0],nativeOrientation:[1,0,0]},area={id:99,objectType:c.areaType??4},viewers=(c.viewers??[[-1,0,0],[45,0,0],[46,0,0]]).map((position,i)=>({id:100+i,position,objectType:(c.viewerTypes??[5,5,5])[i]})),
    p={object:id=>id===99?c.areaExists===false?null:area:viewers.find(o=>o.id===id),
      applyArea:(_a,e,point,orientation)=>calls.push(['area',e.subtype|e.durationType,e.duration,point,orientation]),
      visualRadius:()=>c.radius??0,firstByX:()=>c.indexSuccess===0?null:c.first??0,areaIds:()=>viewers.map(v=>v.id),position:o=>o.position,
      client:id=>c.clients===false?null:{id},send:(client,data)=>calls.push(['send',client.id,data])};
    if(c.mode==='wrapper')await applyLocationEffect(c.durationType??0,effect,location,c.seconds??1,p);else await broadcastLocationVisual(area,effect,location.position,p);
    assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.equal(effect.duration,7,'VM input copy remains separate');
  }
});
