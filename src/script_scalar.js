import {nativeCosf,nativeSinf} from './native_math.js';
// VectorConversions14054a9b0 uses FLOAT degree multiplication
// and CRT cosf/sinf, unlike the script cos/sin DOUBLE path below.
export function scriptAngleToVector(value){
  const radians=Math.fround(Math.fround(value)*Math.fround(0.01745329238474369));
  return [nativeCosf(radians),nativeSinf(radians),0];
}
// ExecuteCommandFloatToInt140313790 uses CVTTSS2SI: single precision,
// truncation toward zero, INT_MIN for nonfinite or out-of-range input.
export function scriptFloatToInt(value){
  value=Math.fround(value);
  return Number.isFinite(value)&&value>=-2147483648&&value<2147483648?Math.trunc(value)|0:-2147483648;
}

// ExecuteCommandIntToFloat140314080 MOVD/CVTDQ2PS converts signed INT to FLOAT.
export function scriptIntToFloat(value){
  if(!Number.isInteger(value))throw new Error('Native IntToFloat INT is unavailable');
  return Math.fround(value|0);
}

// ExecuteCommandMath140314240 case68. Unlike combat cosf, script cos
// promotes FLOAT degrees to DOUBLE, uses the native promoted-float radians
// constant, evaluates double cosine, then returns FLOAT. The bounded adapter
// matches original SSE libm captures; FMA/exception/large-range parity is open.
export function scriptCos(value){
  value=Math.fround(value);
  if(!Number.isFinite(value)||Math.abs(value)>1024)throw new Error('Native script cosine exceptional/large-angle branch is unavailable');
  return Math.fround(Math.cos(value*0.01745329238474369));
}
// Math case69 shares the same FLOAT→DOUBLE degree conversion and returns
// FLOAT after the original double CRT sine (separate from combat sinf).
export function scriptSin(value){
  value=Math.fround(value);
  if(!Number.isFinite(value)||Math.abs(value)>1024)throw new Error('Native script sine exceptional/large-angle branch is unavailable');
  return Math.fround(Math.sin(value*0.01745329238474369));
}

// ExecuteCommandMath140314240 ordinal74. COMISS/JBE returns zero for
// nonpositive/NaN FLOATs. Positive FLOAT is promoted to DOUBLE for CRT log,
// then narrowed once. Original SSE instructions validate finite inputs.
export function scriptLog(value){
  value=Math.fround(value);
  if(!(value>0))return 0;
  if(!Number.isFinite(value))throw new Error('Native script logarithm infinity/CRT exception owner is unavailable');
  return Math.fround(Math.log(value));
}
