import {normalizeOrientation} from './combat_lifecycle.js';

const f=Math.fround,invalid=0x7f000000;
const native=v=>[f(v[0]),f(-v[2]),f(v[1])];
const squared=v=>f(f(f(v[0]*v[0])+f(v[1]*v[1]))+f(v[2]*v[2]));
const normalize=v=>native(normalizeOrientation([v[0],v[2],-v[1]]));

// Decoded WalkToWaypoint140455860..140455f43. Scalar packet decoding and
// client ownership are explicit providers; positions inside the packet use XYZ.
export async function receiveWalkInput(client,p){
  const areaId=p.readObjectId()>>>0,point=[p.readFloat(),p.readFloat(),p.readFloat()].map(f);
  const sequence=p.readByte()&255,run=p.readBool()|0,clientPath=p.readBool()|0,fractional=p.readByte()&255,targetId=p.readObjectId()>>>0;
  if(p.overflow()!==0||p.underflow()!==0)return 0;
  const object=p.clientObject(client),again=p.clientObject(client);
  if(!again||!object||!p.area(object))return 0;
  let actor=p.asCreature(p.clientObject(client));
  if(actor){
    actor=p.asCreature(p.clientObject(client));if(actor.nativeField8ac!==0)return 0;
    actor=p.asCreature(p.clientObject(client));const path=actor.nativePathInfo,offset=path.raw.getInt32(0x74,true)===0?0x4c:0x64;
    const stored=[0,4,8].map(i=>path.raw.getFloat32(offset+i,true));
    if(path.raw.getUint32(offset===0x4c?0x60:0x70,true)===areaId&&path.field28===targetId&&squared(point.map((v,i)=>f(v-stored[i])))<f(.01)){
      path.raw.setUint32(0x20,sequence,true);return 1;
    }
    path.resetAtEnd();if(fractional===1)path.field19c=1;
  }
  actor=p.asCreature(object);
  if(actor){
    actor=p.asCreature(object);
    if(squared(native(actor.position).map((v,i)=>f(v-point[i])))<f(2.25)&&(actor.creatureAnimation&255)===2){
      const target=p.object(actor.currentAITargetId);
      if(target&&p.asObject(target)){
        const other=p.asObject(target);
        if(other){
          await p.pause(actor,1,actor.id);await p.pauseTimer(actor,500,0);
          const origin=native(actor.position),toward=normalize(native(other.position).map((v,i)=>f(v-origin[i]))),direction=normalize(point.map((v,i)=>f(v-origin[i])));
          // Native455cf4 copies toward.z into direction.z before dot/cross.
          direction[2]=toward[2];
          const dot=f(f(f(toward[1]*direction[1])+f(toward[0]*direction[0]))+f(toward[2]*toward[2]));
          const cross=f(f(toward[0]*direction[1])-f(toward[1]*direction[0]));
          const step=dot>=f(.707)?2:dot<=f(-.707)?3:cross<0?5:4;
          await p.combatStep(actor,step,500,actor.currentAITargetId);
        }
      }
      return 1;
    }
  }
  actor=p.asCreature(object);
  if(actor&&actor.nativeFieldEc===1){
    await p.computeAIState(actor);const group=(actor.creatureAnimation&255)===1?65534:65535;
    if(await p.stickyModes()===0)await p.setMode(p.asCreature(object),0,1);
    await p.clearSpecial(p.asCreature(object).combatRound);
    await p.actionManager(p.asCreature(object),8);
    await p.addMove(p.asCreature(object),group,[point[0],point[2],f(-point[1])],areaId,targetId,run,0,0,clientPath,sequence,0,fractional,0,0);
  }
  return 1;
}
