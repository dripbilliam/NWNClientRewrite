import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {PathInformation} from '../src/path_information.js';
import {interTileDFS,generateInterTilePath} from '../src/intertile_search.js';
test('inter-tile search core matches original iterative depth, region BYTE pruning, failed-route writes and avoidance',async()=>{
  const rows=JSON.parse(readFileSync(new URL('../backups/animations/native-intertile-search-observations.json',import.meta.url))).rows;
  for(const row of rows){const c=row.case,path=new PathInformation(77),tiles=new Int32Array(128),points=new Float32Array(128),calls=[];
    path.allocations.set(0xe8,tiles);path.allocations.set(0xf0,points);path.allocations.set(0xd0,Int32Array.from(c.avoid.flatMap(a=>a.tile)));path.allocations.set(0xd8,Int32Array.from(c.avoid.flatMap(a=>a.exits)));path.raw.setInt32(0xcc,c.avoid.length,true);
    if(c.depth>0){tiles.set(c.previous.slice(0,2));points.set(c.previous.slice(2));}
    const state={path,goal:c.goal,goalExit:12,maximumWidth:32,maximumHeight:32,successorsPerDepth:8,exitScratchCount:13,visited:new Uint8Array(32*32*6)};state.visited[c.visitIndex]=c.visitValue;
    const threshold={value:c.budget},p={successors:(_state,depth,x,y,region)=>{const key=[x,y,region].join(',');calls.push(['successors',depth,key]);return c.graph[key]??[];},exitNumber:(_x,_y,point)=>{calls.push(['exit',...point]);return c.exitNumber;}};
    const result=c.mode==='generate'?await generateInterTilePath(state,threshold,c.start,p):await interTileDFS(state,c.depth,c.budget,...c.start,p);
    assert.deepEqual({result,calls,count:path.raw.getInt32(0xe0,true),threshold:threshold.value,tiles:[...tiles.slice(0,12)],points:[...points.slice(0,12)]},
      {result:row.result,calls:row.calls,count:row.count,threshold:row.threshold,tiles:row.tiles,points:row.points},JSON.stringify(c));
    if(c.mode==='dfs')assert.deepEqual([...state.visited],row.visited,JSON.stringify(c));
    else assert.deepEqual([state.visited,state.successorStorage,state.exitScratch],[null,null,null]);
  }
});
