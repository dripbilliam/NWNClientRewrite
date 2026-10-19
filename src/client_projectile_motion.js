import {normalizeNativeVector} from './native_vector.js';
const f=Math.fround,sub=(a,b)=>a.map((v,i)=>f(v-b[i]));
const squared=v=>f(f(f(v[0]*v[0])+f(v[1]*v[1]))+f(v[2]*v[2]));

// CNWCProjectile1409845c0/1409848d0. Native XYZ, UINT milliseconds and
// scalar SSE rounding; callers own countdown/path advancement and model AI.
// No spell-ID selection belongs in motion. No allocation or registry mutation.
export function stepClientProjectileMotion(state,kind){
 if(kind!=='basic'&&kind!=='spiral')throw new Error(`Native projectile motion ${kind} is unavailable`);
 const position=state.position.map(f),endpoint=state.endpoint.map(f),delta=sub(endpoint,position),remaining=f(f(state.remaining>>>0)/1000),dt=f(f(state.elapsed>>>0)/1000);
 let velocity;
 if(kind==='basic'){
  const t2=f(remaining*remaining),scale=f(1/f(remaining+remaining));
  velocity=delta.map((v,i)=>f(f(f(v+v)-f(t2*f(state.acceleration[i])))*scale));
 }else{
  const perpendicular=(state.spiralSide&255)===0?[delta[1],f(-delta[0]),0]:[f(-delta[1]),delta[0],0],normal=normalizeNativeVector(perpendicular),scale=f(1/remaining);
  velocity=delta.map((v,i)=>f(f(v*scale)+f(normal[i]*7.5)));
 }
 let next=position.map((v,i)=>f(v+f(dt*velocity[i])));
 if(squared(sub(position,next))>squared(delta))next=endpoint;
 let direction=delta,orientation=null;
 const mode=state.facing&255;
 if(mode===1){
  if(!Array.isArray(state.attachment)||state.attachment.length!==3)throw new Error('Native projectile facing attachment is unavailable');
  direction=sub(state.attachment.map(f),next);
 }else if(mode===2)direction=sub(next,position);
 if(mode!==0&&squared(direction)>f(1e-10))orientation=normalizeNativeVector(direction);
 return{position:next,velocity,orientation};
}
