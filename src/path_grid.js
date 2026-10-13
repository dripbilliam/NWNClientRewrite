import { pathInt as i,pathFloat as v,setPathInt as si,setPathFloat as sf,gridActivePaths,gridStepSize,
  nativeFastRsqrt,gridPathInfo,setGridPathInfo,gridPathPoints,createGridPath,gridPointSearched,setGridPointSearched,addGridPoint } from './path_grid_storage.js';

const f=Math.fround;
const required=(p,name)=>{if(typeof p[name]!=='function')throw new Error(`Native grid search provider ${name} is unavailable`);return p[name];};
const integer=value=>{if(!Number.isInteger(value))throw new Error('Native grid search integer is unavailable');return value|0;};
const trunc=value=>value>=-2147483648&&value<2147483648?Math.trunc(value):-2147483648;
const sq=(x,y)=>(Math.imul(x,x)+Math.imul(y,y))|0;
const render=point=>[point[0],0,-point[1]];
const line=async(area,a,b,path,p)=>integer(await required(p,'directLine')(area,render(a),render(b),v(path,4),v(path,0xc),1));
const clock=async p=>BigInt.asUintN(64,BigInt(await required(p,'microseconds')()));
const coordinates=(path,x,y)=>[
  f(f(f(v(path,0x15c)*f(x))+v(path,0x154))+f(v(path,0x164)*f(y))),
  f(f(f(v(path,0x160)*f(x))+v(path,0x158))+f(v(path,0x168)*f(y)))];

// GridSearchPathInDirection14036c4c0..14036c988. Its optional long probe
// tries the stop-tolerance point then bisects integer grid coordinates. The
// estimate deliberately uses native fast_rsqrt, including its truncation.
export async function gridSearchDirection(area,path,count,x,y,dx,dy,longProbe,out,p){
  out[0]=x;out[1]=y;
  let from=count===0?[v(path,0x64),v(path,0x68)]:coordinates(path,x,y);
  if(!longProbe){
    const next=[(x+dx)|0,(y+dy)|0];
    if(await line(area,from,coordinates(path,...next),path,p)===1){out[0]=next[0];out[1]=next[1];return true;}
    return false;
  }
  let tx=0,ty=0;
  const tolerance=i(path,0x5c);
  if(tolerance>=1){
    const ax=Math.abs(x),ay=Math.abs(y),ratio=f(ax<ay?f(x)/f(y):f(y)/f(x));
    const distance=f(nativeFastRsqrt(f(f(ratio*ratio)+1))*f(tolerance));
    const major=trunc(distance),minor=trunc(f(distance*ratio));
    tx=ax<ay?minor:major;ty=ax<ay?major:minor;
  }
  if(await line(area,from,coordinates(path,tx,ty),path,p)===1){out[0]=tx;out[1]=ty;return true;}
  let fraction=f(.5),delta=f(.25),clear=false;
  const deltaX=f((tx-x)|0),deltaY=f((ty-y)|0);
  do{
    const next=[(trunc(f(fraction*deltaX))+x)|0,(trunc(f(fraction*deltaY))+y)|0];
    if(next[0]!==x||next[1]!==y){
      const to=coordinates(path,...next);
      if(await line(area,from,to,path,p)===1){out[0]=next[0];out[1]=next[1];from=to;clear=true;fraction=f(fraction+delta);}
      else fraction=f(fraction-delta);
    }
    delta=f(delta*f(.5));
  }while(f(.005)<delta);
  return clear;
}

