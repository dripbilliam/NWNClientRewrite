import { normalizeOrientation } from './combat_lifecycle.js';
import { OBJECT_INVALID } from './game_object_array.js';
const f=Math.fround;
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native BumpFriends provider ${n} is unavailable`);return p[n];};
const point=v=>{if(!Array.isArray(v)||v.length!==3||!v.every(Number.isFinite))throw new Error('Native BumpFriends point is unavailable');return v.map(f);};
const native=v=>{const p=point(v);return [p[0],f(-p[2]),p[1]];};
const render=v=>[v[0],v[2],f(-v[1])];
const normalize=v=>native(normalizeOrientation(render(v)));
const result=v=>{if(!Number.isInteger(v))throw new Error('Native BumpFriends result is unavailable');return v|0;};

// lineproject140230220..140230338 projects onto an INFINITE line. The dot
// sum is Y product + X product, then Z; squared length is X + Y, then Z.
export function projectBumpLine(from,to,value){
  from=native(from);to=native(to);value=native(value);
  const d=to.map((v,i)=>f(v-from[i]));
  let factor=f(f(f(d[0]*d[0])+f(d[1]*d[1]))+f(d[2]*d[2]));
  if(factor!==0){const delta=value.map((v,i)=>f(v-from[i]));
    factor=f(f(f(f(delta[1]*d[1])+f(delta[0]*d[0]))+f(delta[2]*d[2]))/factor);}
  return render(d.map((v,i)=>f(f(v*factor)+from[i])));
}

// CNWSCreature::BumpFriends140385130..14038560f. Actor temporarily occupies
// its line projection in canonical position memory, without spatial reindexing.
// It is restored after the blocker moves or every failed/unsupported search.
export async function bumpFriends(actor,blocker,from,to,p){
  if(result(await required(p,'bumpable')(actor,blocker))===0)return 0;
  const old=actor.position.slice(),original=native(old),blockerPosition=native(blocker.position);
  const projected=native(projectBumpLine(from,to,blocker.position));
  const direction=normalize(blockerPosition.map((v,i)=>f(v-projected[i])));
  const actorRadius=actor.nativePathInfo?.field8,blockerRadius=blocker.nativePathInfo?.field8,height=blocker.nativePathInfo?.fieldC;
  if(![actorRadius,blockerRadius,height].every(Number.isFinite))throw new Error('Native BumpFriends path radii/height are unavailable');
  const clearance=f(f(actorRadius+f(.1))+blockerRadius),candidate=direction.map((v,i)=>f(f(v*clearance)+projected[i]));
  const min=f(Math.min(candidate[2],blockerPosition[2])-f(.1)),max=f(f(Math.max(candidate[2],blockerPosition[2])+height)+f(.1));
  render(projected).forEach((v,i)=>{actor.position[i]=v;});
  try{
    let destination=candidate;
    if(result(await required(p,'safePoint')(await required(p,'area')(actor),render(candidate),blocker.nativePathInfo,0))===0||
      result(await required(p,'polygons')(await required(p,'area')(actor),[blockerPosition[0],-blockerPosition[1]],[candidate[0],-candidate[1]],
        min,max,blocker.nativePathInfo.field4,OBJECT_INVALID,{id:OBJECT_INVALID},1,null,0))!==1){
      const search=async(origin,orientation,end)=>{
        const out={point:[0,0,0]},status=result(await required(p,'safeDirection')(await required(p,'area')(actor),render(origin),render(orientation),clearance,end,blocker.nativePathInfo,1,out));
        return {status,point:status===1?native(out.point):null};
      };
      let found=await search(projected,direction,f(clearance+f(1)));
      if(found.status!==1)found=await search(projected,direction.map(v=>f(-v)),f(clearance+f(.5)));
      if(found.status!==1){
        const orientation=normalize(original.map((v,i)=>f(v-projected[i]))),origin=blockerPosition.map((v,i)=>f(f(v-projected[i])+original[i]));
        found=await search(origin,orientation,f(clearance+f(.5)));
      }
      if(found.status!==1)return 0;destination=found.point;
    }
    await required(p,'setPosition')(blocker,render(destination),0);return 1;
  }finally{old.forEach((v,i)=>{actor.position[i]=v;});}
}
