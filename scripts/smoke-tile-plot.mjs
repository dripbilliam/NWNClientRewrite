// Installed geometry through the native tile/surface coordinator and resume.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {PathInformation} from '../src/path_information.js';
import {plotTileIntraTile} from '../src/intratile_plot.js';
import {intraTileSuccessors} from '../src/intratile_successors.js';
import {intraWalkableProviders,intraTileWalkable,intraAreaWalkable} from '../src/intratile_walkable.js';
const [install,modulePath,areaName,sx,sy,gx,gy]=process.argv.slice(2),start=[Number(sx),Number(sy)],goal=[Number(gx),Number(gy)],f=Math.fround;
const s=await new ModuleSession(await openLocalModule(install,modulePath),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize([],{character:await fs.readFile(`${install}/data/lcv/fighter.bic`)});
await s.enterArea(areaName,[start[0],0,-start[1]]);
const area=s.currentArea,tile=await area.nativeGeometry.tile(Math.trunc(start[0]/10),Math.trunc(start[1]/10)),path=new PathInformation(s.player.id),at=[tile.x*10,tile.y*10];
assert.ok(goal.every((v,i)=>v>=at[i]&&v<=at[i]+10));path.raw.setInt32(0xe0,1,true);
start.concat(goal).forEach((v,n)=>path.raw.setFloat32([0x64,0x68,0x4c,0x50][n],v,true));
const geometry=intraWalkableProviders(s,area),p={microseconds:()=>0n,creature:id=>s.registry.get(id),isPC:o=>o.reputationPCFlag,possessed:()=>0,
  successors:(state,point,triangle)=>intraTileSuccessors(state,point,triangle,{
    tileLine:(state,from,to,out,strict)=>intraTileWalkable(tile,path,from,to,out,strict,geometry),
    areaLine:(state,from,to,low,high)=>intraAreaWalkable(area,tile,path,from,to,low,high,geometry)}),disposeNodes:()=>{}};
let result,passes=0;
do{result=await plotTileIntraTile(tile,area,path,start.map((v,n)=>f(f(v)-at[n])),goal.map((v,n)=>f(f(v)-at[n])),500,p);passes++;}while(result===1&&passes<30);
assert.equal(result,2);assert.deepEqual([path.raw.getFloat32(0x4c,true),path.raw.getFloat32(0x50,true)],goal.map(f));
console.log(JSON.stringify({validation:'PASS',start,goal,tile:[tile.x,tile.y],orientation:tile.orientation,passes,waypoints:[...path.allocations.get(0x90)],limits:'Real installed collision and tile coordinator; deterministic timer fixture, not live area movement.'}));