// GridSearchPath14036bf70..14036c495. Direction preference depends on
// endpoint slope, followed by alternating clockwise/counterclockwise probes.
export async function gridSearchPath(area,path,index,p){
  const original=gridPathInfo(path,index),count=original.getInt32(4,true),x=original.getInt32(12,true),y=original.getInt32(16,true);
  const slope=x===0?(y<0?-4:4):f(f(y)/f(Math.abs(x)));
  let direction=0,turn=-1;
  if(slope<-2){direction=4;turn=x<0?1:-1;}
  else if(slope<-.5){direction=x<0?3:-3;turn=(x<0?1:-1)*(slope<-1?1:-1);}
  else if(slope<.5){direction=x<0?2:-2;turn=(x<0?1:-1)*(slope<0?1:-1);}
  else if(slope<2){direction=x<0?1:-1;turn=direction*(slope<1?1:-1);}
  else turn=x<0?-1:1;
  const maxDistance=sq((i(path,0x150)-count+36)|0,0),out=[0,0];
  let sides=0,advanced=false;
  for(let probe=0;probe<8&&area.nativeGridStopped2b4===0;probe++){
    const side=(probe%2)+1;
    if(probe!==0&&probe!==7&&(sides&side)!==0)continue;
    let code=direction+(probe%2*2-1)*Math.trunc((probe+1)/2)*turn;
    if(code>4)code-=8;else if(code<-3)code+=8;
    const [dx,dy]=new Map([[-3,[-1,1]],[-2,[-1,0]],[-1,[-1,-1]],[0,[0,-1]],
      [1,[1,-1]],[2,[1,0]],[3,[1,1]],[4,[0,1]]]).get(code);
    const nx=(x+dx)|0,ny=(y+dy)|0;
    if(sq(nx,ny)>maxDistance)continue;
    if(gridPointSearched(path,nx,ny)){if(probe>0)sides|=side;continue;}
    const clear=await gridSearchDirection(area,path,count,x,y,dx,dy,false,out,p);
    if(clear&&probe===0&&(x!==dx||y!==dy))await gridSearchDirection(area,path,count,out[0],out[1],dx,dy,true,out,p);
    area.nativeGridProbes2b8=(area.nativeGridProbes2b8+1)|0;
    if(area.nativeGridProbes2b8%20===0&&BigInt.asUintN(64,await clock(p)-path.raw.getBigUint64(0x1c0,true))>path.raw.getBigUint64(0x1c8,true))
      area.nativeGridStopped2b4=1;
    if(!clear)continue;
    if(probe>0)sides|=side;
    if(advanced){
      if(probe!==7){
        const branch=createGridPath(path);
        if(branch!==-1){gridPathPoints(path,branch).set(gridPathPoints(path,index).subarray(0,count*2));
          setGridPathInfo(path,branch,original);addGridPoint(path,branch,out[0],out[1],1);return;}
      }
      break;
    }
    addGridPoint(path,index,out[0],out[1],1);advanced=true;
    if(probe===0)return;
  }
  if(!advanced&&area.nativeGridStopped2b4===0){original.setUint8(20,1);setGridPathInfo(path,index,original);}
}

