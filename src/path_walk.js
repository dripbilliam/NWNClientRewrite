import { OBJECT_INVALID } from './game_object_array.js';
import { NativeIdList } from './native_id_list.js';
import { normalizeOrientation } from './combat_lifecycle.js';

const f=Math.fround;
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native path walk ${n} is unavailable`);return v|0;};
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native path walk provider ${n} is unavailable`);return p[n];};
const point=value=>{if(!Array.isArray(value)||value.length!==3||!value.every(Number.isFinite))throw new Error('Native path walk point is unavailable');return value.map(f);};
const native=point=>[point[0],-point[2],point[1]];
const render=point=>[point[0],point[2],-point[1]];
const magnitude=(x,y,z)=>{const squared=f(f(f(f(x*x)+f(y*y))+f(z*z)));return squared>0?f(Math.sqrt(squared)):0;};
function pathData(actor){
  const path=actor.nativePathInfo;if(!path)throw new Error('Native walk path information is unavailable');
  const count=path.raw.getInt32(0x7c,true),index=path.raw.getInt32(0x98,true),coordinates=path.allocations.get(0x80);
  if(count<0||index<0||count%2||index%2||index>count||!(coordinates instanceof Float32Array)||coordinates.length<count)throw new Error('Native walk waypoint allocation is unavailable');
  return{path,count,index,coordinates};
}
function writePoint(path,offset,value){native(value).forEach((v,i)=>path.raw.setFloat32(offset+i*4,v,true));}

// CutWaypointPath14038a500..14038a58d retains current position/orientation
// when a movement collision truncates the route. All raw neighbors survive.
export function cutWaypointPath(actor){
  const path=actor.nativePathInfo;if(!path)throw new Error('Native cut path information is unavailable');
  // Native only reads scalar cells; a creature can jump before it has ever
  // owned a waypoint allocation. Keep walk-only allocation validation separate.
  const count=path.raw.getInt32(0x7c,true),index=path.raw.getInt32(0x98,true);
  path.raw.setUint8(0x130,(path.raw.getUint8(0x130)+1)&255);path.raw.setInt32(0x128,1,true);path.raw.setInt32(0x12c,0,true);
  path.raw.setInt32(0x134,(count-index)>>1,true);writePoint(path,0x138,point(actor.position));writePoint(path,0x144,point(actor.orientation));
}

// WalkUpdateLocationTestDistance1403dc940..1403dcce5. Test object polygons
// before creatures; excluded target and shrunken radius are temporary. Native
// blocker events and friend bumping have their own providers, never guessed.
export async function testWalkDistance(actor,from,to,p){
  const area=await p.area(actor);if(!area)return 1;
  const path=actor.nativePathInfo,savedTarget=path.field28,savedRadius=path.field8;
  from=point(from);to=point(to);
  const low=f(Math.min(from[1],to[1])+f(-.1)),high=f(Math.max(from[1],to[1])+f(path.fieldC+f(.1)));
  const shrunk=f(savedRadius-f(.01));path.field28=OBJECT_INVALID;path.field8=shrunk<f(.01)?f(.01):shrunk;
  const polygon={id:OBJECT_INVALID},creature={id:OBJECT_INVALID};
  try{
    const clear=integer(await p.polygons(await p.area(actor),[from[0],from[2]],[to[0],to[2]],low,high,path.field4,path.fieldC8,polygon,1,null,0),'polygon result');
    if(clear!==0&&integer(await p.creatureLine(await p.area(actor),[from[0],from[2]],[to[0],to[2]],path,1,0,creature,0),'creature-line result')!==0)return 1;
    let blocker;
    if(creature.id===OBJECT_INVALID){
      if(clear!==0||polygon.id===OBJECT_INVALID)return 0;
      blocker=await p.door(polygon.id);if(!blocker||integer(blocker.animationState,'door animation')!==22)return 0;
    }else{
      blocker=await p.creature(creature.id);if(!blocker)return 0;
      path.field8=savedRadius;
      if(integer(await required(p,'bumpFriends')(actor,blocker,from,to),'bump-friends result')!==0){
        path.field8=shrunk<f(.01)?f(.01):shrunk;
        return Number(integer(await p.creatureLine(await p.area(actor),[from[0],from[2]],[to[0],to[2]],path,1,0,null,0),'recheck result')===1);
      }
    }
    await required(p,'blockedEvent')(blocker.id,actor.id,{scriptEvent:31});return 0;
  }finally{path.field28=savedTarget;path.field8=savedRadius;}
}

