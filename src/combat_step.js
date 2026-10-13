import { OBJECT_INVALID } from './game_object_array.js';
import { normalizeOrientation } from './combat_lifecycle.js';
import { setRoundPaused,setPauseTimer } from './combat_timing.js';

const f=Math.fround;
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native combat step provider ${n} is unavailable`);return p[n];};
const position=o=>{
  if(!Array.isArray(o.position)||o.position.length!==3||!o.position.every(Number.isFinite))throw new Error('Native combat step position is unavailable');
  return o.position.map(f);
};

// DoCombatStep 1403e2830..1403e2fdf. Float32 vectors retain render mapping
// [native X,native Z,-native Y]. The duration argument is unused by the native
// function: a successful step does NOT add a guessed animation pause duration.
export async function prepareCombatStep(actor,step,duration,targetId,p){
  if(![step,duration,targetId].every(Number.isInteger))throw new Error('Native combat step arguments are unavailable');
  step&=255;targetId>>>=0;
  const idle=()=>({idle:true});
  const object=required(p,'object')(targetId),target=object&&required(p,'asObject')(object);
  if(!target)return idle();
  const area=required(p,'area')(actor);if(!area)return idle();
  if(!Number.isInteger(actor.perceptionUpdateFlags))throw new Error('Native combat step movement flags are unavailable');
  if(!(actor.perceptionUpdateFlags&2))return idle();
  const origin=position(actor),destination=position(target);
  const vector=origin.map((v,i)=>f(v-destination[i]));
  const x=vector[0],y=f(-vector[2]),z=vector[1];
  const squared=f(f(f(x*x)+f(y*y))+f(z*z)),distance=squared>0?f(Math.sqrt(squared)):0;
  const direction=normalizeOrientation(vector);
  let range=0,ranged=0,operation,preflighted=false;
  const preflight=async()=>{if(!preflighted){await p.preflightMovement?.(actor,area);preflighted=true;}};
  if(step<2){
    ranged=await required(p,'ranged')(actor);
    if(!Number.isInteger(ranged))throw new Error('Native combat step ranged state is unavailable');
    if(ranged===0)range=f(await required(p,'desiredRange')(actor,targetId,0));
    else{
      const creature=required(p,'asCreature')(target);
      if(!creature||await required(p,'ranged')(creature)!==0)range=f(await required(p,'desiredRange')(actor,targetId,1));
      else range=f(f(await required(p,'maximumRange')(creature,actor.id,0,0))+0.5);
    }
    if(f(range-0.25)>distance)operation='away';
    else if(ranged===1)return idle();
    else if(distance>f(range+0.25))operation='toward';
    else if(step===0)return idle();
    else{
      // An unavailable orbit implementation must fail before its rand draw.
      for(const name of ['asin','atan2','cos','sin','testDirectLine','updateSubareas','setPosition'])required(p,name);
      await preflight();
      const draw=required(p,'random').call(null);
      if(!Number.isInteger(draw))throw new Error('Native combat step random draw is unavailable');
      operation=draw%2===0?'orbitPlus':'orbitMinus';
    }
  }else if(step===2)operation='toward';
  else if(step===3)operation='away';
  else if(step===4)operation='orbitMinus';
  else if(step===5)operation='orbitPlus';
  else{await p.warning?.('Native warning: Error! Invalid combat step type!');return idle();}
  // Capabilities are checked before the dispatch owner removes a due action.
  // Geometry and object movement must be real implementations, not no-op hooks.
  for(const name of ['testDirectLine','updateSubareas','setPosition'])required(p,name);
  if(!actor.nativePathInfo)throw new Error('Native combat step path information is unavailable');
  await preflight();
  let point;
  if(operation==='away'||operation==='toward'){
    const scale=step<2?f(Math.min(f(0.8),operation==='away'?f(range-distance):f(distance-range))):f(0.8);
    const sign=operation==='away'?1:-1;
    point=origin.map((v,i)=>f(f(f(direction[i]*sign)*scale)+v));
  }else{
    const alpha=f(await required(p,'asin')(f(f(0.4)/distance)));
    const theta=f(await required(p,'atan2')(f(-direction[2]),direction[0]));
    const twice=f(alpha+alpha),twoPi=f(6.2831854820251465);
    let angle=operation==='orbitMinus'?f(theta-twice):f(theta+twice);
    if(operation==='orbitMinus'&&angle<0)angle=f(angle+twoPi);
    // Preserve native plus-branch reflection, rather than replacing it with
    // a conventional modulo wrap (1403e2c7f..1403e2c97).
    if(operation==='orbitPlus'&&angle>twoPi)angle=f(twoPi-angle);
    const cosine=f(await required(p,'cos')(angle)),sine=f(await required(p,'sin')(angle));
    point=[f(f(cosine*distance)+destination[0]),f(f(distance*0)+destination[1]),f(-f(f(sine*distance)+f(-destination[2])))];
  }
  return {idle:false,area,origin,point};
}
export async function applyCombatStep(actor,plan,p){
  const idle=async()=>{
    setRoundPaused(actor.combatRound,0,OBJECT_INVALID);setPauseTimer(actor.combatRound,0,0);
    await required(p,'setAnimation')(actor,1);return {moved:false};
  };
  if(plan.idle)return idle();
  const {area,origin,point}=plan;
  const path=actor.nativePathInfo,originalTarget=path.field28;
  // Area+280 retains this query's path info; only path+28 is restored.
  area.nativePathInfo280=path;path.field28=OBJECT_INVALID;
  let line;
  try{line=await p.testDirectLine(area,origin,point,path.field8,path.fieldC,0);}
  finally{path.field28=originalTarget;}
  if(!Number.isInteger(line))throw new Error('Native combat step direct-line result is unavailable');
  if(![area.width,area.height].every(Number.isInteger))throw new Error('Native combat step area dimensions are unavailable');
  const nativeY=f(-point[2]);
  if(point[0]<0||point[0]>f(f(area.width)*10)||nativeY<0||nativeY>f(f(area.height)*10)||line!==1)return idle();
  await p.updateSubareas(actor,origin,point,0,0,0);
  await p.setPosition(actor,point,0);return {moved:true,position:point};
}
export async function doCombatStep(actor,step,duration,targetId,p){
  return applyCombatStep(actor,await prepareCombatStep(actor,step,duration,targetId,p),p);
}
