import {OBJECT_INVALID} from './game_object_array.js';
import {normalizeOrientation} from './combat_lifecycle.js';

const f=Math.fround,raw=(n,i)=>n.parameterData[i]|0;
const float=(n,i)=>{const b=new DataView(new ArrayBuffer(4));b.setInt32(0,raw(n,i),true);return b.getFloat32(0,true);};
const normalize=v=>{const r=normalizeOrientation([v[0],v[2],f(-v[1])]);return[r[0],f(-r[2]),r[1]];};

async function allowed(o,p){
  if(await p.dead(o)===1||await p.dying(o)===1||!o.nativePathInfo)return 3;
  const client=await p.client(o.id),area=await p.area(o);
  return !area&&client&&o.nativeLastClientArea4f4!==OBJECT_INVALID?1:0;
}
async function prepare(o,p){
  const path=o.nativePathInfo;path.resetInterTile();path.resetGrid();
  await p.setAnimation(o,1);path.raw.setUint32(0x24,o.id,true);return path;
}
async function place(o,n,area,point,client,p){
  if(area===await p.area(o)){
    await p.setPosition(o,point,0);await p.subareas(o,point,area.id);
  }else{
    if(client)await p.subareas(o,point,OBJECT_INVALID);
    await p.addToArea(o,area,...point,0,1);
    if(!client)await p.subareas(o,point,area.id);
    else await p.front(o,60,n.groupId,[]);
  }
}
async function complete(o,n,straight,client,p){
  if(!client)for(let i=0;i<p.associates(o).length;i++){
    const associate=await p.creature(p.associates(o)[i]);
    if(associate)await p.front(associate,48,65535,[[3,o.id],[1,straight]]);
  }
  await p.front(o,4,n.groupId,[]);o.nativeField8f8=1;return 2;
}

// AIActionJumpToPoint1403c2a90..1403c37dc. All points here are native XYZ;
// action slots are read as raw DWORDs, independently of their type tags.
export async function executeJumpToPoint(o,n,p){
  const guard=await allowed(o,p);if(guard)return guard;
  if(!await p.area(o)&&await p.inLimbo(o.id))await p.removeLimbo(o.id);
  const point=[0,1,2].map(i=>float(n,i)),areaId=raw(n,3)>>>0,
    straight=n.parameterCount>4?raw(n,4):1,range=n.parameterCount>5?float(n,5):20,
    orientation=n.parameterCount>6?[float(n,6),float(n,7),0]:[...p.orientation(o).slice(0,2),0];
  const object=await p.lookup(areaId);if(!object||object.objectType!==4)return 3;
  const area=p.asArea(object),path=await prepare(o,p),out={point:[0,0,0]};
  if(await p.safeLocation(area,point,range,path,Number(straight!==0),out)!==1){path.resetInterArea();return 3;}
  await p.closePanels(o,0);await p.cutPath(o);
  const client=await p.internalClient(o.id);
  await place(o,n,area,out.point,client,p);
  await p.setOrientation(o,normalize(orientation));
  return complete(o,n,straight,client,p);
}

// AIActionJumpToObject1403c1a60..1403c2a8b. An out-of-area creature target
// supplies its pending area/position. Door opening is queued on the DOOR,
// retaining the original target-ID slot, before testing a safe landing.
export async function executeJumpToObject(o,n,p){
  const guard=await allowed(o,p);if(guard)return guard;
  const id=raw(n,0)>>>0,straight=n.parameterCount>1?raw(n,1):1,target=await p.object(id);
  if(!target||!p.asObject(target))return 3;
  let area=await p.area(p.asObject(target)),point,orientation;
  if(target.objectType===10){
    const door=p.asDoor(target),d=p.asDoor(target),position=p.position(door),facing=p.orientation(d),
      from=position.map((v,i)=>f(v-facing[i])),action=await p.doorPoint(door,from,1),radius=f(o.nativePathInfo.field8+o.nativePathInfo.field8);
    point=action.map((v,i)=>f(v-f(p.orientation(door)[i]*radius)));
    orientation=normalize(point.map((v,i)=>f(v-p.position(door)[i])));
    if(area&&(await p.openState(door)&255)===0)await p.front(door,20,65535,[[3,id]]);
  }else if(target.objectType===12){
    point=p.position(p.asObject(target)).slice();orientation=p.orientation(p.asObject(target)).slice();
  }else{
    point=p.position(target).slice();const position=p.position(p.asObject(target));
    orientation=normalize(position.map((v,i)=>f(v-point[i])));
  }
  if(!area){
    if(p.asCreature(target)){
      const creature=p.asCreature(target);area=await p.areaById(creature.nativeLastClientArea4f4);
      point=creature.nativePendingAreaPosition4f8.slice();
    }
    if(!area)return 3;
  }
  const path=await prepare(o,p),out={point:[0,0,0]};
  if(await p.safeLocation(area,point,20,path,straight,out)!==1){path.resetInterArea();return 3;}
  await p.closePanels(o,0);await p.cutPath(o);
  const client=await p.internalClient(o.id);
  await p.setOrientation(o,orientation);
  await place(o,n,area,out.point,client,p);
  return complete(o,n,straight,client,p);
}
