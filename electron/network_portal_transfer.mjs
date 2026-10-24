import {portalCharacterRequest} from '../src/network_portal.js';

// Main-process only. Neither portal credentials nor downloaded characters are
// emitted to the renderer. The old server saves/releases its player before a
// fresh session performs key exchange, resource admission and character login.
export class NetworkPortalTransfer {
 constructor(session,{prepare=null,timeout=15000}={}){Object.assign(this,{session,prepare,timeout});this.pending=null;}
 async receive(message){
  if(message.kind==='portal-activate'){await this.begin(message);return true;}
  if(message.kind!=='portal-character')return false;
  const pending=this.pending;
  try{
   if(!pending?.waiting||pending.character){this.session.diagnose({code:'network.portal-character-stale',reason:'Unrequested portal character was ignored'});return true;}
   pending.character=message.data?{data:Uint8Array.from(message.data)}:{source:message.source,resref:message.resref};
   // Native AIUpdate140841b70 state4 disconnects once the character download
   // is ready. Waiting for an unsolicited BNDP here would stall indefinitely.
   void this.session.peer.disconnect().catch(()=>this.fail('The old server connection could not be released'));
  }finally{message.data?.fill(0);}
  return true;
 }
 async begin(message){
  const s=this.session;if(this.pending)return;
  if(!this.prepare||!s.characterConfirmed||!['playing','area-loading'].includes(s.phase)){s.diagnose({code:'network.portal-unavailable',reason:'Server transfer is unavailable in this connection state'});return;}
  const pending=this.pending={host:message.host,port:message.port,waiting:false,character:null,next:null};
  s.phase='transferring';s.publish();s.diagnose({code:'network.portal-started',reason:'Server requested a portal handoff',host:message.host,port:message.port,seamless:message.seamless});
  try{
   const next=await this.prepare(message);
   if(s.closed||this.pending!==pending){await next.session.disconnect();return;}
   pending.next=next;pending.waiting=true;
   pending.timer=setTimeout(()=>this.fail('The old server did not complete its character handoff'),this.timeout);
   await s.peer.sendGameMessage(portalCharacterRequest());
  }catch{if(this.pending===pending)this.fail('The destination connection could not be prepared');}
  finally{message.password='';}
 }
 peerClosed(){
  const pending=this.pending;if(!pending?.waiting)return false;
  // Reliable messages preceding BNDP may still be in the session delivery
  // queue. Drain them before consuming43/2 or43/3 and disposing the old owner.
  void this.session.delivery.then(()=>{
   if(this.pending!==pending||this.session.closed)return;
   if(!pending.character){this.fail('The old server closed without a portal character handoff');return;}
   const next=pending.next,character=pending.character;
   next.session.acceptPortalCharacter(character);character.data?.fill(0);
   pending.next=null;pending.character=null;
   this.clear();this.session.diagnose({code:'network.portal-ready',reason:'Old server released the character; destination login is ready',host:pending.host,port:pending.port});
   this.session.portalHandoffReady=true;this.session.finish();this.session.emit('portal-ready',{...next,host:pending.host,port:pending.port});
  }).catch(()=>this.fail('The portal character handoff could not be completed'));
  return true;
 }
 clear(){const pending=this.pending;this.pending=null;if(pending){clearTimeout(pending.timer);pending.character?.data?.fill(0);if(pending.next)void pending.next.session.disconnect().catch(()=>{});}return pending;}
 fail(reason){if(!this.pending)return;this.session.diagnose({code:'network.portal-failed',reason});this.clear();void this.session.disconnect();}
 dispose(){this.clear();}
}
