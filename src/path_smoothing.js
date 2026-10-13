import { pathInt as i,pathFloat as v,setPathInt as si } from './path_grid_storage.js';
const f=Math.fround;
const render=point=>[point[0],0,-point[1]];
const line=async(area,path,a,b,p)=>{
  if(typeof p.directLine!=='function')throw new Error('Native route smoothing direct-line provider is unavailable');
  const result=await p.directLine(area,render(a),render(b),v(path,4),v(path,0xc),1);
  if(!Number.isInteger(result))throw new Error('Native smoothing direct-line result is unavailable');return result|0;
};
const length=(dx,dy)=>f(Math.sqrt(f(f(dx*dx)+f(dy*dy))));
const validate=(points,count)=>{
  if(!(points instanceof Float32Array)||count<2||count%2||count>points.length)
    throw new Error('Native route smoothing source allocation is unavailable');
};
// SmoothSelectNodes1403717b0. Optional subdivision uses a double1.1
// threshold and subtracts double1.0 from the rounded single step remainder.
// Visibility selection tries the farthest node, halves failures above4,
// then decrements. Keep the reverse subdivision stack and its exact order.
export async function smoothSelectNodes(area,path,source,count,subdivide,select,p){
  validate(source,count);
  const result=[source[0],source[1]];let current=0,stack=null,remaining=-1;
  const last=(count-1)>>1;
  while(current<last||remaining>0){
    let jump=0;
    if(select===1){
      let probe=(count>>1)-current-1;
      while(probe>0){
        if(await line(area,path,result.slice(-2),[source[(current+probe)*2],source[(current+probe)*2+1]],p)===1){jump+=probe;probe=0;}
        probe=probe<=4?probe-1:probe>>1;
      }
    }else jump=Number(remaining<1);
    current+=jump;
    let point=[source[current*2],source[current*2+1]];
    if(jump===0){
      if(remaining<1){current++;point=[source[current*2],source[current*2+1]];}
      else{point=stack.slice((remaining-1)*2,remaining*2);remaining--;}
    }else{stack=null;remaining=0;}
    if(subdivide!==0){
      const from=result.slice(-2),distance=length(f(from[0]-point[0]),f(from[1]-point[1]));
      if(distance>=1.1){
        stack=[];remaining=0;
        const dx=f(point[0]-from[0]),dy=f(point[1]-from[1]);
        for(let step=distance;step>0;step=f(step-1)){
          stack.push(f(f(f(dx*step)/distance)+from[0]),f(f(f(dy*step)/distance)+from[1]));remaining++;
        }
        if(remaining>0){point=stack.slice(-2);remaining--;}
      }
    }
    result.push(...point);
    if(result.length>10000000)throw new Error('Native smoothed route exceeds supported bounds');
  }
  return new Float32Array(result);
}
// ComputeBestCorner140369ef0. Native outgoing and incoming length sums
// use Y-square before X-square, unlike the route subdivision above.
export async function computeBestCorner(area,path,a,b,c,p){
  const outgoing=[f(c[0]-b[0]),f(c[1]-b[1])],incoming=[f(b[0]-a[0]),f(b[1]-a[1])];
  const l2=f(Math.sqrt(f(f(outgoing[1]*outgoing[1])+f(outgoing[0]*outgoing[0]))));
  const l1=f(Math.sqrt(f(f(incoming[1]*incoming[1])+f(incoming[0]*incoming[0]))));
  if(l1<f(.0001)||l2<f(.0001))return null;
  const dot=f(f(incoming[1]*outgoing[1])+f(incoming[0]*outgoing[0]));
  if(f(dot/f(l1*l2))>=f(.9))return null;
  const shortest=Math.min(l1,l2);let first=true,fraction=f(.5),delta=f(.25),best=null;
  while(first||f(delta*shortest)>f(.1)){
    const distance=f(fraction*shortest);
    const from=[f(f(f(f(a[0]-b[0])*distance)/l1)+b[0]),f(f(f(f(a[1]-b[1])*distance)/l1)+b[1])];
    const to=[f(f(f(distance*outgoing[0])/l2)+b[0]),f(f(f(distance*outgoing[1])/l2)+b[1])];
    if(await line(area,path,from,to,p)===1){best=[from,to];fraction=f(fraction+delta);}
    else fraction=f(fraction-delta);
    first=false;delta=f(delta*f(.5));
  }
  return best;
}
// SmoothCornerOptimize140371100 has up to four replacement points per
// original corner. It retains the next original corner for the following pass.
export async function smoothCornerOptimize(area,path,source,count,p){
  validate(source,count);const result=[source[0],source[1]];
  for(let offset=2;offset<count-2;offset+=2){
    const previous=result.slice(-2),middle=[source[offset],source[offset+1]],next=[source[offset+2],source[offset+3]];
    const first=await computeBestCorner(area,path,previous,middle,next,p);
    if(!first){result.push(...middle);continue;}
    const second=await computeBestCorner(area,path,previous,first[0],first[1],p);
    if(second){
      const third=await computeBestCorner(area,path,second[1],first[1],next,p);
      result.push(...second[0],...second[1]);
      if(third)result.push(...third[0],...third[1]);else result.push(...first[1]);
    }else{
      const third=await computeBestCorner(area,path,first[0],first[1],next,p);
      result.push(...first[0]);
      if(third)result.push(...third[0],...third[1]);else result.push(...first[1]);
    }
  }
  if(count>2)result.push(source[count-2],source[count-1]);return new Float32Array(result);
}
// SmoothPointsOnPath140371560..1403717a6: three selection passes followed
// by corner optimization. +14==1 copies raw native XY words directly.
export async function smoothPath(area,path,p){
  path.allocations.delete(0x80);path.raw.setBigUint64(0x80,0n,true);si(path,0x7c,0);
  const count=i(path,0x88),source=path.allocations.get(0x90);
  if(count===0)return 1;
  validate(source,count);
  let result;
  if(i(path,0x14)===1)result=new Float32Array(source.buffer.slice(source.byteOffset,source.byteOffset+count*4));
  else{
    let selected=await smoothSelectNodes(area,path,source,count,1,0,p);
    selected=await smoothSelectNodes(area,path,selected,selected.length,1,1,p);
    selected=await smoothSelectNodes(area,path,selected,selected.length,0,1,p);
    result=await smoothCornerOptimize(area,path,selected,selected.length,p);
  }
  path.allocations.set(0x80,result);si(path,0x7c,result.length);return 1;
}
