import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {PathInformation} from '../src/path_information.js';
import {createIntraTileCache,intraTileDFS} from '../src/intratile_search.js';
import {createPathAlternatives,setPathAlternatives,getPathAlternatives} from '../src/path_alternatives.js';
test('intra-tile core matches original goal/stop bounds, FLOAT hash budgets, physical routes and resumable ownership',async()=>{
  const rows=JSON.parse(readFileSync(new URL('../backups/animations/native-intratile-search-observations.json',import.meta.url))).rows;
  for(const row of rows){const c=row.case,path=new PathInformation(77),calls=[],state={path,work:c.work,workLimit:c.workLimit,entryCost:12,routeCount:0,
      route:new Float32Array(24),triangles:new Int32Array(6),goal:c.goal,bounds:c.bounds,limit:c.limit,bestMiss:99,cache:createIntraTileCache()};
    path.raw.setFloat32(0x58,c.stop,true);path.raw.setInt32(0x100,c.saved,true);
    for(const seed of c.cache)state.cache[seed.index]={keys:seed.keys.slice(),budgets:seed.budgets.map(Math.fround)};
    if(c.oldCount){createPathAlternatives(path,c.oldCount);for(let n=0;n<c.oldCount;n++){const nodes=structuredClone(c.graph[String(n)]??[]);setPathAlternatives(path,n,c.savedStart,nodes.length,nodes);}}
    const p={successors:(state,point,triangle)=>{calls.push(['successors',...point,triangle]);state.work+=300;return structuredClone(c.graph[String(triangle)]??[]);},disposeNodes:nodes=>calls.push(['dispose',nodes])};
    const result=await intraTileDFS(state,c.depth,c.cost,c.triangle,c.point,p),count=path.raw.getInt32(0x104,true),alternatives=[];
    if(path.allocations.has(0x118))for(let n=0;n<count;n++)alternatives.push(getPathAlternatives(path,n));
    assert.deepEqual({result,calls,work:state.work,routeCount:state.routeCount,route:[...state.route],triangles:[...state.triangles],bestMiss:state.bestMiss,cache:state.cache,alternativeCount:count,alternatives},
      {result:row.result,calls:row.calls,work:row.work,routeCount:row.routeCount,route:row.route,triangles:row.triangles,bestMiss:row.bestMiss,cache:row.cache,alternativeCount:row.alternativeCount,alternatives:row.alternatives},JSON.stringify(c));
  }
});
