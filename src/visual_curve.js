const f=Math.fround,half=2**63;
const view=(bytes,size)=>{if(!(bytes instanceof Uint8Array)||bytes.byteLength!==size)throw Error('Native visual curve storage is unavailable');return new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength);};
const integer=(v,n)=>{if(!Number.isInteger(v))throw Error('Native visual '+n+' is unavailable');return v|0;};
const cvtt64=value=>Number.isFinite(value)&&value>=-half&&value<half?BigInt(Math.trunc(value)):-(1n<<63n);
// Original unsigned FLOAT conversion, including the SSE out-of-range result.
const durationTicks=duration=>{
 let value=f(f(duration*1000)*1000),bias=0n;
 if(value>=half){value=f(value-half);if(value<half)bias=1n<<63n;}
 return BigInt.asUintN(64,cvtt64(value)+bias);
};

// Restart1402ea120..1402ea248, also reached by tail thunk1402ea110.
// The two timer domains occupy distinct slots. Equal endpoints/lerp0 and
// unknown timer types preserve existing clock slots. Clock/world-timer methods
// are explicit providers; the latter's independently ported owners are reused
// by the runtime adapter, rather than inferred calendar arithmetic here.
function* restartCurveSteps(bytes,p){
 const v=view(bytes,64);
 if(v.getInt32(12,true)===0||v.getFloat32(8,true)===v.getFloat32(4,true))return;
 const timer=v.getInt32(0,true),duration=v.getFloat32(16,true);
 if(timer===0){
  const now=BigInt.asUintN(64,BigInt(yield p.clock()));v.setBigUint64(32,now,true);
  v.setBigUint64(48,BigInt.asUintN(64,now+durationTicks(duration)),true);
 }else if(timer===1){
  const world=yield p.worldTimer();if(world===null)return;
  const delta=(yield p.worldSeconds(world,duration))>>>0,now=yield p.worldTime(world);
  v.setUint32(40,now.day,true);v.setUint32(44,now.time,true);
  const end=yield p.addWorld(world,now,{day:0,time:delta});
  if((end.status|0)===0){v.setUint32(56,end.day,true);v.setUint32(60,end.time,true);}
 }
}

// CVTSI2SS rounds directly from signed64. Avoid a double-round through Number
// for integer values just above a FLOAT halfway point.
const signedFloat=value=>{
 value=BigInt.asIntN(64,value);const sign=value<0n?-1:1,n=value<0n?-value:value,bits=n.toString(2).length;
 if(bits<=24)return Math.fround(sign*Number(n));const shift=BigInt(bits-24),top=n>>shift,tail=n-(top<<shift),half=1n<<(shift-1n);
 return Math.fround(sign*Number(top+BigInt(tail>half||tail===half&&(top&1n)!==0n))*2**Number(shift));
};
const unsignedDifferenceFloat=value=>{value=BigInt.asUintN(64,value);const signed=BigInt.asIntN(64,value),converted=signedFloat(signed);return signed<0n?Math.fround(converted+2**64):converted;};

