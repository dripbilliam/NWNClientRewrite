import {getAttackData} from './combat_attack_data.js';
import {rulesetFloat} from './combat_stats.js';
import {normalizeOrientation} from './combat_lifecycle.js';
import {nativeAtanf,nativeCosf,nativeSinf} from './native_math.js';
import {intersectAreaSegments} from './area_collision.js';
const f=Math.fround,required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native ranged miss provider ${n} is unavailable`);return p[n];};
const vector=v=>{if(!Array.isArray(v)||v.length!==3||!v.every(Number.isFinite))throw new Error('Native ranged miss vector is unavailable');return v.map(f);};
const normalize=v=>{const out=normalizeOrientation([v[0],v[2],f(-v[1])]);return[out[0],f(-out[2]),out[1]];};
const add=(a,b)=>a.map((v,i)=>f(v+b[i])),subtract=(a,b)=>a.map((v,i)=>f(v-b[i])),scale=(v,n)=>v.map(x=>f(x*n));
// This owner sums Y² then X² then Z² (unlike magnitude(Vector)).
const squared=v=>f(f(f(v[1]*v[1])+f(v[0]*v[0]))+f(v[2]*v[2]));
const cvtt=v=>Number.isFinite(v)&&v>=-2147483648&&v<2147483648?Math.trunc(v):-2147483648;
const remainder=(n,divisor)=>{if(!divisor||n===-2147483648&&divisor===-1)throw new Error('Native ranged miss rules cause an integer division fault');return n%divisor;};
const write=(data,v)=>{for(let i=0;i<3;i++)data.raw.setFloat32(0x80+i*4,v[i],true);};

// ResolveRangedMiss1403ea490..1403eb50a, full unwind capture. Native
// clipping checks a bounded endpoint but its successful outside-area path
// writes the ORIGINAL XY endpoint; do not replace it with a clamped point.
export async function resolveRangedMiss(actor,target,rules,p){
  if(!target)return;
  const round=actor.combatRound,index=round.currentAttack&255,data=getAttackData(round,index,p.warning);
  if(((data.result-4)&0xfa)!==0||data.result===5)return;
  let radius=f(.5);
  if(await required(p,'creature')(target)){
    const defender=await p.creature(target),space=await required(p,'personalSpace')(defender);
    if(!Number.isFinite(space))throw new Error('Native ranged miss personal space is unavailable');radius=f(f(space)-f(.1));
  }
  const missedBy=(getAttackData(round,index,p.warning).missedBy<<24)>>24;
  const displacement=f(f(missedBy)/rulesetFloat(rules,'RANGED_MISS_DISTANCE_MODIFIER',4));
  let from=vector(await required(p,'position')(actor)),to=vector(await p.position(target));
  const minimum=rulesetFloat(rules,'MIN_RANGED_DISTANCE',10);
  const distance=squared(subtract(to,from));
  const random=()=>{if(typeof p.random?.next!=='function')throw new Error('Native ranged miss random stream is unavailable');const draw=p.random.next();if(!Number.isInteger(draw))throw new Error('Native ranged miss random draw is unavailable');return draw|0;};
  let point;
  if(distance<=f(minimum*minimum)){
    to=vector(await p.position(target));from=vector(await p.position(actor));let direction=subtract(to,from);
    const side=random()%2;
    const unit=normalize(direction),unit2=normalize(direction);
    let lateral=side===0?[f(-unit[1]),unit2[0],0]:[unit[1],f(-unit2[0]),0];
    lateral=add(lateral,scale(lateral,radius));
    to=vector(await p.position(target));from=vector(await p.position(actor));
    if(squared(subtract(to,from))>25){
      const draw=random(),amount=f(f(remainder(draw,cvtt(f(displacement*1000))))/1000);
      lateral=add(lateral,scale(lateral,amount));
    }
    direction=add(direction,lateral);
    const modulus=cvtt(rulesetFloat(rules,'MIN_RANGED_DISTANCE',10)),draw=random();
    const range=f(rulesetFloat(rules,'MIN_RANGED_DISTANCE',10)+f(remainder(draw,modulus))),unit3=normalize(direction);
    to=vector(await p.position(target));point=[f(range*unit3[0]),f(range*unit3[1]),f(to[2]+1)];
    // Original adds target XYZ after setting Z to target.Z+1.
    point=add(point,to);
  }else{
    from=vector(await p.position(actor));to=vector(await p.position(target));
    const direction=normalize(subtract(from,to));let angle=nativeAtanf(f(direction[1]/direction[0]));
    const side=random()%2,offset=f(f(remainder(random(),2094))/1000);
    angle=side===0?f(angle+offset):f(angle-offset);
    point=[nativeCosf(angle),nativeSinf(angle),0];
    if(direction[0]<0)point=point.map(v=>f(-v));
    point=scale(point,displacement);to=vector(await p.position(target));point=add(point,to);
    to=vector(await p.position(target));point[2]=f(to[2]+1);
  }
  from=vector(await p.position(actor));const start=[from[0],from[1],f(from[2]+1)],hit=[0,0,0];
  let area=await required(p,'area')(actor);if(!area)throw new Error('Native ranged miss area is unavailable');
  const width=f(f(area.width|0)*10),height=f(f(area.height|0)*10);
  const clear=async end=>required(p,'lineOfSight')(area,start,end,hit,actor.id,target.id,1);
  if(point[0]<=width&&point[1]<=height&&point[0]>=0&&point[1]>=0){
    area=await p.area(actor);
    if(await clear(point)!==0){
      write(data,point);area=await p.area(actor);
      const z=await required(p,'height')(area,point);if(!Number.isFinite(z))throw new Error('Native ranged miss height is unavailable');
      data.raw.setFloat32(0x88,z,true);return;
    }
  }else{
    // Original prioritizes X-edge intersections, then Y; failed intersections
    // retain the candidate and emit the native warning before the final LOS.
    const end=[...point],edges=[];
    if(point[0]>width)edges.push([[width,0],[width,height]]);
    else if(point[0]<0)edges.push([[0,0],[0,height]]);
    if(point[1]>height)edges.push([[0,height],[width,height]]);
    else if(point[1]<0)edges.push([[0,0],[width,0]]);
    let intersection=null;
    for(const edge of edges){intersection=intersectAreaSegments(from.slice(0,2),point.slice(0,2),...edge);if(intersection)break;}
    if(intersection){end[0]=intersection[0];end[1]=intersection[1];}
    else p.warning?.('Native warning: Something is wrong with the computation of arrow hits.');
    area=await p.area(actor);
    if(await clear(end)!==0){write(data,point);data.raw.setFloat32(0x88,(await p.position(target))[2],true);return;}
  }
  write(data,vector(hit));
}
