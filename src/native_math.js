import { nativeAtanTable } from './native_atan_table.js';

const f = Math.fround;
const bits = new DataView(new ArrayBuffer(8));
const PI4 = 0.7853981633974483, INV_PI2 = 0.6366197723675814;
const PI2_HI = 1.5707963267341256, PI2_LO = 6.077100506506192e-11;
const PI2_HI2 = 6.077100506303966e-11, PI2_LO2 = 2.0222662487959506e-21;
const C = [0.041666666666666664, -0.0013888888888888887, 0.000024801587301587298, -2.755731922398589e-7];
const S = [-0.16666666666666666, 0.008333333333333333, -0.0001984126984126984, 0.0000027557319223985893];

// Bounded, finite float32 branches of native CRT cosf140c7ac70 and
// sinf140c7a2b0. Both SSE and FMA dispatch paths are evaluated: unknown
// process CPU-dispatch state may not silently select a different float32.
// Large-angle remainder helpers and floating exception/errno state remain
// unmapped. Geometry angles outside this verified branch fail explicitly.
export function nativeCosf(value) { return nativeTrig(value, true); }
export function nativeSinf(value) { return nativeTrig(value, false); }

// atanf140c94418..140c945f8. Input is float32, reduction/polynomial
// use SSE doubles, then one CVTSD2SS. NaN/CRT exception flags stay diagnosed.
export function nativeAtanf(value){
  value=f(value);
  if(Number.isNaN(value))throw new Error('Native atanf NaN/CRT exception state is not implemented');
  const negative=value<0||Object.is(value,-0);let x=Math.abs(value),offset=0;
  if(x<.4375){}
  else if(x<.6875){offset=.4636476090008061;x=(x+x-1)/(x+2);}
  else if(x<1.1875){offset=.7853981633974483;x=(x-1)/(x+1);}
  else if(x<2.4375){offset=.982793723247329;x=(x-1.5)/(x*1.5+1);}
  else if(x>5512405943901487000)return negative?-f(1.5707963267948966):f(1.5707963267948966);
  else{offset=1.5707963267948966;x=-1/x;}
  const square=x*x;
  const numerator=((square*.004706779342861492+.19232454640210858)*square+.2965285988192392)*(square*x);
  const denominator=(square*.2993096999596597+1.1107249999539954)*square+.8895857968624323;
  const output=offset-(numerator/denominator-x);
  return f(negative?-output:output);
}

// CRT asinf140c7a9a8..140c7abc4, finite domain only. Every mulss/addss/
// subss/divss rounds separately. The truncated root is a bit operation,
// not a numeric integer conversion. Floating status/errno is not emulated.
export function nativeAsinf(value) {
  value = f(value);
  if (!Number.isFinite(value) || Math.abs(value) > 1) throw new Error('Native asinf exceptional input branch is not implemented');
  const absolute = Math.abs(value);
  bits.setFloat32(0, absolute, true);
  const exp = bits.getUint32(0, true) >>> 23;
  if (exp < 0x71) return value;
  if (absolute === 1) return value < 0 ? -f(1.5707963705062866) : f(1.5707963705062866);
  const z = exp < 0x7e ? f(absolute * absolute) : f(f(1 - absolute) * 0.5);
  let r = f(-0.013381929136812687 - f(z * 0.003961374517530203));
  r = f(f(r * z) - 0.05652986839413643);
  r = f(f(r * z) + 0.18416160345077515);
  r = f(f(r * z) / f(1.1049696207046509 - f(z * 0.8364112973213196)));
  let output;
  if (exp < 0x7e) output = f(f(r * absolute) + absolute);
  else {
    const root = f(Math.sqrt(z));
    bits.setFloat32(0, root, true); bits.setUint32(0, bits.getUint32(0, true) & 0xffff0000, true);
    const split = bits.getFloat32(0, true), c = f(f(z - f(split * split)) / f(split + root));
    const correction = f(f(f(root * 2) * r) - f(7.549789415861596e-08 - f(c + c)));
    output = f(0.7853981256484985 - f(correction - f(0.7853981256484985 - f(split * 2))));
  }
  return value < 0 ? -output : output;
}

