import {createPathAlternatives,getPathAlternatives,setPathAlternatives} from './path_alternatives.js';
const f=Math.fround,epsilon=f(.0001);
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native intra-tile ${n} is unavailable`);return v|0;};
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native intra-tile provider ${n} is unavailable`);return p[n];};
const finite=(v,n)=>{if(!Number.isFinite(v))throw new Error(`Native intra-tile ${n} is unavailable`);return f(v);};
// CNWTileSurfaceMeshHashTableEntry1402ba7a0: two -1 keys and two -1 FLOATs.
export function createIntraTileCache(){return Array.from({length:128},()=>({keys:[-1,-1],budgets:[-1,-1]}));}

// IntraTileDFS1402bf970. Search budgets, the two-key hash, physical route
// writes and saved successor ownership are separate from triangle geometry.
export async function intraTileDFS(state,depth,cost,triangle,point,p){
  depth=integer(depth,'depth');triangle=integer(triangle,'triangle');cost=finite(cost,'cost');
  const [x,y]=point.map((v,i)=>finite(v,['x','y'][i])),path=state.path,route=state.route,triangles=state.triangles;
  if(!(route instanceof Float32Array)||!(triangles instanceof Int32Array)||depth<0||depth>=triangles.length||depth*4+3>=route.length)throw new Error('Native intra-tile route allocation is unavailable');
  state.work=(integer(state.work,'work')+integer(state.entryCost,'entry work cost'))|0;state.routeCount=(depth*2)|0;route[depth*4]=x;route[depth*4+1]=y;
  const [lowX,highX,lowY,highY]=state.bounds.map((v,i)=>finite(v,`bound${i}`)),[gx,gy]=state.goal.map((v,i)=>finite(v,`goal${i}`));
  const stop=path.raw.getFloat32(0x58,true),dx=f(gx-x),dy=f(gy-y);
  if(stop>f(.01)&&depth>0&&f(highX-lowX)<=f(epsilon*3)&&f(highY-lowY)<=f(epsilon*3)&&f(f(f(dy*dy)+f(dx*dx))+0)<f(stop*stop)||lowX<=x&&x<=highX&&lowY<=y&&y<=highY)return 2;
  const nearestX=x>highX?highX:x<lowX?lowX:x,nearestY=y>highY?highY:y<lowY?lowY:y;
  const nx=f(nearestX-x),ny=f(nearestY-y),estimate=f(f(Math.sqrt(f(f(nx*nx)+f(ny*ny))))+cost),limit=finite(state.limit,'distance limit');
  // +178 is diagnostic scratch: the native surface constructor does not
  // initialise it and no search decision consumes it. Preserve a supplied
  // finite value; leave unknown allocator contents unknown.
  if(!(estimate<limit)){if(state.bestMiss!==undefined&&estimate<finite(state.bestMiss,'best miss'))state.bestMiss=estimate;return 3;}
  const index=(((triangle>>8)+triangle)|0)&127,entry=state.cache?.[index];
  if(!entry||!Array.isArray(entry.keys)||!Array.isArray(entry.budgets))throw new Error('Native intra-tile hash storage is unavailable');
  let saved=0;if(entry.keys[0]===triangle)saved=entry.budgets[0];else if(entry.keys[1]===triangle)saved=entry.budgets[1];
  const available=f(limit-cost);if(!(saved<available))return 3;
  triangles[depth]=triangle;const budget=f(available-epsilon),slot=budget<entry.budgets[0]?1:0;entry.keys[slot]=triangle;entry.budgets[slot]=budget;
  let start=0,count=0,nodes=null;
  if(depth<path.raw.getInt32(0x104,true)){
    if(path.raw.getInt32(0x100,true)!==0){const old=getPathAlternatives(path,depth);({start,count,nodes}=old);setPathAlternatives(path,depth,0,0,null);}
  }else{
    nodes=await required(p,'successors')(state,[x,y],triangle);if(!Array.isArray(nodes))throw new Error('Native intra-tile successor allocation is unavailable');count=nodes.length;
  }
  let result=3;
  for(let index=start;index<count;index++){
    if(integer(state.workLimit,'work limit')<integer(state.work,'work')){createPathAlternatives(path,(depth+1)|0);result=1;}
    else{
      const next=nodes?.[index];if(!next)throw new Error('Native intra-tile saved successor is unavailable');
      state.routeCount=(depth*2+1)|0;route[depth*4+2]=finite(next.via[0],'via x');route[depth*4+3]=finite(next.via[1],'via y');
      result=await intraTileDFS(state,(depth+1)|0,f(cost+finite(next.cost,'successor cost')),next.triangle,next.point,p);
    }
    if(result===1){setPathAlternatives(path,depth,index,count,nodes);return 1;}
    if(result!==3)break;
  }
  if(depth<path.raw.getInt32(0x104,true)&&path.raw.getInt32(0x100,true)!==0)path.raw.setInt32(0x104,depth,true);
  if(nodes!==null)await required(p,'disposeNodes')(nodes);
  return result;
}
