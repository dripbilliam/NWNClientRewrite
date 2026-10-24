const f=Math.fround,signed16=value=>value<<16>>16;
const rows={R:[109,112,115],G:[110,113,116],Y:[111,114,117],W:[237,238,239]};

// SpawnHitVisuals80bb10 mode1. Native table row constants encode damage
// categories; the active visualeffects table still supplies every model name.
export function selectClientBloodVisual(actor,record,p){
 if(p.kind(actor)===1)return null;
 let violence=p.violence(),large=[3,10].includes(record.result)||((record.attackType-867)>>>0)<2||record.killingBlow===1;
 const blood=p.blood(actor);if(blood==='N')return null;if(!blood){p.warning('missing-blood');return null;}
 if(record.weaponAttackType===7)violence=0;
 let level;
 if(violence===0||violence===2)level=large?2:signed16(record.damage)<Math.trunc(signed16(p.maximum(actor))/10)?0:1;
 else if(violence===1)level=large?1:0;
 else{p.warning('unknown-violence');return '';}
 const ids=rows[blood==='W'||p.whiteOverride(actor)?'W':blood];if(!ids)return '';
 let row=ids[level];if(violence===0){const low=p.lowViolence(row);if(low.found)row=low.value;}
 return p.modelName(row);
}

// The three physical slots are retained until reuse or creature destruction.
// Animation disappearance, not a guessed timer/particle count, frees a slot.
export function clientBloodSlot(slots,p){
 for(let i=0;i<3;i++)if(!slots[i])return i;else if(p.playInfo(slots[i],'impact')===-1){p.destroy(slots[i]);slots[i]=null;return i;}
 return -1;
}

export function normalizeBloodDirection(vector){
 const [x,y,z]=vector.map(f),square=f(f(f(x*x)+f(y*y))+f(z*z));
 if(square===1||square>=f(.99999)&&square<=f(1.00001))return[x,y,z];
 if(square===0)return[1,0,0];const reciprocal=f(Math.sqrt(f(1/square)));return[f(x*reciprocal),f(y*reciprocal),f(z*reciprocal)];
}

const floatBits=new Float32Array(1),uintBits=new Uint32Array(floatBits.buffer);
const bits=x=>{floatBits[0]=x;return uintBits[0];},fromBits=x=>{uintBits[0]=x;return floatBits[0];};
// The shipped float acos polynomial (c79a38), preserving SSE float stores.
// FP status/errno are outside this rendering helper; domain errors remain NaN.
export function bloodAcos(value){
 const x=f(value),word=bits(x),exponent=word>>>23&255;
 if(Number.isNaN(x)||Math.abs(x)>1)return NaN;
 if(exponent<0x65)return f(Math.PI/2);
 if(exponent>=0x7f)return x===1?0:f(Math.PI);
 let a=Math.abs(x),r;if(exponent<0x7e)r=f(a*a);else{r=f(f(1-a)*f(.5));a=f(Math.sqrt(r));}
 const numerator=f(f(f(f(f(f(-.013381929)-f(r*f(.0039613745)))*r)-f(.05652987))*r)+f(.1841616));
 const p=f(f(numerator*r)/f(f(1.1049696)-f(r*f(.8364113))));
 if(exponent>0x7d){
  if(x<0){const z=f(p*a)-6.123233995736766e-17+a;return f(Math.PI-(z+z));}
  const high=fromBits(bits(a)&0xffff0000),correction=f(f(r-f(high*high))/f(high+a));
  return f(f(f(f(a+a)*p)+f(correction+correction))+f(high*2));
 }
 return f(Math.PI/2-(x-(6.123233995736766e-17-f(p*x))));
}

export function clientBloodQuaternion(facing,direction,animation,weaponType){
 const face=facing.map(f),toward=normalizeBloodDirection(direction),dot=f(f(f(face[1]*toward[1])+f(face[0]*toward[0]))+f(face[2]*toward[2]));
 let angle=bloodAcos(dot>=1?1:dot);const normFace=normalizeBloodDirection(face),cross=f(f(f(direction[0])*normFace[1])-f(normFace[0]*f(direction[1]))),negative=cross<0;
 const slash=[1,3,4].includes(weaponType),pierce=[2,5].includes(weaponType);
 if((animation&65535)===200||((animation&65535)===201)){
  let offset=0;if(slash)offset=negative?-1:1;else if(pierce)offset=negative?1:-1;
  if((animation&65535)===201)offset=-offset;if(offset)angle=f(angle+f(offset*f(Math.PI/4)));
 }
 if(!negative)angle=f(-angle);
 const half=f(angle*f(.5)),cx=f(Math.cos(f(.5))),sx=f(Math.sin(f(.5))),cz=f(Math.cos(half)),sz=f(Math.sin(half));
 // Original axis-Z(angle) * axis-X(1), in native [w,x,y,z] order.
 return[f(cz*cx),f(sx*cz),f(sz*sx),f(sz*cx)];
}
