import {OBJECT_INVALID} from './game_object_array.js';
const call=(p,n,...a)=>{if(typeof p?.[n]!=='function')throw new Error(`Native client pause provider ${n} is unavailable`);return p[n](...a);};
const flags=s=>s.flags&255;
export function clientPauseExcluded(s,id){return s.exclusions===null?1:Number(s.exclusions.includes(id>>>0));}
// Client internal6d7fe0. One shared received exclusion list; unlike server
// storage there are not separate mask1/mask2 ID arrays on this client owner.
export function clientActiveTimer(s,id){
 id>>>=0;if(id!==OBJECT_INVALID){if(flags(s)&2){if(clientPauseExcluded(s,id)===1)return s.timer2;}else if((flags(s)&1)&&clientPauseExcluded(s,id)===1)return s.timer1;}return s.world;
}
function sceneCall(object,offset,p){
 if(call(p,'asObject',object)){const scene=call(p,'scene',call(p,'asObject',object));if(scene)call(p,'sceneVirtual',call(p,'scene',call(p,'asObject',object)),offset);}
}
// Clear prior list6d6770: reset uses the POST-change flags/timers but old list.
// Scene resume158 follows reset; live list count is re-read after callbacks.
export function clearClientPauseExclusions(s,p){
 if(!Array.isArray(s.exclusions))throw new Error('Native client pause clear dereferences unavailable exclusion storage');
 for(let i=0;i<s.exclusions.length;i++){
  const object=call(p,'object',s.exclusions[i]>>>0);if(!object)continue;
  const now=clientActiveTimer(s,object.id).time();call(p,'resetObjectTimes',object,now.day,now.time);sceneCall(object,0x158,p);
 }
 s.exclusions=[];
}
// Complete client internal6e1fc0. Its initial comparison is raw(flags&mask),
// not BOOL; a repeated mask2/value1 therefore still runs. Incoming is owned.
export function setClientPauseState(s,mask,value,incoming,p){
 mask&=255;value|=0;if((flags(s)&mask)===(value>>>0))return;
 const world=s.world,one=s.timer1,two=s.timer2,snapshot=t=>call(p,'snapshot',t),sync=t=>call(p,'syncPrevious',t),pause=t=>call(p,'pause',t),unpause=t=>call(p,'unpause',t),reset=(t,from)=>call(p,'reset',t,from);
 if(value===1){
  s.flags=flags(s)|mask;pause(world);snapshot(world);snapshot(world);
  if(flags(s)&2){pause(one);snapshot(one);snapshot(one);call(p,'pauseText',205);}
  call(p,'audio',true);
 }else{
  s.flags=flags(s)&(~mask&255);
  if(mask===2){
   pause(two);reset(two,one);snapshot(two);snapshot(one);sync(two);sync(one);
   if((flags(s)&2)!==0||(flags(s)&1)===0){snapshot(world);sync(world);unpause(world);call(p,'audio',false);}
   unpause(one);unpause(two);call(p,'pauseText',206);
  }else if(mask===1){
   pause(one);pause(two);reset(one,world);reset(two,world);snapshot(world);snapshot(one);snapshot(two);sync(two);sync(one);sync(world);unpause(world);unpause(one);unpause(two);call(p,'audio',false);
  }
 }
 clearClientPauseExclusions(s,p);
 if(incoming){
  for(let i=0;i<incoming.ids.length;i++){
   const id=incoming.ids[i]>>>0;if(s.exclusions!==null&&!s.exclusions.includes(id))s.exclusions.push(id);
   const object=call(p,'object',id);if(object){sceneCall(object,0x150,p);const now=clientActiveTimer(s,object.id).time();call(p,'resetObjectTimes',object,now.day,now.time);}
  }
  call(p,'disposeIncoming',incoming);
 }
 if(!s.gui||call(p,'guiActive',s.gui)===0)return;
 let blocked=0;
 if(((flags(s)&3)!==0)&&s.profileMode!==1&&clientPauseExcluded(s,s.controlledId)===0)blocked=1;
 call(p,'guiBlocked',s.gui,blocked);
 const bits=((mask&1)*2)|((mask&2)!==0?4:0);call(p,value!==0?'guiSetFlags':'guiClearFlags',s.gui,bits);
}
// Entire module3/minor9 receiver7a5680 after outer dispatch. On overflow or
// an unchanged-state early return native ownership is NOT freed by this owner.
export function receiveClientPauseMessage(p){
 const owned={ids:[],capacity:0,disposed:false};call(p,'allocateIncoming',owned);
 const mask=call(p,'byte',2,1)&255,value=call(p,'bool')|0,count=call(p,'word',16)&65535;
 for(let i=0;i<count;i++){const id=call(p,'objectId')>>>0;if(owned.ids.length===owned.capacity)owned.capacity=owned.capacity===0?16:owned.capacity*2;owned.ids.push(id);}
 if(call(p,'overflow')!==0){call(p,'unconsumedIncoming',owned,'overflow');return 0;}
 call(p,'apply',mask,value,owned);const gui=call(p,'gui');if(gui&&gui.fieldA8)call(p,'refreshGui');
 if(!owned.disposed)call(p,'unconsumedIncoming',owned,'unchanged-state');return 1;
}
