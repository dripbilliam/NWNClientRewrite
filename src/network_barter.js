import {NativeMessageWriter} from './native_message.js';
import {OBJECT_INVALID} from './game_object_array.js';
const uint=v=>Number.isInteger(v)&&v>=0&&v<=0xffffffff;
const boolean=v=>[false,true,0,1].includes(v);
// Original client7ba070..7ba480 and server443810 dispatch, message35.
export function barterRequest({operation,targetId=OBJECT_INVALID,itemId=OBJECT_INVALID,value=false,x=255,y=255}){
 const minors={start:1,close:3,add:5,remove:6,lock:7,accept:9,window:12,move:13},minor=minors[operation];
 if(minor===undefined||!uint(targetId)||!uint(itemId)||!boolean(value)||![x,y].every(v=>Number.isInteger(v)&&v>=0&&v<=255))throw Error('Invalid native barter request');
 const w=new NativeMessageWriter(1);w.create(operation==='start'?8:['add','remove','move'].includes(operation)?6:4,0xffffffff,1);
 if(operation==='start'){w.writeObjectIdClient(targetId);w.writeObjectIdClient(itemId);}
 else if(['add','remove','move'].includes(operation)){w.writeObjectIdClient(itemId);w.writeByte(x);w.writeByte(y);}
 else w.writeBool(operation==='close'?1:Number(value));
 w.setPrefix(Uint8Array.of(112,35,minor));return Uint8Array.from(w.getWriteMessage().data);
}
// Original client7701a0..770ac0: first BOOL names the initiating side; the
// second is that side's new value. It is not a pair of participant states.
export function readNetworkBarter(r,minor){
 if(minor===2)return{kind:'barter-start',firstId:r.readObjectIdClient(),secondId:r.readObjectIdClient()};
 if(minor===4)return{kind:'barter-close',completed:Boolean(r.readBool())};
 if(minor===8||minor===10)return{kind:minor===8?'barter-lock':'barter-accept',initiator:Boolean(r.readBool()),value:Boolean(r.readBool())};
 if(minor===11)return{kind:'barter-reject',operation:r.readByte(),reason:r.readByte(),targetId:r.readObjectIdClient()};
 throw Error('Unsupported native barter reply');
}
export function retireNetworkBarter(world,completed=false){
 const previous=world.barter??{},serial=previous.serial??0;world.barter={...previous,open:false,serial,completed,revision:(previous.revision??0)+1};
 for(const channel of ['A','B']){for(const entry of world.inventories.get(channel)?.entries??[]){const object=world.registry.get(entry.id);if(object?.inventoryLocation?.channel===channel)object.inventoryLocation=null;}world.inventories.delete(channel);}
}
export function applyNetworkBarter(world,message){
 if(message.kind==='barter-start'){
  const own=world.localObjectId;if(own!==message.firstId&&own!==message.secondId)return false;
  const serial=(world.barter?.serial??0)+1;retireNetworkBarter(world);
  world.barter={open:true,serial,revision:1,actorId:own,areaId:world.areaId,firstId:message.firstId,secondId:message.secondId,partnerId:own===message.firstId?message.secondId:message.firstId,initiator:own===message.firstId,ownLocked:false,otherLocked:false,ownAccepted:false,otherAccepted:false};
  world.inventories.set('A',{entries:[]});world.inventories.set('B',{entries:[]});return true;
 }
 if(message.kind==='barter-close'){retireNetworkBarter(world,message.completed);return true;}
 const state=world.barter;
 if(!state?.open||state.actorId!==world.localObjectId||state.areaId!==world.areaId)return false;
 if(message.kind==='barter-lock'||message.kind==='barter-accept'){
  const key=(message.initiator===state.initiator?'own':'other')+(message.kind==='barter-lock'?'Locked':'Accepted');state[key]=message.value;state.revision++;return true;
 }
 return false;
}