// PlotGridPath14036f510..14036fc6b. Persist pending paths across frames,
// choose the first strictly closest open path, and keep native budget probes.
export async function plotGridPath(area,path,budget,forcePartial,p){
  await required(p,'markGridAI')(1);area.nativePathInfo280=path;
  if(i(path,0x60)!==i(path,0x70))return 3;
  const sx=v(path,0x64),sy=v(path,0x68),gx=v(path,0x4c),gy=v(path,0x50),step=gridStepSize(path);
  const dx=f(sx-gx),dy=f(sy-gy),lengthSquared=f(f(dx*dx)+f(dy*dy));
  let nx=1,ny=0;
  if(lengthSquared===1){nx=dx;ny=dy;}
  else if(lengthSquared>0){const factor=f(Math.sqrt(f(1/lengthSquared)));nx=f(dx*factor);ny=f(dy*factor);}
  const axisX=f(step*nx),axisY=f(step*ny),negativeX=f(-axisX);
  const magnitude=lengthSquared===1?1:lengthSquared>0?f(Math.sqrt(lengthSquared)):0;
  const span=trunc(f(magnitude/step)+.5);
  let bestBefore,capacity;
  if(gridActivePaths(path)<1){
    capacity=(Math.trunc(span/4)+36)|0;bestBefore=Math.imul(span,span);
    if(capacity<1||span<0||capacity*2>10000000)throw new Error('Native grid search allocation exceeds supported bounds');
    for(const [offset,value] of [[0x180,sx],[0x184,sy],[0x154,gx],[0x158,gy],[0x15c,axisY],[0x160,negativeX],[0x164,axisX],[0x168,axisY]])sf(path,offset,value);
    si(path,0x17c,capacity);si(path,0x150,span);si(path,0x198,bestBefore);si(path,0x188,0);si(path,0x178,0);
    path.allocations.set(0x170,new Int32Array(capacity*2));path.allocations.set(0x190,new Int32Array(capacity*2));
    path.allocations.set(0x1e0,new DataView(new ArrayBuffer(0x300)));path.allocations.set(0x1d0,Array(32));
    const first=createGridPath(path),searchedLength=Math.imul((span-1+capacity*2)|0,(capacity*2-1)|0);
    if(searchedLength<0||searchedLength>100000000)throw new Error('Native searched-grid allocation exceeds supported bounds');
    path.allocations.set(0x1b0,new Uint8Array(searchedLength));si(path,0x1b8,capacity-1);si(path,0x1bc,capacity-1);
    setGridPointSearched(path,0,span,1);addGridPoint(path,first,0,span,1);
  }else{bestBefore=i(path,0x198);capacity=i(path,0x17c);}
  path.raw.setBigUint64(0x1c0,await clock(p),true);path.raw.setBigUint64(0x1c8,BigInt.asUintN(64,BigInt(budget)),true);
  area.nativeGridStopped2b4=0;area.nativeGridProbes2b8=0;si(path,0x1c,1);
  let status=3,chosenDistance=1000000;
  while(area.nativeGridStopped2b4===0){
    let index=-1;chosenDistance=1000000;
    for(let n=0;n<gridActivePaths(path);n++){
      const record=gridPathInfo(path,n);
      if(record.getUint8(20)!==1&&record.getInt32(0,true)<chosenDistance&&record.getInt32(4,true)<capacity){
        index=n;chosenDistance=record.getInt32(0,true);
      }
    }
    if(index===-1)break;
    await gridSearchPath(area,path,index,p);
    const record=gridPathInfo(path,index),count=record.getInt32(4,true),tolerance=i(path,0x5c);
    if(record.getInt32(0,true)<=0||sq(record.getInt32(12,true),record.getInt32(16,true))<=Math.imul(tolerance,tolerance)){
      si(path,0x178,count);path.allocations.get(0x170).set(gridPathPoints(path,index).subarray(0,count*2));status=2;break;
    }
  }
  if(status!==2){
    if(!forcePartial&&area.nativeGridStopped2b4!==0&&i(path,0x198)<bestBefore){si(path,0x198,chosenDistance);status=1;}
    else if(i(path,0x1c)!==0&&i(path,0x188)>1&&i(path,0x74)!==1){
      const count=i(path,0x188);si(path,0x178,count);path.allocations.get(0x170).set(path.allocations.get(0x190).subarray(0,count*2));status=2;
    }
  }
  if(status===2){
    const count=i(path,0x178),points=path.allocations.get(0x170),out=new Float32Array(count*2);
    let current=[sx,sy],written=1;out[0]=sx;out[1]=sy;
    // Native uses this call's computed basis, even on resumed searches.
    const point=(x,y)=>[f(f(f(axisY*f(x))+gx)+f(axisX*f(y))),f(f(f(negativeX*f(x))+gy)+f(axisY*f(y)))];
    for(let n=1;n<count;n++){
      if(n>=count-1||await line(area,current,point(points[n*2+2],points[n*2+3]),path,p)!==1){
        current=point(points[n*2],points[n*2+1]);out[written*2]=current[0];out[written*2+1]=current[1];written++;
      }
    }
    path.allocations.set(0x90,out);si(path,0x88,written*2);
    await required(p,'smooth')(area,path);
  }
  if(status!==1)path.resetGrid();return status;
}
