import {scriptFloatToInt as cvtt} from './script_scalar.js';
import {nativeSinf,nativeCosf} from './native_math.js';
import {nativeFastRsqrt} from './path_grid_storage.js';
import {particleQuaternionBasis,particleQuaternionZ,multiplyParticleQuaternion,crossParticleVector} from './particle_math.js';
const f=Math.fround,BYTE_SCALE=f(255.99000549316406);
const call=(p,name,...args)=>{if(typeof p?.[name]!=='function')throw new Error(`Native particle draw provider ${name} is unavailable`);return p[name](...args);};
const clamp=v=>v>1?1:v<0?0:v;
const mix=(start,end,t)=>f(f(t*end)+f(f(1-t)*start));
const byte=v=>Math.trunc(v)&255;
const rgba=(color,alpha)=>(byte(alpha)<<24|byte(color[2])<<16|byte(color[1])<<8|byte(color[0]))>>>0;
const halfSize=(factor,value)=>f(f(factor*f(value))*f(.5));

// CPU portion of RenderStandard1400643b0 ->140062900..14006416c. All seven
// render modes share this implementation (the native Linked/MotionBlur entry
// stubs also jump here). Material/shader/stream calls are adapter boundaries;
// output retains the original packed 24-byte vertices and six-vertex order.
export function buildParticleVertices(e,p){
  if(e.source50?.instance&&1>f(e.source50.instance.fade)||e.instance100&&1>f(e.instance100.fade))return null;
  const mode=e.renderMode1a8,list=e.active188.records,count=list.length-(mode===3?1:0),life=f(e.lifeExp);
  if(count<1||life===0)return null;
  const factor=e.source50?f(call(p,'sourceFactor',e.source50)):1,camera=call(p,'cameraQuaternion').map(f),splat=!!(e.flags&512),tinted=!!(e.flags&8);
  let orientation=mode===1?e.quaternion1d0.map(f):mode===2?[1,0,0,0]:camera;
  const axis=mode===2?[0,0,1]:particleQuaternionZ(orientation),cameraBasis=particleQuaternionBasis(camera),cameraX=cameraBasis.slice(0,3),cameraY=cameraBasis.slice(3,6);
  let upright=1;
  if(mode===4){const [w,x,y,z]=camera;const direction=f(f(f(f(1-f(f(f(w*w)+f(x*x))*2))*0)+f(f(f(f(x*y)-f(z*w))*2)*0))+f(f(f(w*y)+f(x*z))*2));if(direction<0)upright=-1;}
  const lifeScale=e.ageMode1cc===0?f(1/f(list.length)):life>0?f(1/life):f(.01);
  const xGrid=e.xGrid===0?1:e.xGrid|0,yGrid=e.yGrid===0?1:e.yGrid|0,atlas=xGrid>1||yGrid>1,dx=f(1/f(xGrid)),dy=f(1/f(yGrid));
  const instance=e.instance100??e.source50?.instance;let elevation=1;
  if(instance&&f(f(e.position1e0[2])-f(instance.height50))>f(e.elevationThreshold))elevation=f(instance.opacity70);
  const opacity=e.source50?f(e.source50.opacity108):1,tint=tinted?call(p,'lightColor',e.position1e0.slice()).map(f):[1,1,1];
  const colorStart=e.colorStart.map((v,i)=>f(clamp(f(f(v)*tint[i]))*BYTE_SCALE)),varyColor=life>0&&e.colorStart.some((v,i)=>f(v)!==f(e.colorEnd[i]));
  const colorEnd=varyColor?e.colorEnd.map((v,i)=>f(clamp(f(f(v)*tint[i]))*BYTE_SCALE)):colorStart;
  const alphaStart=f(clamp(f(f(elevation*f(e.alphaStart))*opacity))*BYTE_SCALE),varyAlpha=life>0&&f(e.alphaStart)!==f(e.alphaEnd),alphaEnd=varyAlpha?f(clamp(f(f(elevation*f(e.alphaEnd))*opacity))*BYTE_SCALE):alphaStart;
  const start=halfSize(factor,e.sizeStart),varySize=life>0&&f(e.sizeStart)!==f(e.sizeEnd)&&!splat,end=varySize||splat?halfSize(factor,e.sizeEnd):start;
  const startY=halfSize(factor,e.sizeStartY),varyY=life>0&&f(e.sizeStartY)!==f(e.sizeEndY)&&!splat,endY=varyY||splat?halfSize(factor,e.sizeEndY):startY;
  const maximumSize=Math.max(start,end,startY,endY),buffer=new ArrayBuffer(count*6*24),view=new DataView(buffer);
  const write=(index,color,position,u,v)=>{const offset=index*24;view.setUint32(offset,color,true);for(let i=0;i<3;i++)view.setFloat32(offset+4+i*4,position[i],true);view.setFloat32(offset+16,u,true);view.setFloat32(offset+20,v,true);};
  const sine=p.sineFloat??nativeSinf,cosine=p.cosineFloat??nativeCosf;
  for(let index=0;index<count;index++){
    const particle=list[index],age=f(particle.age),t=life>0?Math.min(1,f((e.ageMode1cc===0?f(index):age)*lifeScale)):0;
    const color=varyColor?colorStart.map((v,i)=>mix(v,colorEnd[i],t)):colorStart;
    const alpha=varyAlpha?mix(alphaStart,alphaEnd,t):alphaStart;
    let width=varySize?mix(start,end,t):start,height=varyY?mix(startY,endY,t):f(e.sizeStartY)!==0?startY:width;
    if(splat&&particle.stopped70){width=end;height=f(e.sizeEndY)!==0?endY:end;}
    let head=particle.position10.map(f),tail=[...head],x,y,tailColor=rgba(color,alpha);
    if(mode===6||mode===3){
      if(mode===6)tail=particle.trail64.map(f);else head=list[index+1].position10.map(f);
      const travel=head.map((v,i)=>f(v-tail[i])),dotX=f(f(f(cameraX[1]*travel[1])+f(cameraX[0]*travel[0]))+f(cameraX[2]*travel[2])),dotY=f(f(f(cameraY[1]*travel[1])+f(cameraY[0]*travel[0]))+f(cameraY[2]*travel[2]));
      const inverse=nativeFastRsqrt(f(f(dotY*dotY)+f(dotX*dotX))),px=f(dotX*inverse),py=f(dotY*inverse);
      x=cameraX.map((v,i)=>f(f(v*py)-f(cameraY[i]*px)));y=cameraY.map((v,i)=>f(f(v*py)+f(cameraX[i]*px)));
      width=f(width*2);height=f(height*.5);
      if(mode===6)tailColor=rgba(color,f(Math.min(1,f(inverse*width))*alpha));
    }else if(mode===5){const basis=particleQuaternionBasis(particle.quaternion34);x=basis.slice(0,3);y=basis.slice(6,9);}
    else{
      const angle=f(f(particle.rotation1c)*f(.5)),s=sine(angle),c=cosine(angle),rotationAxis=particle.stopped70?particle.direction4c:axis;
      const quaternion=multiplyParticleQuaternion([c,...rotationAxis.map(v=>f(f(v)*s))],particle.stopped70?particle.quaternion34:orientation);
      x=particleQuaternionBasis(quaternion).slice(0,3);
      y=mode===4?[0,0,upright]:crossParticleVector(splat?particle.direction4c:axis,x);
    }
    x=x.map(v=>f(width*v));y=y.map(v=>f(height*v));
    let u0=0,u1=1,v0=0,v1=1;
    if(atlas){
      const interval=f(e.fps)>0?f(1/f(e.fps)):0,elapsed=f(age-f(particle.field48));
      if(interval!==0&&f(e.frameStart)!==f(e.frameEnd)&&elapsed>=interval){
        const steps=cvtt(f(elapsed/interval));
        if(f(e.frameStart)>f(e.frameEnd)){particle.frame44=(particle.frame44-steps)|0;if(f(e.frameEnd)>f(particle.frame44))particle.frame44=cvtt(e.frameStart);}
        else{particle.frame44=(particle.frame44+steps)|0;if(f(particle.frame44)>f(e.frameEnd))particle.frame44=cvtt(e.frameStart);}
        particle.field48=age;
      }
      const frame=f(particle.frame44),row=f(Math.floor(f(frame*dx)));v1=f(1-f(row*dy));u0=f(f(frame-f(f(xGrid)*row))*dx);v0=f(v1-dy);u1=f(u0+dx);
    }
    const packed=rgba(color,alpha),a=head.map((v,i)=>f(f(v+x[i])+y[i])),b=head.map((v,i)=>f(f(v-x[i])+y[i])),c=tail.map((v,i)=>f(f(v+x[i])-y[i])),d=tail.map((v,i)=>f(f(v-x[i])-y[i])),base=index*6;
    write(base,packed,a,u1,v1);write(base+1,packed,b,u0,v1);write(base+2,tailColor,c,u1,v0);write(base+3,tailColor,c,u1,v0);write(base+4,packed,b,u0,v1);write(base+5,tailColor,d,u0,v0);
  }
  const softInverse=splat||mode===1||mode===2||!(maximumSize>0)?0:f(1/Math.min(f(.2),f(maximumSize*f(.2))));
  return{buffer,count:count*6,softInverse,blendMode:e.blendMode68,twoSided:!!e.twoSided};
}
