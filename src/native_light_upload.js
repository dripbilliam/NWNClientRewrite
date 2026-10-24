// PREPARED, UNVERIFIED candidate. No production imports. See
// evidence/native-enhanced-lighting-policy.md for the pinned binary/call sites.
// The power callback is an explicit native math boundary: Math.pow is useful
// for a candidate, but has not been proved bit-identical to the native CRT.
const f=Math.fround;
function power32(power,value,exponent){
 if(typeof power!=='function')throw new TypeError('An explicit power boundary is required');
 return f(power(f(value),f(exponent)));
}

// color_pow1400bf3e0: channels <=0, NaN, and exactly1 bypass the power helper.
// GetColorSpaceFromSRGB1400beb90 enables this with exponent2.2, not the standard
// piecewise sRGB transfer used by Three.Color.setRGB(...,SRGBColorSpace).
// Its four-component overload1400beb50 leaves alpha unchanged. This is the CPU
// upload path; the shader's signed ApplyColorSpace is a different operation.
export function nativeColorSpaceFromSrgb(color,{gammaCorrection,power}={}){
 return color.map((value,index)=>{value=f(value);return index<3&&gammaCorrection&&value>0&&value!==1?power32(power,value,2.2):value;});
}

// GetLightAdjustedColor14007f380. Preserve comparison order rather than clamp
// or normalize all colors; radius>=1000 and gamma-off bypass adjustment.
export function nativeLightAdjustedColor({color,radius},{gammaCorrection}={}){
 const result=color.map(f);
 if(!(f(radius)>=1000)&&gammaCorrection){
  let maximum=result[1]<result[2]?result[2]:result[1];
  if(!(maximum>result[0]))maximum=result[0];
  if(maximum>1&&maximum!==0){const reciprocal=f(1/maximum);for(let i=0;i<3;i++)result[i]=f(reciprocal*result[i]);}
 }
 return result;
}

// GetLightAdjustedRadius14007f480, including its different comparison order.
export function nativeLightAdjustedRange({color,radius,multiplier},{gammaCorrection,cutoffRangeMultiplier}={}){
 let result=f(radius);
 if(!(result>=1000)){
  result=f(result*f(multiplier));
  if(gammaCorrection){
   const rgb=color.map(f);let maximum=rgb[2]>rgb[1]?rgb[2]:rgb[1];
   if(!(maximum>rgb[0]))maximum=rgb[0];
   if(maximum>1)result=f(result*maximum);
   result=f(f(cutoffRangeMultiplier)*result);
  }
 }
 return result;
}

// SetLightGL140080c10 point-light property preparation, not admission/fading.
// Caller supplies the native fade parameter and already-mapped world position.
// Authored multiplier changes enhanced range, not an extra RGB intensity here.
// Area lights (slot-1), view rejection, slot enabling and headlight/fade owners
// are deliberately separate; this function cannot establish their membership.
export function nativePointLightUpload(light,policy){
 const rgb=light.color.map(value=>f(f(light.fade)*f(value))),ambient=(light.ambientOnly|0)!==0;
 let radius=f(.1);if(f(.1)<=f(light.radius))radius=f(light.radius);
 const square=f(radius*radius),quadraticAttenuation=f(9/f(square+square));
 let enhancedColor=null;
 if(policy.gammaCorrection){
  const adjusted=nativeLightAdjustedColor(light,policy).map(value=>f(f(light.fade)*value));
  const color=nativeColorSpaceFromSrgb(adjusted,policy),range=nativeLightAdjustedRange(light,policy);
  enhancedColor=[...color,f(f(range*range)*(ambient?-1:1))];
 }
 return {ambient:[...(ambient?rgb:[0,0,0]),1],diffuse:[...(ambient?[0,0,0]:rgb),1],
  position:[...light.position.map(f),1],quadraticAttenuation,enhancedColor};
}

// SetUniforms1400b8380, upload locations established by ConnectShaderData.
// Float operands follow the observed scalar instruction order. The callback
// still needs native-oracle validation for powf rounding and exceptional input.
export function nativeLightFalloffUniforms({gammaCorrection,cutoffRangeMultiplier,intensityAtRange,maxIntensity,power}){
 const cutoff=f(cutoffRangeMultiplier),at=f(intensityAtRange),maximum=f(maxIntensity);
 const atInv=gammaCorrection?power32(power,at,-2.2):f(1/at);
 const maxInv=gammaCorrection?power32(power,maximum,-2.2):f(1/maximum);
 return {lightFalloffFactor:f(f(atInv-maxInv)*f(cutoff*cutoff)),lightMaxIntensityInv:maxInv};
}
