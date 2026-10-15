import {intersectAreaSegments} from './area_collision.js';
const f=Math.fround,epsilon=f(.0001),high=f(9.9999);
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native inter-tile successor ${n} is unavailable`);return v|0;};
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native inter-tile successor provider ${n} is unavailable`);return p[n];};
const point=(v,n)=>{if(!Array.isArray(v)||v.length!==2||!v.every(Number.isFinite))throw new Error(`Native inter-tile successor ${n} is unavailable`);return v.map(f);};
const squared=v=>f(f(v[1]*v[1])+f(v[0]*v[0]));
function alignment(direction,delta){
  let value=f(f(direction[0]*delta[0])+f(delta[1]*direction[1]));
  if(Math.abs(delta[0])>=epsilon||Math.abs(delta[1])>=epsilon)value=f(value/f(Math.sqrt(squared(delta))));
  if(Math.abs(direction[0])>=epsilon||Math.abs(direction[1])>=epsilon)value=f(value/f(Math.sqrt(squared(direction))));
  return value;
}
function score(origin,goal,worldExit,localExit){
  let a=worldExit.slice(),b=worldExit.slice();
  if(localExit[1]>high||localExit[1]<epsilon){const width=f(Math.min(localExit[0],f(10-localExit[0]))-epsilon);a[0]=f(a[0]-width);b[0]=f(b[0]+width);}
  else if(localExit[0]>high||localExit[0]<epsilon){const width=f(Math.min(localExit[1],f(10-localExit[1]))-epsilon);a[1]=f(a[1]-width);b[1]=f(b[1]+width);}
  else return 0;
  if(intersectAreaSegments(origin,goal,a,b))return 1;
  const direction=goal.map((v,i)=>f(v-origin[i]));
  const first=alignment(direction,a.map((v,i)=>f(v-origin[i]))),second=alignment(direction,b.map((v,i)=>f(v-origin[i])));
  // Native compares the upper endpoint first and keeps the lower endpoint
  // on ties (MAXSS on the vertical branch), including its signed zero.
  return first>=second?first:second;
}

// InterTileDFSGenerateSuccessors14036d560. Physical exit order, entry-pair
// exclusions, neighbour-region admission and descending stable score order.
// Tile path-node/door storage remains explicit providers.
export async function interTileSuccessors(state,depth,x,y,region,p){
  const path=state.path,width=integer(state.width,'width'),height=integer(state.height,'height');
  const valid=(x,y)=>x>=0&&y>=0&&x<width&&y<height;
  if(!valid(x,y)||!valid(state.goal[0],state.goal[1]))throw new Error('Native successor tile lookup is unavailable');
  const centre=point(await required(p,'regionCoords')(x,y,region),'region centre'),origin=[f(f(f(x)*10)+centre[0]),f(f(f(y)*10)+centre[1])];
  await p.regionCoords(...state.goal,false);
  const goal=point(state.goalPoint,'goal point'),count=integer(await required(p,'totalExits')(x,y),'exit count'),cache=state.exitScratch;
  if(!(cache instanceof Int32Array)||cache.length<state.exitScratchCount)throw new Error('Native successor exit scratch is unavailable');cache.fill(0);
  const avoidCount=path.raw.getInt32(0xcc,true),avoidTiles=path.allocations.get(0xd0),avoidExits=path.allocations.get(0xd8);
  if(avoidCount>0&&(!(avoidTiles instanceof Int32Array)||!(avoidExits instanceof Int32Array)))throw new Error('Native successor avoidance allocation is unavailable');
  const mark=index=>{if(index<0||index>=cache.length)throw new Error('Native successor exclusion index is unavailable');cache[index]=1;};
  for(let n=0;n<avoidCount;n++)if(avoidTiles[n*2]===x&&avoidTiles[n*2+1]===y){
    const outgoing=avoidExits[n*2+1];
    if(depth===0){if(outgoing!==state.goalExit)mark(outgoing);}
    else{
      const tiles=path.allocations.get(0xe8),points=path.allocations.get(0xf0);
      if(!(tiles instanceof Int32Array)||!(points instanceof Float32Array))throw new Error('Native successor route allocation is unavailable');
      const incoming=[f(f(f((tiles[depth*2-2]-x)|0)*10)+points[depth*2-2]),f(f(f((tiles[depth*2-1]-y)|0)*10)+points[depth*2-1])];
      const exit=await required(p,'exit')(x,y,avoidExits[n*2]),at=point(exit.point,'avoidance exit');
      if(at.every((v,i)=>f(incoming[i]-epsilon)<=v&&v<=f(incoming[i]+epsilon)))mark(outgoing);
    }
  }
  const result=[];if(cache[state.goalExit]!==0)return result;
  for(let index=0;index<count;index++){
    const exit=await required(p,'exit')(x,y,index),at=point(exit.point,'exit point');
    if(integer(exit.region,'exit region')!==region||cache[index]!==0)continue;
    if(result.length>=state.successorsPerDepth)return result;
    let nx=x,ny=y,local=at.slice();
    if(at[0]>high){nx++;local[0]=0;}if(at[0]<epsilon){nx--;local[0]=10;}
    if(at[1]>high){ny++;local[1]=0;}if(at[1]<epsilon){ny--;local[1]=10;}
    if(!valid(nx,ny))continue;
    const next=integer(await required(p,'entrance')(nx,ny,local),'neighbour region');if(next<0)continue;
    await p.regionCoords(nx,ny,next,false);
    const world=[f(f(f(x)*10)+at[0]),f(f(f(y)*10)+at[1])],value=score(origin,goal,world,at);
    if(!Number.isFinite(value))throw new Error('Native successor nonfinite score is unsupported');
    const candidate={tile:[nx,ny],region:next,exit:at,score:value};
    const before=result.findIndex(other=>value>other.score);if(before<0)result.push(candidate);else result.splice(before,0,candidate);
  }
  return result;
}
