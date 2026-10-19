import {OBJECT_INVALID} from './game_object_array.js';

// Original4dddb0 ->7a7440, minors1 full/3 add/4 remove. Signed nonpositive
// counts are empty; IDs remain raw client uint32, including not-yet-seen members.
export function readNetworkParty(r,minor){
 const count=r.readInt(),ids=[];
 if(count>Math.floor((r.byteSize40-r.byteCursor44)/4))throw new Error('Invalid native party-list count');
 for(let i=0;i<count;i++)ids.push(r.readObjectIdClient());
 return{kind:'party-list',operation:({1:'all',3:'add',4:'remove'})[minor],count,ids};
}
// Native852ac0 marks old members,851220 refreshes or appends,852f90 sweeps.
// Preserve physical order. Existing full-list members do not move to wire order.
// Native851c60's INVALID cache miss allows repeated sentinel entries. Native
// sweeps deliberately retain ID0. Neither case creates a game-object proxy.
export function applyNetworkParty(current,message){
 if(!['all','add','remove'].includes(message.operation)||!Array.isArray(message.ids)||!message.ids.every(id=>Number.isInteger(id)&&id>=0&&id<=0xffffffff))throw new Error('Invalid replicated party list');
 let next=current.map(e=>({...e}));
 const sweep=()=>{next=next.filter(e=>e.id===0||!e.stale);};
 if(message.operation==='all')for(const e of next)e.stale=true;
 for(const id of message.ids){
  const old=next.find(e=>e.id===id);
  if(message.operation==='remove'){if(old)old.stale=true;sweep();}
  else if(old&&id!==OBJECT_INVALID)old.stale=false;
  else next.push({id,stale:false});
 }
 if(message.operation==='all')sweep();
 return next;
}
// Native party count/first/next queries resolve the current creature by ID,
// then compare type274/master270; membership alone never grants ownership.
export function networkPartyAssociates(world,actor,type){
 return(world?.party??[]).map(e=>world.registry.get(e.id)).filter(o=>o?.objectType===5&&!o.replicationRemoved&&o.replicated?.field908===(type&65535)&&(actor.id===OBJECT_INVALID||o.replicated?.master===actor.id));
}