// CRT atan2f140c8f29c..140c8f6ac. Inputs become doubles before exponent
// comparison/ratio/table reduction; only the final result becomes float32.
// Signed zero, axes and very unequal magnitudes follow the native branches.
export function nativeAtan2f(y, x) {
  y = f(y); x = f(x);
  if (![x, y].every(Number.isFinite)) throw new Error('Native atan2f exceptional input branch is not implemented');
  const negativeX = x < 0 || Object.is(x, -0), negativeY = y < 0 || Object.is(y, -0);
  const pi = f(3.141592653589793), halfPi = f(1.5707963267948966);
  if (y === 0) return negativeX ? (negativeY ? -pi : pi) : y;
  const delta = exponent(y) - exponent(x);
  if (x === 0 && negativeY) return -halfPi;
  if (delta > 26) return negativeY ? -halfPi : halfPi;
  if (delta < -13 && !negativeX) {
    if (delta < -150) return negativeY ? -0 : 0;
    if (delta < -126) {
      // Scaled-ratio exponent adjustment140c8f3fd..140c8f468. For finite
      // float32 arguments this double is normal and its exponent exceeds100.
      bits.setFloat64(0, (y * 2 ** 100) / x, true);
      const raw = bits.getBigUint64(0, true);
      bits.setBigUint64(0, raw - (100n << 52n), true);
      return f(bits.getFloat64(0, true));
    }
    return f(y / x);
  }
  if (delta < -26 && negativeX) return negativeY ? -pi : pi;
  const ax = Math.abs(x), ay = Math.abs(y), swapped = ax < ay;
  const low = swapped ? ax : ay, high = swapped ? ay : ax;
  let angle = low / high;
  if (angle > 0.0625) {
    const index = Math.trunc(angle * 256 + 0.5);
    const residual = (low * 256 - index * high) / (index * low + high * 256);
    angle = (residual + nativeAtanTable[index - 16]) - ((residual * residual) * residual) * 0.33333333333224097;
  } else if (angle >= 0.0001) {
    const square = angle * angle;
    angle -= (0.3333333333333317 - (0.19999999999393223 - square * 0.1428571356180717) * square) * (square * angle);
  }
  if (swapped) angle = 1.5707963267948966 - angle;
  if (negativeX) angle = 3.141592653589793 - angle;
  if (negativeY) angle = -angle;
  return f(angle);
}
function nativeTrig(value, cosine) {
  value = f(value);
  if (!Number.isFinite(value) || Math.abs(value) > 32) throw new Error('Native trigonometric input branch is not implemented');
  const sse = trigBranch(value, cosine, false), fused = trigBranch(value, cosine, true);
  if (!Object.is(sse, fused)) throw Object.assign(new Error('Native trigonometric CPU dispatch produces different float32 results'), { sse, fused, input: value });
  return sse;
}
function trigBranch(value, cosine, fused) {
  const absolute = Math.abs(value);
  if (!cosine && absolute < 0.0001220703125) return value;
  if (absolute <= PI4) {
    if (absolute < 0.0078125) {
      if (!cosine) return f(fused ? fma64(-(value * value * value), 1/6, value) : value - (value * value * value) * (1/6));
      if (fused) return absolute < 0.0001220703125 ? 1 : f(fma64(-(value * .5), value, 1));
    }
    return f(polynomial(value, cosine, fused));
  }
  const quadrant = Math.trunc(fused ? fma64(absolute, INV_PI2, .5) : absolute * INV_PI2 + .5);
  let reduced;
  if (fused) reduced = fma64(-quadrant, PI2_HI, absolute) - quadrant * PI2_LO;
  else {
    const first = absolute - PI2_HI * quadrant;
    reduced = first - PI2_LO * quadrant;
    if (exponent(absolute) - exponent(reduced) > 15) {
      const next = first - PI2_HI2 * quadrant;
      reduced = next - (PI2_LO2 * quadrant - ((first - next) - PI2_HI2 * quadrant));
    }
  }
  const useCosine = cosine ? (quadrant & 1) === 0 : (quadrant & 1) !== 0;
  let result;
  // The SSE reduction path selects its small-remainder branch using the
  // first reduction's exponent (before the cancellation correction).
  const smallExponent = exponent((absolute - PI2_HI * quadrant) - PI2_LO * quadrant);
  if (!fused && smallExponent < 1010) {
    result = smallExponent <= 990 ? (useCosine ? 1 : reduced)
      : useCosine ? 1 - (reduced * reduced) * .5 : reduced - ((1/6) * reduced) * (reduced * reduced);
  } else result = polynomial(reduced, useCosine, fused);
  const negate = cosine ? ((quadrant + 1) & 2) !== 0 : ((quadrant >> 1) & 1) !== Number(value < 0);
  if (negate) result = -result;
  return f(result);
}
function polynomial(value, cosine, fused) {
  const square = value * value, fourth = square * square;
  const coefficients = cosine ? C : S;
  let correction;
  if (fused) {
    correction = fma64(coefficients[3], square, coefficients[2]);
    correction = fma64(correction, square, coefficients[1]);
    correction = fma64(correction, square, coefficients[0]);
    return cosine ? fma64(correction, fourth, 1 - square * .5) : fma64(correction, value * square, value);
  }
  correction = (coefficients[3] * square + coefficients[2]) * fourth + (coefficients[1] * square + coefficients[0]);
  return cosine ? (-.5 * square + 1) + correction * fourth : value + correction * (value * square);
}
function exponent(value) { bits.setFloat64(0, value, true); return Number((bits.getBigUint64(0, true) >> 52n) & 2047n); }

// Exact finite binary64 multiply-add for the bounded normal results above.
// BigInt retains the full product before a single nearest-even conversion;
// converting an intermediate JS multiplication would introduce two rounds.
function fma64(a, b, c) {
  function parts(value) {
    bits.setFloat64(0, value, true);
    const raw = bits.getBigUint64(0, true), exp = Number(raw >> 52n & 2047n);
    const magnitude = (raw & 0xfffffffffffffn) | (exp === 0 ? 0n : 0x10000000000000n);
    return { integer: raw >> 63n ? -magnitude : magnitude, exponent: exp === 0 ? -1074 : exp - 1075 };
  }
  const x = parts(a), y = parts(b), z = parts(c);
  const product = x.integer * y.integer, productExponent = x.exponent + y.exponent;
  const low = Math.min(productExponent, z.exponent);
  let integer = (product << BigInt(productExponent - low)) + (z.integer << BigInt(z.exponent - low));
  if (integer === 0n) return 0;
  const negative = integer < 0n; if (negative) integer = -integer;
  // Round the exact integer to53 significant bits, then scale by a power
  // of two. The math branches using this helper have normal f64 outputs.
  const shift = Math.max(0, integer.toString(2).length - 53);
  if (shift) {
    const count = BigInt(shift), truncated = integer >> count;
    const remainder = integer - (truncated << count), half = 1n << (count - 1n);
    integer = truncated + BigInt(remainder > half || remainder === half && (truncated & 1n) !== 0n);
  }
  const result = Number(integer) * 2 ** (low + shift);
  return negative ? -result : result;
}
