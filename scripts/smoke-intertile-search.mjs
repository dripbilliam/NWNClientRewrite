// Installed geometry integration for the inter-tile core only. Intra-tile
// collision/waypoint commit and the live area plot owner are not substituted.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {PathInformation} from '../src/path_information.js';
import {generateInterTilePath} from '../src/intertile_search.js';
import {interTileSuccessors} from '../src/intertile_successors.js';
import {closestTileRegion,tileRegionCoords,tileExit,tileTotalExits,tileRegionEntrance,tileExitNumber} from '../src/tile_path_node.js';
const [install,modulePath,area,sx,sy,gx,gy]=process.argv.slice(2),start=[Number(sx),Number(sy)],goal=[Number(gx),Number(gy)];
const s=await new ModuleSession(await openLocalModule(install,modulePath),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0})
  .initialize([],{character:await fs.readFile(`${install}/data/lcv/fighter.bic`)});
await s.enterArea(area,[start[0],0,-start[1]]);const geometry=s.currentArea.nativeGeometry,path=new PathInformation(s.player.id),slot=v=>Math.trunc(Math.fround(Math.fround(v)/10));
const startTile=start.map(slot),goalTile=goal.map(slot);
const initialRegion=closestTileRegion(await geometry.tile(...startTile),start),goalRegion=closestTileRegion(await geometry.tile(...goalTile),goal);
path.allocations.set(0xe8,new Int32Array(32*32*2));path.allocations.set(0xf0,new Float32Array(32*32*2));
const state={path,width:geometry.area.width,height:geometry.area.height,maximumWidth:32,maximumHeight:32,goal:[...goalTile,goalRegion],goalPoint:goal,goalExit:12,successorsPerDepth:8,exitScratchCount:13};
const getters={regionCoords:async(x,y,region)=>tileRegionCoords(await geometry.tile(x,y),region),totalExits:async(x,y)=>tileTotalExits(await geometry.tile(x,y)),
  exit:async(x,y,index)=>tileExit(await geometry.tile(x,y),index),entrance:async(x,y,point)=>tileRegionEntrance(await geometry.tile(x,y),point)};
const p={successors:(...args)=>interTileSuccessors(...args,getters),exitNumber:async(x,y,point)=>tileExitNumber(await geometry.tile(x,y),point)};
const threshold={value:Math.abs(startTile[0]-goalTile[0])+Math.abs(startTile[1]-goalTile[1])-2};
assert.equal(await generateInterTilePath(state,threshold,[...startTile,initialRegion],p),1,'Installed path-node graph must reach the requested tile/region');
const count=path.raw.getInt32(0xe0,true),tiles=[...path.allocations.get(0xe8).slice(0,count*2)],points=[...path.allocations.get(0xf0).slice(0,Math.max(0,count-1)*2)];
console.log(JSON.stringify({validation:'PASS',start,goal,startTile,goalTile,count,tiles,points,threshold:threshold.value,limits:'Native inter-tile graph core; not an intra-tile or walkable committed route.'}));
