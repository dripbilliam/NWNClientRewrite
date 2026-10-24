// Render1e0c50..1e0c72 uses unsigned timer arithmetic with one fewer tick
// across wrap, and does not admit a zero elapsed interval even for delay0.
export function nativeSoundDelayDue(now,start,delay){const elapsed=((now>>>0)-(start>>>0)-((now>>>0)<(start>>>0)?1:0))>>>0;return elapsed!==0&&elapsed>=(delay>>>0);}
export class NativeDelayedSounds{
 constructor({now,play}){Object.assign(this,{now,play});this.queue=[];this.sequence=0;}
 add(event,delay){this.queue.unshift({id:this.sequence++,start:this.now()>>>0,delay:delay>>>0,event});}
 update(){const now=this.now()>>>0;for(const entry of [...this.queue]){if(entry.event.current&&!entry.event.current()){this.queue.splice(this.queue.indexOf(entry),1);continue;}if(nativeSoundDelayDue(now,entry.start,entry.delay)){this.queue.splice(this.queue.indexOf(entry),1);this.play(entry.event);}}}
 clear(){this.queue=[];}
 snapshot(){return this.queue.map(e=>({id:e.id,start:e.start,delay:e.delay,resRef:e.event.resRef,objectId:e.event.objectId,position:e.event.position,priority:e.event.nativeSource.priority,channel:e.event.channel}));}
}