// WalkUpdateLocationDistance1403dc2e0..1403dc938. Travel across stored
// horizontal waypoint pairs with native f32 reciprocal/multiply. Accumulate
// ordered crossed-subarea IDs and compute actual tile heights for each test.
export async function walkDistance(actor,distance,out,crossed,p){
  let area=await p.area(actor);if(!area){await p.warning?.('NULL Area in WalkUpdateLocationDistance');return 0;}
  if(!(crossed instanceof NativeIdList))throw new Error('Native walk crossed-subarea storage is unavailable');
  let {path,count,index,coordinates}=pathData(actor);
  let current=native(point(actor.position)),orientation=native(point(actor.orientation)),originalOrientation=orientation.slice(),status=Number(index===count),lastLength=0,lastDirection=[0,0,0];
  out.orientation=render(orientation);
  distance=f(distance);if(!Number.isFinite(distance))throw new Error('Native walk distance is unavailable');
  while(index<count){
    const destination=[coordinates[index],coordinates[index+1],0];
    const dx=f(destination[0]-current[0]),dy=f(destination[1]-current[1]);
    const length=magnitude(dx,dy,0),inverse=f(1/Math.max(f(1e-9),length));
    const direction=[f(dx*inverse),f(dy*inverse),f(0*inverse)],travel=distance<=length?distance:length;
    const candidate=current.map((v,i)=>f(f(direction[i]*travel)+v));
    const testedFrom=current.slice(),testedTo=candidate.slice();
    testedFrom[2]=f(await p.height(area,render(testedFrom)));testedTo[2]=f(await p.height(area,render(testedTo)));
    if(integer(await p.testDistance(actor,render(testedFrom),render(testedTo)),'distance test')===0){
      area=await p.area(actor);if(area)current[2]=f(await p.height(area,render(current)));
      out.point=render(current);writePoint(path,0x4c,render(current));const currentArea=await p.area(actor);
      if(!currentArea)throw new Error('Native collision truncation area disappeared');path.raw.setUint32(0x60,currentArea.id,true);
      cutWaypointPath(actor);return 1;
    }
    lastLength=length;lastDirection=direction;
    if(distance<length){
      if(length>0){
        const destination=current.map((v,i)=>f(f(direction[i]*distance)+v));
        await p.crossings(area,render(current),render(destination),crossed);out.orientation=render(direction);current=destination;
      }
      status=0;break;
    }
    await p.crossings(area,render(current),render(destination),crossed);distance=f(distance-length);index+=2;path.raw.setInt32(0x98,index,true);current=destination;
    if(index===count){if(lastLength>0)out.orientation=render(lastDirection);status=1;break;}
  }
  if(count===4){
    const dx=f(coordinates[2]-f(actor.position[0])),dy=f(coordinates[3]-f(-actor.position[2]));
    if(f(f(f(dy*dy)+f(dx*dx))+0)<=1){
      const dot=f(f(out.orientation[0]*originalOrientation[0])+f(f(-out.orientation[2])*originalOrientation[1]));
      if(dot<f(-.707))out.orientation=[-out.orientation[0],0,-out.orientation[2]];
    }
  }
  area=await p.area(actor);if(area)current[2]=f(await p.height(await p.area(actor),render(current)));out.point=render(current);return status;
}

// WalkUpdateLocation1403dbd10..1403dc2dd: acceleration/braking, slope
// correction, panels, subareas, position, horizontal orientation, then end.
export async function walkPath(actor,group,p){
  const elapsed=integer(actor.nativeFrameElapsedD4,'elapsed time')>>>0;if(elapsed===0)return 1;
  const animation=integer(actor.animationState,'animation state');
  const rate=animation===2||animation===3?f(await p.rate(actor,0)):animation===4?f(await p.rate(actor,1)):0;
  if(!Number.isFinite(rate))throw new Error('Native path walk rate is unavailable');
  const {path,count,index,coordinates}=pathData(actor),from=point(actor.position);let remaining=0;
  for(let i=index;i<count;i+=2){
    const current=i===index?native(from):[coordinates[i-2],coordinates[i-1],0];
    remaining=f(remaining+magnitude(f(coordinates[i]-current[0]),f(coordinates[i+1]-current[1]),f(0-current[2])));
  }
  const stopping=f(f(rate*f(1000))/f(2000000)),old=f(actor.nativeAcceleration538),delta=f(f(elapsed)/f(1000));
  if(!Number.isFinite(old))throw new Error('Native acceleration factor is unavailable');
  let next=1;
  if(!(stopping<remaining)){
    const ratio=f(remaining/stopping);if(!Number.isFinite(ratio))throw new Error('Native movement acceleration exceptional input is unavailable');
    next=f((ratio>=f(.01)?f(Math.sqrt(ratio)):f(.1))-delta);
  }
  if(old<=1)next=Math.min(f(delta+old),next);next=Math.max(f(.1),next);
  let distance=f(f(f(f(old+next)*f(f(elapsed)*rate))*f(.5))/f(1000000));
  actor.nativeAcceleration538=next;
  const crossed=new NativeIdList(),out={point:[0,0,0],orientation:[0,0,0]},savedIndex=path.raw.getInt32(0x98,true);
  let status=integer(await p.walkDistance(actor,distance,out,crossed),'walk-distance result');
  const dz=f(out.point[1]-actor.position[1]);
  if(dz<=f(-.001)||dz>=f(.001)){
    const corrected=normalizeOrientation([distance,dz,0]);distance=f(distance*corrected[0]);path.raw.setInt32(0x98,savedIndex,true);
    status=integer(await p.walkDistance(actor,distance,out,crossed),'slope-corrected result');
  }
  await required(p,'closePanels')(actor,1);
  await p.updateSubareas(actor,point(actor.position),out.point.slice(),1,crossed,0);await p.setPosition(actor,out.point.slice(),0);
  await p.setOrientation(actor,normalizeOrientation([out.orientation[0],0,out.orientation[2]]));
  const target=await p.object(path.field28);
  if(target&&(target.objectType===7||target.objectType===10))return integer(await required(p,'transition')(actor,target,group,status),'transition result');
  if(status===1){path.resetAtEnd();await p.setAnimation(actor,0);return 2;}
  return 1;
}
