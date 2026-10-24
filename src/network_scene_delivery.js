// Presentation IO must not hold the ordered server-state import queue. Capture
// event payloads and canonical identities before yielding; ID reuse is not a
// license to deliver an old cast/attack/effect to a replacement object.
export class NetworkSceneDelivery{
 constructor(scene){this.scene=scene;this.tail=Promise.resolve();this.pending=0;this.closed=false;}
 enqueue(work,ids=[]){
  const s=this.scene,area=s.world.areaId,actors=[...new Set(ids.filter(id=>id!==undefined))].map(id=>({id,actor:s.world.registry.get(id)}));this.pending++;
  const task=this.tail.then(async()=>{
   if(this.closed||s.closed||s.world.areaId!==area)return;
   await s.requestSync();
   if(this.closed||s.closed||s.world.areaId!==area)return;
   const current=id=>{const ref=actors.find(a=>a.id===id);return !ref||s.world.registry.get(id)===ref.actor&&(!ref.actor||!ref.actor.replicationRemoved&&ref.actor.areaId===area);};
   return work(current);
  }).catch(error=>{if(!this.closed&&!s.closed)s.report('network.scene-delivery-failed',error.message);}).finally(()=>{this.pending--;});
  this.tail=task;return task;
 }
 updates(events){
  const movement=this.scene.receiveMovementChanges(events);
  const captured=events.filter(e=>['attack-animation','cast-animation','visual-effects'].includes(e.action)).map(e=>structuredClone(e));
  // Motion-only snapshots coalesce model loading without building an event log.
  if(!captured.length)return Promise.all([movement,this.scene.requestSync()]);
  return Promise.all([movement,this.enqueue(async current=>{const live=captured.filter(e=>current(e.id));this.scene.receiveAnimationChanges(live);await this.scene.receiveVisualChanges(live);},captured.map(e=>e.id))]);
 }
 objectVisual(message){const captured=structuredClone(message);return this.enqueue(current=>{if(current(captured.targetId)&&current(captured.sourceId))return this.scene.receiveObjectVisual(captured);},[message.targetId,message.sourceId]);}
 projectile(header){const captured=structuredClone(header);return this.enqueue(current=>{if(current(captured.sourceId)&&current(captured.targetId))return this.scene.receiveProjectile(captured);},[header.sourceId,header.targetId]);}
 areaVisual(message){const captured=structuredClone(message);return this.enqueue(()=>this.scene.receiveAreaVisual(captured));}
 dispose(){this.closed=true;}
}
