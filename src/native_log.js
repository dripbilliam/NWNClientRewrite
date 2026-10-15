import {nativeLogTable as tables} from './native_log_table.js';
const f=Math.fround,view=new DataView(new ArrayBuffer(4));
const raw=v=>{view.setFloat32(0,v,true);return view.getUint32(0,true);};
const value=v=>{view.setUint32(0,v>>>0,true);return view.getFloat32(0,true);};
// Exact finite float32 multiply-add, with one nearest-even rounding. The
// logarithm's intermediates are normal, but subnormal output rounds correctly.
function fused(a,b,c){
  const parts=v=>{const r=raw(v),e=r>>>23&255,m=BigInt(r&0x7fffff)|(e?0x800000n:0n);
    return{m:r>>>31?-m:m,e:e?e-150:-149};};
  const x=parts(a),y=parts(b),z=parts(c),pe=x.e+y.e,lo=Math.min(pe,z.e);
  let n=(x.m*y.m<<BigInt(pe-lo))+(z.m<<BigInt(z.e-lo));
  if(n===0n)return 0;
  const negative=n<0n;if(negative)n=-n;
  const shift=Math.max(0,n.toString(2).length-24,-149-lo);
  if(shift){const k=BigInt(shift),q=n>>k,rem=n-(q<<k),half=1n<<(k-1n);
    n=q+BigInt(rem>half||rem===half&&(q&1n)!==0n);}
  const result=f(Number(n)*2**(lo+shift));return negative?-result:result;
}
// Original CRT logf140c946b0. Evaluate SSE and FMA CPU branches separately;
// callers may compare final gameplay outputs without guessing CPU dispatch.
// Exceptional negative/NaN/Infinity inputs and CRT errno/status are not mapped.
export function nativeLogfBranches(input){
  const x=f(input);
  if(x===0)return[-Infinity,-Infinity];
  if(!Number.isFinite(x)||x<0)throw new Error('Native logf exceptional input/status owner is unavailable');
  return[logBranch(x,false),logBranch(x,true)];
}
function logBranch(x,isFused){
  let r=raw(x),e=(r>>>23)-127,m=r&0x7fffff;
  const difference=f(x-1);
  if(e!==-127&&Math.abs(difference)<f(.0625)){
    const q=f(difference/f(2+difference)),correction=f(difference*q),u=f(q+q),u2=f(u*u),u3=f(u*u2);
    const polynomial=isFused?fused(u2,f(.0125),f(1/12)):f(f(u2*f(.0125))+f(1/12));
    return f(difference+(isFused?fused(polynomial,u3,-correction):f(f(polynomial*u3)-correction)));
  }
  if(e===-127){r=raw(f(value(m|0x3f800000)-1));e=(r>>>23)-253;m=r&0x7fffff;}
  const rounded=(m&0x7f0000)+((m&0x8000)<<1),index=rounded>>>16;
  const q=f(f(value(rounded|0x3f000000)-value(m|0x3f000000))*tables.inverse[index]),q2=f(q*q);
  const polynomial=isFused?fused(f(1/3),q,f(.5)):f(f(q*f(1/3))+f(.5));
  const residual=isFused?fused(polynomial,q2,q):f(q+f(polynomial*q2));
  const low=f((isFused?fused(f(3.194618329871446e-5),e,-residual):f(f(f(3.194618329871446e-5)*e)-residual))+tables.tail[index]);
  const high=isFused?fused(f(.693115234375),e,tables.head[index]):f(f(f(.693115234375)*e)+tables.head[index]);
  return f(high+low);
}
