// Installed geometry integration of the real triangle/area collision providers.
// This exercises the core, not the still-unconnected area plot coordinator.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {PathInformation} from '../src/path_information.js';
import {rotateReal} from '../src/tile_path_node.js';
import {tileSubdivision,findSubdivisionTriangle} from '../src/tile_subdivision.js';
import {createIntraTileCache,intraTileDFS} from '../src/intratile_search.js';
import {intraTileSuccessors} from '../src/intratile_successors.js';
import {intraWalkableProviders,intraTileWalkable,intraAreaWalkable} from '../src/intratile_walkable.js';
const [install,modulePath,areaName,sx,sy,gx,gy]=process.argv.slice(2),start=[Number(sx),Number(sy)],goal=[Number(gx),Number(gy)],f=Math.fround;
const s=await new ModuleSession(await openLocalModule(install,modulePath),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0})
  .initialize([],{character:await fs.readFile(`${install}/data/lcv/fighter.bic`)});
await s.enterArea(areaName,[start[0],0,-start[1]]);
const area=s.currentArea,tile=await area.nativeGeometry.tile(Math.trunc(start[0]/10),Math.trunc(start[1]/10)),levels=tileSubdivision(tile.mesh),path=new PathInformation(s.player.id),at=[tile.x*10,tile.y*10];
assert.ok(goal.every((v,i)=>v>=at[i]&&v<=at[i]+10),'Fixture goal must belong to the same tile');
const local=v=>rotateReal(v.map((n,i)=>f(f(n)-f(at[i]))),tile.orientation),a=local(start),b=local(goal);
const triangle=findSubdivisionTriangle(tile.mesh,0,2,a),target=findSubdivisionTriangle(tile.mesh,0,2,b);assert.ok(triangle>=0&&target>=0);
const distance=f(Math.sqrt(f(f(f(b[0]-a[0])**2)+f(f(b[1]-a[1])**2))));
const state={path,area,tile,mesh:tile.mesh,goal:b,goalTriangle:target,bounds:[f(b[0]-.0001),f(b[0]+.0001),f(b[1]-.0001),f(b[1]+.0001)],optimisation:0,
  work:0,workLimit:500,entryCost:12,route:new Float32Array(levels[2].faces.length*4),triangles:new Int32Array(levels[2].faces.length),cache:createIntraTileCache(),limit:f(distance+10),bestMiss:3.4028234663852886e38};
const geometry=intraWalkableProviders(s,area),collision={tileLine:(state,from,to,out,strict)=>intraTileWalkable(state.tile,state.path,from,to,out,strict,geometry),
  areaLine:(state,from,to,low,high)=>intraAreaWalkable(state.area,state.tile,state.path,from,to,low,high,geometry)};
const p={successors:(...args)=>intraTileSuccessors(...args,collision),disposeNodes:()=>{}};
let result,passes=0;
do{state.work=0;result=await intraTileDFS(state,0,0,triangle,a,p);if(result===1)path.raw.setInt32(0x100,1,true);passes++;}while(result===1&&passes<30);
assert.equal(result,2,'Installed geometry core must reach its goal with real collision admission');
console.log(JSON.stringify({validation:'PASS',start,goal,tile:[tile.x,tile.y],orientation:tile.orientation,triangle,target,passes,route:[...state.route.slice(0,state.routeCount*2+2)],work:state.work,limits:'Native core and installed collision integration; not a live committed area path.'}));
