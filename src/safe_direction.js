import {normalizeOrientation} from './combat_lifecycle.js';
import {OBJECT_INVALID} from './game_object_array.js';
const f=Math.fround;
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native safe-direction provider ${n} is unavailable`);return p[n];};
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native safe-direction ${n} is unavailable`);return v|0;};
const point=v=>{if(!Array.isArray(v)||v.length!==3||!v.every(Number.isFinite))throw new Error('Native safe-direction point is unavailable');return v.map(f);};
const cvtt=v=>Number.isFinite(v)&&v>=-2147483648&&v<2147483648?Math.trunc(v):-2147483648;

// ComputeSafeLocationInDirection14036b050..14036b63b. Coordinates and
// providers use native XYZ. Scan distance, then center,+right,-left,+2,-2.
// Initial safe origin wins even outside the requested distance interval.
export async function computeSafeLocationInDirection(area,origin,direction,start,end,path,straight,out,p){
  if(!path){required(p,'warning')('Native safe-direction pathfinding information is NULL');return 0;}
  const radius=f(path.field4);area.nativePathInfo280=path;
  if(!Number.isFinite(radius))throw new Error('Native safe-direction radius is unavailable');
  if(radius<=0){required(p,'warning')('Native safe-direction personal space is <=0');return 0;}
  origin=point(origin);direction=point(direction);start=f(start);end=f(end);straight=integer(straight,'straight-line flag');
  if(!Number.isFinite(start)||!Number.isFinite(end)||!Number.isFinite(path.fieldC))throw new Error('Native safe-direction range/height is unavailable');
  const height=async candidate=>{const n=await required(p,'height')(area,candidate);if(!Number.isFinite(n))throw new Error('Native safe-direction terrain height is unavailable');return f(n);};
  const finish=candidate=>{out.point=candidate.slice();return 1;};
  const initial=[origin[0],origin[1],await height(origin)];
  if(integer(await required(p,'safePoint')(area,initial,path,0),'initial safe result')===1)return finish(initial);
  const margin=f(.1),epsilon=f(.01),low=f(origin[2]-margin);
  if(integer(await required(p,'lineWalkable')(area,[f(origin[0]-.001),origin[1]],origin.slice(0,2)),'initial line result')===0||
    integer(await required(p,'polygons')(area,[f(origin[0]-epsilon),f(origin[1]-epsilon)],[f(origin[0]+epsilon),f(origin[1]+epsilon)],
      low,f(f(origin[2]+f(path.fieldC))+margin),radius,OBJECT_INVALID,{id:OBJECT_INVALID},1,null,0),'initial polygon result')===0){
    required(p,'warning')('Native unsafe origin: straight line not required for ComputeSafeLocationInDirection');straight=0;
  }
  let step=f(end/f(10));if(radius<=step)step=radius>=margin?radius:margin;
  if(!(step>0))throw new Error('Native safe-direction nonpositive step is unsupported');
  const normalized=normalizeOrientation([direction[0],0,f(-direction[1])]),dx=f(step*normalized[0]),dy=f(step*f(-normalized[2]));
  const first=cvtt(f(f(start+epsilon)/step)),last=cvtt(f(f(end+epsilon)/step));
  let visited=0;
  for(let distance=first;distance<=last;distance++){
    // Negative distance performs no inner scan in the native signed loop.
    if(distance<0)continue;
    const forward=[f(f(dx*f(distance))+origin[0]),f(f(dy*f(distance))+origin[1])];
    for(let slot=0;slot<=distance*2;slot++){
      if(++visited>1000000)throw new Error('Native safe-direction search exceeds supported candidate budget');
      const lateral=((slot&1)*2-1)*Math.trunc((slot+1)/2),n=f(lateral);
      const candidate=[f(f(dy*n)+forward[0]),f(f(f(-dx)*n)+forward[1]),origin[2]];
      candidate[2]=await height(candidate);
      if(integer(await p.safePoint(area,candidate,path,0),'candidate safe result')!==1)continue;
      if(straight!==0){
        if(integer(await p.lineWalkable(area,candidate.slice(0,2),origin.slice(0,2)),'candidate line result')!==1)continue;
        if(integer(await p.polygons(area,origin.slice(0,2),candidate.slice(0,2),low,f(f(f(path.fieldC)+margin)+candidate[2]),radius,
          OBJECT_INVALID,{id:OBJECT_INVALID},1,null,0),'candidate polygon result')!==1)continue;
      }
      return finish(candidate);
    }
  }
  return 0;
}
