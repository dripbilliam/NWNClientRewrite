import {plotAreaPath} from './area_path_plot.js';
import {plotTileIntraTile} from './intratile_plot.js';
import {generateBestIntraTileExit} from './intratile_exit.js';
import {generateInterTilePath} from './intertile_search.js';
import {interTileSuccessors} from './intertile_successors.js';
import {intraTileSuccessors} from './intratile_successors.js';
import {intraWalkableProviders,intraTileWalkable,intraAreaWalkable} from './intratile_walkable.js';
import {closestTileRegion,tileRegionCoords,tileExit,tileTotalExits,tileRegionEntrance,tileExitNumber} from './tile_path_node.js';
import {runtimeDiagnostics} from './runtime_diagnostics.js';

// Canonical live area geometry adapters. All searches resolve the active
// module's SET/WOK/path-node data and registry; no authored target exceptions.
export function areaPathProviders(session,area,base={}){
  if(!area?.nativeGeometry)throw new Error('Native area path geometry is unavailable');
  const geometry=area.nativeGeometry,collision=intraWalkableProviders(session,area),tile=(x,y)=>geometry.tile(x,y);
  const getters={regionCoords:async(x,y,region,outputRequired=true)=>{
    const at=await tile(x,y),point=tileRegionCoords(at,region,{outputRequired});
    if(point===null)runtimeDiagnostics.record('geometry.native-region-query-failed','Native GetRegionCoords returned0; caller ignores indeterminate output',
      {areaId:area.id,area:area.resRef,tile:[x,y],region,pathKind:at.pathNodes.path,pathOrientation:at.pathNodes.pathOrientation},'info');
    return point;
  },totalExits:async(x,y)=>tileTotalExits(await tile(x,y)),
    exit:async(x,y,index)=>tileExit(await tile(x,y),index),entrance:async(x,y,point)=>tileRegionEntrance(await tile(x,y),point)};
  const intra={...collision,microseconds:()=>BigInt(Math.trunc(performance.now()*1000)),creature:id=>{const o=session.registry.get(id);return o?.objectType===5?o:null;},
    isPC:o=>o.reputationPCFlag,possessed:o=>Number((o.associateType&65535)===3&&Boolean(session.combat.broadcastProviders().client(o.id))),
    bestExit:(state,start)=>generateBestIntraTileExit(state,start,collision),
    successors:(state,point,triangle)=>intraTileSuccessors(state,point,triangle,{
      tileLine:(state,from,to,out,strict)=>intraTileWalkable(state.tile,state.path,from,to,out,strict,collision),
      areaLine:(state,from,to,low,high)=>intraAreaWalkable(state.area,state.tile,state.path,from,to,low,high,collision)}),disposeNodes:()=>{}};
  return {...intra,
    markAI:value=>{session.nativeAIFieldA8=value;},closestRegion:async(_area,x,y,point)=>closestTileRegion(await tile(x,y),point),
    exitNumber:async(_area,at,point)=>tileExitNumber(await tile(...at),point),
    generate:(_area,path,threshold,start,goal,goalPoint)=>generateInterTilePath({path,width:geometry.area.width,height:geometry.area.height,
      maximumWidth:32,maximumHeight:32,goal,goalPoint,goalExit:12,successorsPerDepth:8,exitScratchCount:13},threshold,start,{
      successors:(...args)=>interTileSuccessors(...args,getters),exitNumber:async(x,y,point)=>tileExitNumber(await tile(x,y),point)}),
    tilePlot:async(_area,path,at,start,end,budget)=>plotTileIntraTile(await tile(...at),area,path,start,end,budget,intra),...base};
}
export function plotLiveAreaPath(session,area,path,budget,p={}){return plotAreaPath(area,path,budget,areaPathProviders(session,area,p));}
