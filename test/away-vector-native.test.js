import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {computeAwayVector} from '../src/move_away.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-away-vector-observations.json',import.meta.url))),f=Math.fround;
const bits=value=>{const d=new DataView(new ArrayBuffer(4));d.setFloat32(0,value,true);return d.getUint32(0,true);};
test('escape-vector candidates, native float math, directional weighting, collision shortening and tie selection match original code',async()=>{
 assert.equal(data.rows.length,426);
 for(const row of data.rows){const c=row.case,calls=[],area={},path=c.path===false?null:{field4:f(c.radius??.6),fieldC:f(c.height??.5)};
  const point=await computeAwayVector(area,c.origin,c.threat,c.distance,path,{directLine:(_area,from,to,radius,height,flag)=>{assert.equal(_area,area);assert.equal(area.nativePathInfo280,path);const line=[from[0],from[1],to[0],to[1],radius,height,flag],index=calls.length;calls.push(line);const mode=c.line??'clear';return mode==='clear'?1:mode==='blocked'?0:mode==='prefix'?Number(index>=(c.blocked??0)):line[2]>=line[0]?1:-2;}});
  assert.deepEqual(point.map(bits),row.bits,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.equal(area.nativePathInfo280===path,row.pathStored,JSON.stringify(c));
 }
});
