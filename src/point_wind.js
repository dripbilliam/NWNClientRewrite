import {normalizeParticleVector} from './particle_math.js';
const f=Math.fround;

// PointSourceWind records only: WindManager's ambient/noise fields, scene
// registration and frame scheduling remain separate native owners.
export const createPointWindList=()=>({records:[],capacity:0});
// Full AddPointSourceWind1400f1250 (allocation is backing storage, no game ID).
export function addPointWind(list,position,radius,duration,strength){
 if(list.records.length===list.capacity)list.capacity=list.capacity===0?16:Math.imul(list.capacity,2);
 list.records.push({position:position.map(f),radius:f(radius),duration:f(duration),remaining:f(duration),strength:f(strength)});
}
// Point-array portion of updateTimer1400f2250, 1400f2403..1400f24ac.
// Exact zero survives; negative time removes and shifts, rechecking that slot.
export function advancePointWinds(list,delta){
 delta=f(delta);
 for(let i=0;i<list.records.length;i++){
  const wind=list.records[i];wind.remaining=f(wind.remaining-delta);
  if(wind.remaining<0){list.records.splice(i,1);i--;}
 }
}
// Complete pointSourceWindVector1400f2070. Center uses normalize's native
// zero-vector fallback (+X); boundary is strict. Strength does not fade with
// remaining lifetime. GetGlobalPointWind1400f1530 ignores its float argument.
export function pointWindVector(list,position){
 const result=[0,0,0],point=position.map(f);
 for(const wind of list.records){
  const radius=f(wind.radius),d=point.map((v,i)=>f(v-f(wind.position[i])));
  if(d.some(v=>Math.abs(v)>radius))continue;
  const squared=f(f(f(d[1]*d[1])+f(d[0]*d[0]))+f(d[2]*d[2]));
  if(!(squared<f(radius*radius)))continue;
  const distance=f(Math.sqrt(squared)),reciprocal=f(1/distance),unit=normalizeParticleVector(distance===0?d:d.map(v=>f(v*reciprocal)));
  const scale=f(f(f(radius-distance)*f(wind.strength))/radius);
  for(let i=0;i<3;i++)result[i]=f(result[i]+f(scale*unit[i]));
 }
 return result;
}
