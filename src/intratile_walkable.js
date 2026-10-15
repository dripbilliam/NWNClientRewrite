import {rotateTilePoint,clippedTileSurfaceLine,noDeniedTilePolygons} from './tile_surface_mesh.js';
const f=Math.fround;
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native intra-tile walkable provider ${n} is unavailable`);return p[n];};
const point=(v,n)=>{if(!Array.isArray(v)||v.length!==2||!v.every(Number.isFinite))throw new Error(`Native intra-tile walkable ${n} is unavailable`);return v.map(f);};
const origin=tile=>{if(!Number.isInteger(tile.x)||!Number.isInteger(tile.y))throw new Error('Native intra-tile location is unavailable');return[f(f(tile.x)*10),f(f(tile.y)*10)];};

// TestLineForWalkableOnTile1402c5250. Canonical local endpoints receive the
// tile origin; clipping supplies heights which are expanded BEFORE any strict
// endpoint rejection. Surface polygon checks retain their original flag0.
export async function intraTileWalkable(tile,path,from,to,out,strict,p){
  from=point(from,'start');to=point(to,'end');if(!Number.isInteger(strict))throw new Error('Native intra-tile endpoint flag is unavailable');
  const at=origin(tile),worldFrom=from.map((v,i)=>f(at[i]+v)),worldTo=to.map((v,i)=>f(at[i]+v));
  const clipped=await required(p,'clipped')(tile,worldFrom,worldTo);
  out.low=f(clipped.minHeight);out.high=f(clipped.maxHeight);
  if(clipped.status!==1)return 0;
  out.low=f(out.low-f(.1));out.high=f(f(path.raw.getFloat32(0xc,true)+f(.1))+out.high);
  if(strict!==0){const dx=f(clipped.exit[0]-worldTo[0]),dy=f(clipped.exit[1]-worldTo[1]);if(!(f(f(f(dy*dy)+f(dx*dx))+0)<=f(1e-10)))return 0;}
  return await required(p,'noDenied')(tile,clipped.entry.map((v,i)=>f(v-at[i])),clipped.exit.map((v,i)=>f(v-at[i])),out.low,out.high,path.raw.getFloat32(4,true),0)===1?1:0;
}

// TestLineForWalkableOnArea1402c5060. Forward rotate the canonical endpoints;
// both height limits receive native tile elevation. Creature checks only run
// after detailed object polygons return exactly1, with flags1/0/NULL/0.
export async function intraAreaWalkable(area,tile,path,from,to,low,high,p){
  from=point(from,'start');to=point(to,'end');const at=origin(tile);
  const a=rotateTilePoint(tile,from.map((v,i)=>f(at[i]+v)),false),b=rotateTilePoint(tile,to.map((v,i)=>f(at[i]+v)),false);
  if(!Number.isFinite(tile.heightOffset))throw new Error('Native intra-tile elevation is unavailable');
  if(await required(p,'noNonWalk')(area,a,b,f(f(tile.heightOffset)+f(low)),f(f(tile.heightOffset)+f(high)),path.raw.getFloat32(4,true),path.raw.getUint32(0xc8,true))!==1)return 0;
  return await required(p,'noCreatures')(area,a,b,path,1,0,null,0)===1?1:0;
}

// Live geometry adapters use the same loaded WOK and canonical object/spatial
// stores as attack approach. These do not replace intra-tile successor owners.
export function intraWalkableProviders(session,area){
  if(!area?.nativeGeometry)throw new Error('Native intra-tile geometry is unavailable');
  return{clipped:(tile,from,to)=>clippedTileSurfaceLine(tile.mesh,tile.x,tile.y,from,to),
    noDenied:(tile,...args)=>noDeniedTilePolygons(tile.mesh,...args),
    noNonWalk:(_area,...args)=>area.nativeGeometry.detailedPolygons(...args,{id:0},0,null,0),
    noCreatures:(_area,a,b,...args)=>session.combat.creatureLine(area,[a[0],f(-a[1])],[b[0],f(-b[1])],...args)};
}
