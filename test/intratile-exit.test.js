import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {PathInformation} from '../src/path_information.js';
import {generateBestIntraTileExit} from '../src/intratile_exit.js';
test('best intra-tile exit matches original corridor candidates, collision query order, fallback probes and scores',async()=>{
  const rows=JSON.parse(readFileSync(new URL('../backups/animations/native-best-exit-observations.json',import.meta.url))).rows;
  for(const row of rows){
    const c=row.case,path=new PathInformation(77),state={path,area:{},tile:{x:c.tile[0],y:c.tile[1],orientation:c.orientation,heightOffset:c.height}},calls=[],counts={};
    path.raw.setInt32(0xe0,c.tileCount,true);path.raw.setFloat32(4,c.radius,true);path.raw.setUint32(0xc8,90,true);path.allocations.set(0xf0,new Float32Array(c.exit));path.allocations.set(0xe8,new Int32Array(c.route));
    const resultFor=name=>{const n=counts[name]??0;counts[name]=n+1;return c[name][n%c[name].length];};
    const p={pathNode:()=>({entrances:c.entrances.map(p=>p.map(Math.fround))}),clipped:(_tile,a,b)=>{const status=resultFor('clip');calls.push(['clip',a,b,status]);return{status,entry:a,exit:b,minHeight:Math.fround(c.low),maxHeight:Math.fround(c.high)};},
      noDenied:(_tile,a,b,lo,hi,r,flag)=>{const value=resultFor('denied');calls.push(['denied',a,b,lo,hi,r,flag,value]);return value;},
      noNonWalk:(_area,a,b,lo,hi,r,id)=>{const value=resultFor('polygons');calls.push(['polygons',a,b,lo,hi,r,id,value]);return value;},
      noCreatures:(_area,a,b,_path,f1,f2,ptr,f3)=>{const value=resultFor('creatures');calls.push(['creatures',a,b,f1,f2,ptr??0,f3,value]);return value;}};
    const result=await generateBestIntraTileExit(state,c.start,p);
    assert.deepEqual({result,calls,goal:state.goal,bounds:state.bounds,target:state.goalTriangle},{result:row.result,calls:row.calls,goal:row.goal,bounds:row.bounds,target:row.target},JSON.stringify(c));
  }
});
