// CNWSCreature::ReceiveAssociateCommand1403d69f0. A master lookup precedes
// recording the command, even for unknown commands and dismissal. Ordinary
// commands enqueue a conversation/listen event; they are not direct AI orders.
export async function receiveAssociateCommand(actor,command,p){
  command|=0;const master=p.creature(actor.masterId);if(!master)return;
  actor.lastAssociateCommand=command;
  if(command===-13){await p.unpossess(master);return;}
  if(command===-12){await p.removeDomination(actor);return;}
  if(command===-9){master.nativeField910=0;await p.unsummon(actor);return;}
  if(command===-8){master.nativeField914=0;await p.unsummon(actor);return;}
  if(command===-10){await p.unsummon(actor);return;}
  if(command< -23||command> -2)return;
  if(command===-2)actor.nativeField708=1;
  const event={type:7,integers:[],strings:[]};
  event.integers[0]=p.expression(actor,command).matches.length|0;
  event.integers[1]=command;
  if(p.expression(actor,command).matches.length>1){
    let index=1;
    do{event.strings[index]=p.expression(actor,command).matches[index]??'';index++;}
    while(index<p.expression(actor,command).matches.length);
  }
  await p.event(actor.masterId,actor.id,event);
}

// BroadcastAssociateCommand140382bb0 rereads the physical count and preserves
// duplicate/stale IDs; callbacks can change the live list during traversal.
export async function broadcastAssociateCommand(actor,command,p){
  const ids=p.associates(actor);if(!ids||ids.length<=0)return;
  let i=0;do{const target=p.creature(ids[i]);if(target)await p.receive(target,command|0);i++;}while(i<ids.length);
}
