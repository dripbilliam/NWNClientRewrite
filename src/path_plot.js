import { normalizeOrientation } from './combat_lifecycle.js';
import { OBJECT_INVALID } from './game_object_array.js';

const f=Math.fround;
const int=(path,offset)=>path.raw.getInt32(offset,true),uint=(path,offset)=>path.raw.getUint32(offset,true);
const float=(path,offset)=>path.raw.getFloat32(offset,true);
const setInt=(path,offset,value)=>path.raw.setInt32(offset,value,true);
const required=(p,name)=>{if(typeof p[name]!=='function')throw new Error(`Native path plot provider ${name} is unavailable`);return p[name];};
const result=v=>{if(!Number.isInteger(v))throw new Error('Native path plot result is unavailable');return v|0;};
const nativePoint=(path,offset)=>[float(path,offset),float(path,offset+4),float(path,offset+8)];
const renderPoint=point=>[point[0],point[2],-point[1]];
const normalize=point=>{const value=normalizeOrientation(renderPoint(point));return[value[0],-value[2],value[1]];};

// PlotPathInArea1404843e6..140484657. Search selection and retry cadence
// remain separate from the native tile/grid search owners. Never substitute
// an approximate route when an owner is unavailable.
export async function plotBlockedPath(path,budget,context,p){
  const {area,start:renderStart,end:renderEnd,radius,height,direct}=context;
  const start=[renderStart[0],-renderStart[2],renderStart[1]],end=[renderEnd[0],-renderEnd[2],renderEnd[1]];
  const actor=await required(p,'creature')(uint(path,0x24));
  let status=3;
  if(!actor||result(await required(p,'aiLevel')(actor))!==0){
    let threshold=100;
    budget>>>=0;
    if(uint(path,0x24)!==OBJECT_INVALID&&await required(p,'client')(uint(path,0x24))){
      const level=result(await required(p,'pathfindingLevel')())&255;
      if(level===0)budget=1000;
      else if(level===1){threshold=10;budget=7000;}
      else if(level===2){threshold=5;budget=12000;}
      else if(level===3){threshold=1;budget=50000;}
    }
    if(int(path,0x19c)===0&&direct!==-3){
      if(((direct+2)>>>0)<=1){
        setInt(path,0x19c,0);
        status=result(await required(p,'areaPlot')(area,path,budget));
        if(status===3&&int(path,0x2c)<threshold){
          const dx=f(end[0]-start[0]),dy=f(end[1]-start[1]);
          if(f(f(f(dy*dy)+f(dx*dx))+0)<400){setInt(path,0x19c,1);status=1;}
        }
      }
    }else{
      setInt(path,0x19c,1);
      status=result(await required(p,'gridPlot')(area,path,budget,direct===-3&&int(path,0x2c)>=threshold));
    }
    if(int(path,0x2c)>threshold&&status===1)status=3;
  }
  if(status!==3||int(path,0)!==0)return status;
  setInt(path,0x74,0);
  let fraction=f(.5),delta=f(.25),clear=false,last=start.slice();
  do{
    const candidate=[f(f(f(end[0]-start[0])*fraction)+start[0]),f(f(f(end[1]-start[1])*fraction)+start[1]),end[2]];
    if(result(await required(p,'directLine')(area,renderPoint(last),renderPoint(candidate),radius,height,1))===1){
      clear=true;last=candidate;fraction=f(fraction+delta);
    }else fraction=f(fraction-delta);
    delta=f(delta*f(.5));
  }while(f(.005)<delta);
  if(!clear)return status;
  setInt(path,0x7c,4);path.allocations.set(0x80,new Float32Array([start[0],start[1],last[0],last[1]]));return 2;
}

// FlipStartEndPoints140294150..14029418f: swap raw XYZ words and area IDs.
export function flipPathEndpoints(path){
  for(const [a,b] of [[0x4c,0x64],[0x50,0x68],[0x54,0x6c],[0x60,0x70]]){
    const saved=uint(path,a);path.raw.setUint32(a,uint(path,b),true);path.raw.setUint32(b,saved,true);
  }
}

