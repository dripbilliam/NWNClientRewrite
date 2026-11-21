import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {PathInformation} from '../src/path_information.js';
import {interTileSuccessors} from '../src/intertile_successors.js';
test('inter-tile successors match original exclusions, neighbour admission, FLOAT scores and stable physical ties',async()=>{
  const rows=JSON.parse(readFileSync(new URL('../backups/animations/native-intertile-successor-observations.json',import.meta.url))).rows;
  for(const row of rows){const c=row.case,calls=[],path=new PathInformation(77),tiles=new Int32Array(16),points=new Float32Array(16);
    tiles.set(c.previous.slice(0,2));points.set(c.previous.slice(2));path.allocations.set(0xe8,tiles);path.allocations.set(0xf0,points);
    path.allocations.set(0xd0,Int32Array.from(c.avoid.flatMap(a=>a.tile)));path.allocations.set(0xd8,Int32Array.from(c.avoid.flatMap(a=>a.exits)));path.raw.setInt32(0xcc,c.avoid.length,true);
    const state={path,width:c.width,height:c.height,goal:c.goal,goalPoint:c.goalPoint,goalExit:12,exitScratchCount:13,exitScratch:new Int32Array(13),successorsPerDepth:8};
    const p={regionCoords:(x,y,r)=>{calls.push(['centre',x,y,r]);return c.centre;},totalExits:(x,y)=>{calls.push(['total',x,y]);return c.exits.length;},
      exit:(x,y,n)=>{calls.push(['exit',x,y,n]);return c.exits[n];},entrance:(x,y,point)=>{calls.push(['entrance',x,y,...point]);return c.enter;}};
    const result=await interTileSuccessors(state,c.depth,...c.start,p);
    assert.deepEqual({calls,rows:result,cache:[...state.exitScratch]},{calls:row.calls,rows:row.rows,cache:row.cache},JSON.stringify(c));
  }
});
