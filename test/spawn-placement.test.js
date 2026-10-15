import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {computeSafeLocation,computeNonVisibleLocation} from '../src/safe_location.js';
import {countVisibleToPlayers} from '../src/area_visibility_count.js';
test('safe, nonvisible and visibility counter owners match full original candidate/output traces',async()=>{
  const capture=JSON.parse(readFileSync(new URL('../backups/animations/native-spawn-placement-observations.json',import.meta.url)));assert.equal(capture.observations.length,512);
  for(const row of capture.observations){const c=row.case,calls=[],area={id:77,nativeObjectCursor238:99},origin=c.origin.map(Math.fround),out={point:[88,99,77]},path=c.hasPath?{field4:Math.fround(c.radius),fieldC:Math.fround(c.bodyHeight)}:null;let h=0,s=0;
    const actors=c.actorTypes.map((kind,n)=>({id:n+11,objectType:kind,point:c.actorPoints[n].map(Math.fround)})),p={
      warning:()=>calls.push(['warning']),height:(_a,point)=>{calls.push(['height',point.slice()]);return Math.fround(c.height+h++*.01);},
      safePoint:(_a,point)=>{calls.push(['safe',point.slice()]);return Number(c.safeAfter>=0&&s++>=c.safeAfter);},
      lineWalkable:(_a,from,to)=>{calls.push(['walk',from,to]);return c.walk;},polygons:(_a,from,to,low,high,radius)=>{calls.push(['polygons',from,to,low,high,radius]);return c.polygons;},
      lineOfSight:(_a,from,to)=>{calls.push(['los',from,to]);return c.los;},countVisible:(_a,point,limit)=>{calls.push(['count',point,limit]);return Math.min(c.visible,limit);},
      spatialIds:()=>actors.map(a=>a.id),object:id=>actors.find(a=>a.id===id),position:o=>o.point,client:id=>{calls.push(['client',id]);return c.client;},
    };
    const result=c.mode==='safe'?await computeSafeLocation(area,origin,c.range,path,c.straight,out,p):c.mode==='nonvisible'?await computeNonVisibleLocation(area,origin,path,c.straight,out,c.range,p):await countVisibleToPlayers(area,origin,c.limit,p);
    assert.deepEqual({result,out:out.point,origin,cursor:area.nativeObjectCursor238,calls},{result:row.result,out:row.out,origin:row.origin,cursor:row.cursor,calls:row.calls},JSON.stringify(c));
  }
});
