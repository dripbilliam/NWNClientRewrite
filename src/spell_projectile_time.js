import {OBJECT_INVALID} from './game_object_array.js';
import {nativeLogfBranches} from './native_log.js';
const f=Math.fround;
const required=(p,n)=>{if(typeof p?.[n]!=='function')throw new Error(`Native spell projectile provider ${n} is unavailable`);return p[n];};
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native spell projectile ${n} is unavailable`);return v|0;};
const magnitude=v=>{const squared=f(f(f(v[0]*v[0])+f(v[1]*v[1]))+f(v[2]*v[2]));return squared>0?f(Math.sqrt(squared)):0;};
const cvttLow=value=>Number.isFinite(value)&&value>=-(2**63)&&value<2**63?Math.trunc(value)|0:0;
// CalculateLastSpellProjectileTime14048fe20. Native positions are XYZ;
// +140's low BYTE selects a path, but the tail compares its full INT to6.
// No projectile, or an exact-one carried/equipped item lookup, skips travel.
export function calculateSpellProjectileTime(actor,path,p){
  const spell=required(p,'spell')(integer(actor.nativeSpellId218,'current spell ID'));
  if(!spell)return;
  const store=time=>{actor.nativeSpellProjectileTime220=time|0;};
  if(integer(spell.useProjectile,'projectile flag')===0){store(0);return;}
  if(required(p,'asCreature')(actor)){
    const item=required(p,'item')(actor.nativeSpellTarget214>>>0);
    if(item&&(required(p,'inRepository')(actor,item)===1||required(p,'equipped')(actor,item)===1)){store(0);return;}
  }
  let vector=[0,0,0],destination;
  if((integer(actor.nativeSpellTarget214,'target ID')>>>0)===OBJECT_INVALID)destination=actor.nativeSpellPoint208;
  else{const target=required(p,'object')(actor.nativeSpellTarget214>>>0);if(target)destination=required(p,'position')(target);}
  if(destination){
    const from=required(p,'position')(actor);
    if(![destination,from].every(v=>Array.isArray(v)&&v.length===3&&v.every(Number.isFinite)))throw new Error('Native spell projectile positions are unavailable');
    vector=destination.map((v,i)=>f(f(v)-f(from[i])));
  }
  const distance=magnitude(vector),logs=(p.logBranches??nativeLogfBranches)(distance);
  if(distance===0)p.zeroLogStatus?.(actor); // output is known; CRT errno/status is a separate boundary.
  const requested=integer(path,'path')&255,defaultPath=integer(spell.projectilePath,'default path');
  const selected=requested===0?defaultPath&255:requested;
  const results=logs.map(log=>{
    let speed=f(f(log*f(3))+f(2));
    if(selected===1)speed=f(speed+speed);
    else if(selected===3)return 2000;
    else if(selected===5)speed=f(speed*f(1.5));
    else if(selected===7)speed=f(distance*f(.5));
    else if(selected===8)speed=f(speed*f(.8));
    if(speed<=0)return 1;
    const time=cvttLow(f(f(distance/speed)*f(1000)));
    return defaultPath===6?(time+2500)|0:time;
  });
  if(!results.length||results.some(value=>value!==results[0]))throw Object.assign(new Error('Native spell projectile CPU dispatch produces different travel times'),{diagnosticContext:{distance,path:selected,results}});
  store(results[0]);
}
