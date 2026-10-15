import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {PathInformation} from '../src/path_information.js';
import {createIntraTileCache} from '../src/intratile_search.js';
import {plotSurfaceIntraTile,plotTileIntraTile} from '../src/intratile_plot.js';
const square={vertices:[[0,0,0],[10,0,0],[10,10,0],[0,10,0]],faces:[[0,1,2],[0,2,3]],adjacency:[[-2,-2,1],[0,-2,-2]]};
test('surface plot matches original physical admission, retry limits, timer wrap, cache transfer and waypoint append',async()=>{
  const rows=JSON.parse(readFileSync(new URL('../backups/animations/native-intratile-coordinator-observations.json',import.meta.url))).rows;
  for(const row of rows){
    const c=row.case,path=new PathInformation(77),calls=[],names=new Map(),state={path,mesh:square,tile:{x:c.tile[0],y:c.tile[1]}};let allocations=0,ticks=0,steps=0;
    path.raw.setInt32(0xe0,c.tileCount,true);path.raw.setInt32(0xf8,c.resume,true);path.raw.setFloat32(0xfc,c.bound,true);
    c.goal.forEach((v,n)=>path.raw.setFloat32(0x4c+n*4,v,true));path.raw.setInt32(0x88,c.old.length,true);
    if(c.old.length){const previous=new Float32Array(c.old);path.allocations.set(0x90,previous);names.set(previous,'oldWaypoints');}
    if(c.resume){const cache=createIntraTileCache();path.allocations.set(0x120,cache);names.set(cache,'oldCache');}
    const p={microseconds:()=>BigInt(c.timers[Math.min(ticks++,1)]),findTriangle:(_mesh,level,remaining,point,seed)=>{calls.push(['triangle',level,remaining,point,seed]);return c.triangle;},
      bestExit:(state,start)=>{calls.push(['exit',...start]);state.goal=c.exitGoal.map(Math.fround);state.bounds=c.exitBounds.map(Math.fround);state.goalTriangle=c.triangle;return c.exitResult;},
      deleteAlternatives:()=>calls.push(['deleteAlternatives']),onAllocate:(bytes,value)=>{calls.push(['allocate',bytes]);names.set(value,`new${++allocations}`);},onFree:value=>calls.push(['free',names.get(value)??'null']),
      dfs:(state,depth,cost,triangle,point,p)=>{calls.push(['dfs',state.limit,state.work,state.workLimit,depth,cost,triangle,...point,...p.end,Math.fround(.6),state.optimisation]);
        const response=c.responses[Math.min(steps++,c.responses.length-1)];state.work+=response.work;state.routeCount=response.route.length/2-1;state.route.set(response.route);return response.result;}};
    const result=await plotSurfaceIntraTile(state,c.start,c.end,c.budget,c.optimisation,p);
    assert.deepEqual({result,calls,resume:path.raw.getInt32(0xf8,true),bound:path.raw.getFloat32(0xfc,true),saved:path.raw.getInt32(0x100,true),cache:names.get(path.allocations.get(0x120))??null,
      waypoints:[...(path.allocations.get(0x90)??[])],goal:state.goal,bounds:state.bounds,target:state.goalTriangle},
      {result:row.result,calls:row.calls,resume:row.resume,bound:row.bound,saved:row.saved,cache:row.cache,waypoints:row.waypoints,goal:row.goal,bounds:row.bounds,target:row.target},JSON.stringify(c));
  }
});
test('tile plot matches original rotations, restored goals/exits, old waypoint retention and far-NPC optimisation',async()=>{
  const rows=JSON.parse(readFileSync(new URL('../backups/animations/native-tile-plot-observations.json',import.meta.url))).rows;
  for(const row of rows){
    const c=row.case,path=new PathInformation(77),calls=[],tile={x:c.tile[0],y:c.tile[1],orientation:c.orientation,mesh:c.loaded?square:null};
    c.goal.concat(c.originalStart).forEach((v,n)=>path.raw.setFloat32([0x4c,0x50,0x64,0x68][n],v,true));path.raw.setInt32(0xe0,c.tileCount,true);
    path.raw.setInt32(0x88,c.old.length,true);path.allocations.set(0x90,new Float32Array(c.old));path.allocations.set(0xf0,new Float32Array(c.exits));
    const p={creature:id=>{calls.push(['creature',id]);return c;},isPC:c=>c.pc,possessed:c=>{calls.push(['possessed']);return c.possessed;},
      surfacePlot:(state,start,end,budget,optimisation)=>{calls.push(['surface',start,end,budget,optimisation,[path.raw.getFloat32(0x4c,true),path.raw.getFloat32(0x50,true)],
        [...path.allocations.get(0xf0).slice(0,Math.max(0,c.tileCount-1)*2)]]);
        path.allocations.set(0x90,new Float32Array(c.old.concat(c.append)));path.raw.setInt32(0x88,c.old.length+c.append.length,true);return c.result;}};
    const result=await plotTileIntraTile(tile,{},path,c.start,c.end,12000,p);
    assert.deepEqual({result,calls,goal:[path.raw.getFloat32(0x4c,true),path.raw.getFloat32(0x50,true)],exits:[...path.allocations.get(0xf0)],waypoints:[...path.allocations.get(0x90)]},
      {result:row.result,calls:row.calls,goal:row.goal,exits:row.exits,waypoints:row.waypoints},JSON.stringify(c));
  }
});
test('diagnostic failures roll back temporary tile goal/exit transforms without hiding the unavailable owner',async()=>{
  for(const tileCount of [1,3]){
    const path=new PathInformation(77),tile={x:7,y:10,orientation:1,mesh:square},goal=[78.1234,109.8765],exits=new Float32Array([10,5,5,0]);
    path.raw.setInt32(0xe0,tileCount,true);path.allocations.set(0xf0,exits);goal.forEach((v,n)=>path.raw.setFloat32(0x4c+n*4,v,true));
    path.raw.setFloat32(0x64,72,true);path.raw.setFloat32(0x68,104,true);
    const beforeGoal=goal.map(Math.fround),beforeExits=[...exits];
    await assert.rejects(plotTileIntraTile(tile,{},path,[2,4],[8,9],500,{surfacePlot:()=>{throw new Error('Missing collision boundary');}}),/Missing collision boundary/);
    assert.deepEqual([path.raw.getFloat32(0x4c,true),path.raw.getFloat32(0x50,true)],beforeGoal);assert.deepEqual([...exits],beforeExits);
    assert.equal(path.raw.getInt32(0xe0,true),tileCount);
  }
});