// Complete LerpFloat::Progress1402e9cd0..2e9eee. Completion can decrement
// repeats, swap endpoints and refresh clocks on the SAME owned curve.
function* progressCurveSteps(bytes,p){
 const v=view(bytes,64),f=Math.fround;if(v.getInt32(12,true)===0)return f(1);
 if(v.getFloat32(20,true)<1){
  const timer=v.getInt32(0,true);let fraction;
  if(timer===0){
   const now=BigInt.asUintN(64,BigInt(yield p.clock())),end=v.getBigUint64(48,true);
   if(now<end){const total=unsignedDifferenceFloat(end-v.getBigUint64(32,true));if(total>0)fraction=f(unsignedDifferenceFloat(end-now)/total);}
  }else if(timer===1){
   const world=yield p.worldTimer();if(world===null)return f(1);
   const sampled=yield p.worldTime(world),now={day:integer(sampled.day,'world day')>>>0,time:integer(sampled.time,'world time')>>>0},end={day:v.getUint32(56,true),time:v.getUint32(60,true)};
   if(now.day<end.day||now.day===end.day&&now.time<end.time){
    const remaining=yield p.subtractWorld(world,end,now),total=yield p.subtractWorld(world,end,{day:v.getUint32(40,true),time:v.getUint32(44,true)});
    // Both native output pairs are zero-initialized; subtraction status is
    // ignored. A failed lower call that writes nothing retains those zeroes.
    const ticks=integer(total.time??((total.status|0)!==0?0:undefined),'world denominator')>>>0;
    if(ticks!==0)fraction=f(f(integer(remaining.time??((remaining.status|0)!==0?0:undefined),'world numerator')>>>0)/f(ticks));
   }
  }
  if(fraction!==undefined){const result=f(1-fraction);if(result!==1)return result;}
 }
 const repeats=v.getInt32(28,true);if(repeats!==-1){if(repeats<1)return f(1);v.setInt32(28,repeats-1,true);}
 if(v.getUint8(24)&1){const from=v.getUint32(8,true),to=v.getUint32(4,true);v.setUint32(8,to,true);v.setUint32(4,from,true);}
 yield* restartCurveSteps(bytes,p);return f(1);
}


// Both adapters execute the same native owner steps. The render adapter uses
// synchronous clock providers, avoiding Promise/microtask work per channel.
async function runAsync(steps){let s=steps.next();while(!s.done)s=steps.next(await s.value);return s.value;}
function runSync(steps){let s=steps.next();while(!s.done){if(s.value&&typeof s.value.then==='function')throw Error('Visual render clock provider must be synchronous');s=steps.next(s.value);}return s.value;}
export const restartVisualCurve=(bytes,p)=>runAsync(restartCurveSteps(bytes,p));
export const restartVisualCurveSync=(bytes,p)=>runSync(restartCurveSteps(bytes,p));
export const visualCurveProgress=(bytes,p)=>runAsync(progressCurveSteps(bytes,p));
export const visualCurveProgressSync=(bytes,p)=>runSync(progressCurveSteps(bytes,p));

// LerpFloat::Lerped1402e9a80. Progress can swap endpoints on repeat, so
// read ValueFrom/ValueTo after sampling it. Arithmetic mirrors FLOAT ops;
// sinf/cosf/asinf are provided by the host and validated within float tolerance.
export function sampleVisualCurveSync(bytes,p){
 return lerpedVisualCurveValue(bytes,()=>visualCurveProgressSync(bytes,p));
}
export function lerpedVisualCurveValue(bytes,progress){
 const v=view(bytes,64),type=v.getInt32(12,true);
 if(type===0)return v.getFloat32(4,true);
 let t=progress();
 if(t===0)return v.getFloat32(8,true);
 let to=v.getFloat32(4,true);if(t===1)return to;
 const from=v.getFloat32(8,true),span=f(to-from);
 switch(type){
  case 1:case 6:if(type===6)t=f(t*t);return f(f(span*t)+from);
  case 2:{let s=f(3-f(t*2));s=f(s*t);s=f(s*t);return f(f(s*span)+from);}
  case 3:{const u=Math.max(-1,Math.min(1,f(1-f(t+t)))),angle=f(Math.asin(u));t=f(.5-f(Math.sin(f(angle/3))));return f(f(t*span)+from);}
  case 4:t=f(Math.cos(f(f(t*f(Math.PI))*.5)));return f(f(f(1-t)*span)+from);
  case 5:t=f(Math.sin(f(f(t*f(Math.PI))*.5)));return f(f(t*span)+from);
  case 7:{let s=f(f(f(t*6)-15)*t);s=f(s+10);s=f(s*t);s=f(s*t);s=f(s*t);return f(f(s*span)+from);}
  default:return to;
 }
}
