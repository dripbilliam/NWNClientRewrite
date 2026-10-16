const f=Math.fround;

// Complete InterpolateBezier14022ce00..14022ceb4. Preserve the original
// de Casteljau operation grouping and float32 rounding, including extrapolation.
export function interpolateModelBezier(a,b,c,d,t){
 [a,b,c,d,t]=[a,b,c,d,t].map(f);const u=f(1-t),middle=f(f(u*c)+f(d*t));
 const left=f(f(f(f(u*a)+f(c*t))*u)+f(middle*t));
 const right=f(f(f(f(u*d)+f(b*t))*t)+f(middle*u));
 return f(f(left*u)+f(right*t));
}

// Complete NewController::GetFloatValue1400512c0..140051466. Fields describe
// the runtime remapped NewController, not disk controller IDs. Reads beyond
// known resource storage must be supplied explicitly rather than invented.
export function sampleModelFloat(controller,time,node,output){
 const flags=controller.columnsA&255;if((flags&15)!==1)return 0;
 time=f(time);const rows=controller.rows4&65535,timeBase=controller.timeIndex6&65535,valueBase=controller.valueIndex8&65535;
 const read=index=>{if(index<0||index>=node.values88.length)throw new Error('Native model controller value storage is unavailable');return f(node.values88[index]);};
 let index=0,t=1;
 while(index<rows){if(!(time>read(timeBase+index)))break;index++;}
 if(index&&index!==rows)t=f(f(time-read(timeBase+index-1))/f(read(timeBase+index)-read(timeBase+index-1)));
 let value;
 if(index===0)value=read(valueBase);
 else if(index===rows){
  if((flags&240)===16){const at=((index-1)*3+valueBase)&65535;value=interpolateModelBezier(read(at),read(at+3),read(at+2),read(at+4),time);}
  else value=read(valueBase+rows-1);
 }else if((flags&240)===16){
  const at=((index-1)*3+valueBase)&65535,a=read(at),c=read(at+2);
  value=interpolateModelBezier(a,f(a+read(at+3)),c,f(c+read(at+4)),t);
 }else value=f(f(f(1-t)*read(valueBase+index-1))+f(t*read(valueBase+index)));
 output[0]=value;return 1;
}

// Complete GetVectorValue140051750..140051b0e. Only remapped position
// displacement0x10 consumes the caller's position_scale_factor. Native WORD
// wrap differs between linear element indexing and Bezier block indexing.
export function sampleModelVector(controller,time,node,output,positionScale){
 const flags=controller.columnsA&255;if((flags&15)!==3)return 0;
 time=f(time);const rows=controller.rows4&65535,timeBase=controller.timeIndex6&65535,valueBase=controller.valueIndex8&65535;
 const read=index=>{if(index<0||index>=node.values88.length)throw new Error('Native model controller value storage is unavailable');return f(node.values88[index]);};
 const scale=(controller.displacement0|0)===16?f(positionScale):1;
 let index=0,t=1;while(index<rows){if(!(time>read(timeBase+index)))break;index++;}
 if(index&&index!==rows)t=f(f(time-read(timeBase+index-1))/f(read(timeBase+index)-read(timeBase+index-1)));
 let values;
 if(index===0)values=[0,1,2].map(i=>f(read((valueBase+i)&65535)*scale));
 else if((flags&240)===16){
  const at=((index-1)*9+valueBase)&65535;
  values=[0,1,2].map(i=>{const a=read(at+i),b=read(at+9+i);return f(interpolateModelBezier(a,b,f(a+read(at+6+i)),f(b+read(at+12+i)),t)*scale);});
 }else{
  const at=((index-1)*3+valueBase)&65535;
  values=[0,1,2].map(i=>{const a=read((at+i)&65535);return f((index===rows?a:f(f(read((at+i+3)&65535)*t)+f(f(1-t)*a)))*scale);});
 }
 output.splice(0,3,...values);return 1;
}

// Complete quaternion slerp140231cd0..140231f37. Math library calls remain
// explicit providers; this owner does not normalize or use an epsilon. It
// flips the mutable LEFT input when the dot is negative, then recalculates.
export function interpolateModelQuaternion(left,right,time,p){
 time=f(time);const dot=()=>f(f(f(f(f(right[0])*f(left[0]))+f(f(right[1])*f(left[1])))+f(f(right[2])*f(left[2])))+f(f(right[3])*f(left[3])));
 if(dot()<0)for(let i=0;i<4;i++)left[i]=f(-f(left[i]));
 const cosine=dot();if(Math.abs(cosine)>=1)return left.map(f);
 const angle=f(p.acos(cosine));if(angle===0)return left.map(f);
 const scaled=f(angle*time),denominator=f(p.sin(angle)),b=f(f(p.sin(scaled))/denominator),a=f(f(p.sin(f(angle-scaled)))/denominator);
 return right.map((v,i)=>f(f(f(v)*b)+f(f(left[i])*a)));
}

// Complete GetQuaternionValue140051530..140051749. Runtime values remain
// authored x,y,z,w; the destination is native w,x,y,z. Unlike vector sampling,
// the four-component value index sum is not truncated to WORD.
export function sampleModelQuaternion(controller,time,node,output,p){
 if((controller.columnsA&15)!==4)return 0;
 time=f(time);const rows=controller.rows4&65535,timeBase=controller.timeIndex6&65535,valueBase=controller.valueIndex8&65535;
 const read=index=>{if(index<0||index>=node.values88.length)throw new Error('Native model controller value storage is unavailable');return f(node.values88[index]);};
 let index=0,t=1;while(index<rows){if(!(time>read(timeBase+index)))break;index++;}
 if(index&&index!==rows)t=f(f(time-read(timeBase+index-1))/f(read(timeBase+index)-read(timeBase+index-1)));
 const quaternion=at=>[read(at+3),read(at),read(at+1),read(at+2)];let value;
 if(!index)value=quaternion(valueBase);
 else if(index===rows)value=quaternion(valueBase+index*4-4);
 else value=interpolateModelQuaternion(quaternion(valueBase+index*4-4),quaternion(valueBase+index*4),t,p);
 output.splice(0,4,...value);return 1;
}
