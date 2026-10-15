import {tileSubdivision,findSubdivisionTriangle} from './tile_subdivision.js';
import {createIntraTileCache,intraTileDFS} from './intratile_search.js';
import {deletePathAlternatives} from './path_alternatives.js';
import {rotateReal,rotateCanonical} from './tile_path_node.js';
import {rotateTilePoint} from './tile_surface_mesh.js';
const f=Math.fround,epsilon=f(.0001);
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native intra-tile plot provider ${n} is unavailable`);return p[n];};
const int=(path,o)=>path.raw.getInt32(o,true),setInt=(path,o,v)=>path.raw.setInt32(o,v,true);
const scalar=(v,n)=>{if(!Number.isFinite(v))throw new Error(`Native intra-tile plot ${n} is unavailable`);return f(v);};
const half=(a,b,p)=>f(f(f(b[0]-a[0])*f(p[1]-a[1]))+f(f(a[1]-b[1])*f(p[0]-a[0])));
const distance=(point,b)=>{const x=f(Math.max(b[0],Math.min(b[1],point[0]))-point[0]),y=f(Math.max(b[2],Math.min(b[3],point[1]))-point[1]);return f(Math.sqrt(f(f(y*y)+f(x*x))));};

// CNWTileSurfaceMesh::PlotIntraTilePath1402c3830..1402c41e2.
// Preserve physical base-face admission before seeded FindTriangle(1,1),
// microsecond budget truncation, iterative FLOAT limits and saved cache owner.
// The route buffer capacity is base triangles*64 (+70), not subdivision depth2.
export async function plotSurfaceIntraTile(state,start,end,budget,optimisation,p){
  const {tile,path,mesh}=state;start=start.map(v=>scalar(v,'start'));end=end.map(v=>scalar(v,'end'));
  const began=BigInt(await required(p,'microseconds')()),at=[f(f(tile.x)*10),f(f(tile.y)*10)];
  tileSubdivision(mesh);
  const find=point=>{
    const seed=mesh.faces.findIndex(indices=>{const v=indices.map(n=>mesh.vertices[n]);return v.every((a,e)=>half(a,v[(e+1)%3],point)>=0);});
    return seed<0?-1:(p.findTriangle??findSubdivisionTriangle)(mesh,1,1,point,seed);
  };
  const removeAlternatives=()=>{(p.deleteAlternatives??deletePathAlternatives)(path);setInt(path,0x100,0);};
  const fail=()=>{removeAlternatives();setInt(path,0xf8,0);return 3;};
  if(int(path,0xe0)===1){
    state.goal=[f(path.raw.getFloat32(0x4c,true)-at[0]),f(path.raw.getFloat32(0x50,true)-at[1])];
    const [x,y]=state.goal;state.bounds=[f(x-epsilon),f(x+epsilon),f(y-epsilon),f(y+epsilon)];state.goalTriangle=find(state.goal);
  }else if(await required(p,'bestExit')(state,start)!==1)return fail();
  const triangle=find(start);if(triangle===-1)return fail();
  const allocate=(bytes,value)=>{p.onAllocate?.(bytes,value);return value;},free=value=>p.onFree?.(value);
  const count=mesh.faces.length*64;
  state.triangles=allocate(count*4,new Int32Array(count));state.route=allocate(count*16,new Float32Array(count*4));
  if(int(path,0xf8)===0){if(state.cache)free(state.cache);state.cache=allocate(2048,createIntraTileCache());}
  else{state.cache=path.allocations.get(0x120);if(!Array.isArray(state.cache)||state.cache.length!==128)throw new Error('Native intra-tile resumed cache is unavailable');}
  let bound=f(distance(start,state.bounds)+10);if(int(path,0xf8)===1)bound=path.raw.getFloat32(0xfc,true);
  const now=BigInt(await required(p,'microseconds')());state.work=0;state.workLimit=Math.max(500,Number(BigInt.asIntN(32,BigInt(budget>>>0)+began-now)));
  state.optimisation=optimisation;state.entryCost=12;
  let result;
  do{
    state.limit=bound;result=await (p.dfs??intraTileDFS)(state,0,0,triangle,start,{...p,end});bound=f(bound+5);
    if(result===1)setInt(path,0x100,1);else removeAlternatives();
  }while(state.work<=state.workLimit&&result===3&&bound<=40);
  if(result===1||result===3&&bound<=40){
    result=1;setInt(path,0xf8,1);path.raw.setFloat32(0xfc,f(bound-5),true);path.allocations.set(0x120,state.cache);
  }else{setInt(path,0xf8,0);free(state.cache);path.allocations.delete(0x120);}
  state.cache=null;
  if(result===2){
    const previousCount=int(path,0x88),previous=path.allocations.get(0x90),added=state.routeCount*2+2;
    if(previousCount<0||previousCount%2||previousCount>0&&(!(previous instanceof Float32Array)||previous.length<previousCount)||added<0||added>state.route.length)
      throw new Error('Native intra-tile waypoint allocation is unavailable');
    const next=allocate((previousCount+added)*4,new Float32Array(previousCount+added));
    if(previousCount){next.set(previous.subarray(0,previousCount));free(previous);}
    for(let n=0;n<added;n+=2){next[previousCount+n]=f(at[0]+state.route[n]);next[previousCount+n+1]=f(at[1]+state.route[n+1]);}
    setInt(path,0x88,next.length);path.allocations.set(0x90,next);
  }
  free(state.triangles);state.triangles=null;free(state.route);state.route=null;
  return result;
}

// CNWSTile::PlotIntraTilePath1404fe1b0. Surface work uses canonical local
// coordinates. Restore goals/exits afterwards; rotate only newly appended
// canonical-world waypoints. The optimisation uses the ORIGINAL path start.
export async function plotTileIntraTile(tile,area,path,start,end,budget,p){
  if(!tile?.mesh)return 3;
  const at=[f(f(tile.x)*10),f(f(tile.y)*10)],oldCount=int(path,0x88),tiles=int(path,0xe0),exits=path.allocations.get(0xf0);
  if(tiles!==1&&tiles>1&&(!(exits instanceof Float32Array)||exits.length<(tiles-1)*2))throw new Error('Native tile plot exit storage is unavailable');
  const localGoal=[f(path.raw.getFloat32(0x4c,true)-at[0]),f(path.raw.getFloat32(0x50,true)-at[1])];
  const savedGoal=[path.raw.getFloat32(0x4c,true),path.raw.getFloat32(0x50,true)],savedExits=tiles>1?exits.slice(0,(tiles-1)*2):null;
  if(tiles===1){const rotated=rotateReal(localGoal,tile.orientation);rotated.forEach((v,n)=>path.raw.setFloat32(0x4c+n*4,f(at[n]+v),true));}
  else for(let n=0;n<(tiles-1)*2;n+=2)exits.set(rotateReal([exits[n],exits[n+1]],tile.orientation),n);
  const x=f(f(path.raw.getFloat32(0x64,true)-at[0])-5),y=f(f(path.raw.getFloat32(0x68,true)-at[1])-5);
  let result;
  try{
    let optimisation=0;
    if(f(f(y*y)+f(x*x))>225){
      const actor=await required(p,'creature')(path.raw.getUint32(0x24,true));
      if(!actor)throw new Error('Native far-tile plot creature is unavailable');
      if(await required(p,'isPC')(actor)===0&&await required(p,'possessed')(actor)===0)optimisation=1;
    }
    const state={tile,area,path,mesh:tile.mesh};
    result=await (p.surfacePlot??plotSurfaceIntraTile)(state,rotateReal(start,tile.orientation),rotateReal(end,tile.orientation),budget,optimisation,p);
  }catch(error){
    // Replacement diagnostics throw at undefined native helper boundaries.
    // Roll back temporary coordinate transforms so the canonical goal and
    // exit data remain reviewable and safe to retry after that failure.
    savedGoal.forEach((v,n)=>path.raw.setFloat32(0x4c+n*4,v,true));if(savedExits)exits.set(savedExits);throw error;
  }
  if(int(path,0xe0)===1)localGoal.forEach((v,n)=>path.raw.setFloat32(0x4c+n*4,f(at[n]+v),true));
  else for(let n=0;n<(int(path,0xe0)-1)*2;n+=2)exits.set(rotateCanonical([exits[n],exits[n+1]],tile.orientation),n);
  const count=int(path,0x88),waypoints=path.allocations.get(0x90);
  if(count!==oldCount&&tile.orientation!==0){
    if(!(waypoints instanceof Float32Array)||waypoints.length<count)throw new Error('Native tile plot waypoint storage is unavailable');
    for(let n=oldCount;n<count;n+=2)waypoints.set(rotateTilePoint(tile,[waypoints[n],waypoints[n+1]],false),n);
  }
  return result;
}