// PlotPathInArea140483c90: direct segment, desired stop radius, optional
// fractional progress, cached direct-line result, and reverse-route commit.
// Native area/grid search is a separate required owner when direct LOS fails.
export async function plotPathInArea(path,budget,p){
  const start=nativePoint(path,0x64),goal=nativePoint(path,0x4c),radius=float(path,4),height=float(path,0xc);
  const area=await p.area(uint(path,0x70));if(!area)return 3;
  setInt(path,0x2c,(int(path,0x2c)+1)|0);area.nativePathInfo280=path;
  const stop=float(path,0x58);
  let end=goal.slice();
  if(stop>0){
    const dx=f(goal[0]-start[0]),dy=f(goal[1]-start[1]),dz=f(goal[2]-start[2]);
    const squared=f(f(f(dx*dx)+f(dy*dy))+f(dz*dz));
    end=start.slice();
    if(f(stop*stop)<squared){
      const direction=normalize(start.map((v,i)=>f(v-goal[i])));
      end=[f(f(stop*direction[0])+goal[0]),f(f(stop*direction[1])+goal[1]),goal[2]];
    }
  }
  let direct;
  if(int(path,0x2c)===1){
    if(start[0]===end[0]&&start[1]===end[1])direct=1;
    else{direct=result(await p.directLine(area,renderPoint(start),renderPoint(end),radius,height,1));setInt(path,0x1a4,direct);}
  }else direct=int(path,0x1a4);
  if(int(path,0x1a0)===1){
    if(direct!==1&&int(path,0x74)===0){
      let fraction=f(.5),delta=f(.25),clear=false,last=start.slice();
      do{
        const candidate=[f(f(f(end[0]-start[0])*fraction)+start[0]),f(f(f(end[1]-start[1])*fraction)+start[1]),goal[2]];
        if(result(await p.directLine(area,renderPoint(last),renderPoint(candidate),radius,height,1))===1){fraction=f(fraction+delta);clear=true;last=candidate;}
        else fraction=f(fraction-delta);
        delta=f(delta*f(.5));
      }while(f(.005)<delta);
      if(clear){direct=1;end=last;}else direct=-4;
    }
    setInt(path,0x19c,0);setInt(path,0x1a0,0);
  }
  let status;
  if(direct===1){
    setInt(path,0x7c,4);path.allocations.set(0x80,new Float32Array([start[0],start[1],end[0],end[1]]));status=2;
  }else if(direct===-4)status=3;
  else{
    const context={area,start:renderPoint(start),end:renderPoint(end),radius,height,direct};
    status=result(await (p.blocked? p.blocked(path,budget,context):plotBlockedPath(path,budget,context,p)));
  }
  if(status===2&&int(path,0x74)===1){
    const count=int(path,0x7c),source=path.allocations.get(0x80);
    if(!(source instanceof Float32Array)||count<0||count%2||source.length<count)throw new Error('Native reversed path allocation is unavailable');
    const reversed=new Float32Array(count);for(let i=0;i<count;i+=2){reversed[i]=source[count-2-i];reversed[i+1]=source[count-1-i];}
    path.allocations.set(0x80,reversed);setInt(path,0x74,0);flipPathEndpoints(path);
  }
  if(status===2||status===3)setInt(path,0x78,1);
  return status;
}

// CNWSModule::PlotPath140483a30..140483c80 and same-area
// PlotInterAreaPath140483600..140483a24. Preserve completed early return2.
export async function plotPath(path,budget,p){
  if(!path)return 3;
  if(int(path,0x48)===0&&int(path,0x78)===1)return 2;
  if(int(path,0x48)===1){
    if(int(path,0xa0)===1){await required(p,'resetInterTile')(path);await required(p,'resetGrid')(path);setInt(path,0xa0,0);}
    else{const reverse=int(path,0x74);path.resetInterArea();setInt(path,0x74,reverse);}
    setInt(path,0x2c,0);setInt(path,0x78,0);setInt(path,0x48,0);
  }
  await required(p,'markAI')(1);
  if(uint(path,0x60)!==uint(path,0x70))return result(await required(p,'interArea')(path,budget));
  if(!path.allocations.has(0xa8)){
    setInt(path,0x9c,1);setInt(path,0xa4,1);path.allocations.set(0xa8,new Uint32Array([uint(path,0x60)]));path.allocations.delete(0xb0);
  }
  const status=await plotPathInArea(path,budget,p);
  if(int(path,0xa4)>=2)return result(await required(p,'interAreaCompletion')(path,budget,status));
  return status;
}
