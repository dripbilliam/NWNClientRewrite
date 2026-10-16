import {OBJECT_INVALID} from './game_object_array.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native item input ${n} is unavailable`);return v|0;};
// HandlePlayerToServerInputMessage1404531b0, decoded subtype9 branch
// 14045360b..140453780. The native handler returns zero after processing;
// UseItem returns0 alone triggers feedback23. Packet scalar codec is separate.
export async function receiveItemInput(client,p){
 const object=p.clientObject(client);let actor=object?p.asCreature(object):null;
 if(actor&&integer(actor.nativeField8ac,'creature field8ac')!==0)actor=null;
 if(p.overflow()!==0)return 0;
 const id=p.readObjectId()>>>0,index=p.readByte()&255,variant=p.readBool()!==0?p.readByte()&255:0,
  targetId=p.readBool()===1?p.readObjectId()>>>0:OBJECT_INVALID,
  point=p.readBool()===1?[p.readFloat(),p.readFloat(),p.readFloat()].map(Math.fround):[0,0,0];
 if(p.overflow()!==0||p.underflow()!==0||!actor||actor.areaId===OBJECT_INVALID)return 0;
 const areaId=actor.areaId;await p.actionManager(actor,1);
 if(await p.use(actor,id,index,variant,targetId,point,areaId,1)===0)await p.feedback(actor,23);
 return 0;
}
