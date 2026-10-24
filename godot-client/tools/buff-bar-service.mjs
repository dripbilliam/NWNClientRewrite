import {networkEffectIcons} from '../../src/network_buff_bar.js';
import {intEntry} from '../../src/combat_stats.js';
import {nativeStringEntry} from '../../src/spell_metadata.js';
// Connection/controlled-actor owned, independent of area presentation. Wire
// states 0 and 1 are both present; duration/stack counts are never synthesized.
export class BuffBarService{
 constructor({session,connection,active,text,icon,send,diagnose=()=>{}}){Object.assign(this,{session,connection,active,text,icon,send,diagnose});this.serial=0;this.epoch=0;this.tasks=new Set();this.queue=[];this.images=new Map();this.closed=false;this.view=null;this.signature=null;}
 live(){return!this.closed&&this.active()&&!this.session.closed;}
 current(view){return this.live()&&this.view===view&&view.world===this.session.world&&view.actorId===view.world.localObjectId&&view.actor===view.world.registry.get(view.actorId)&&!view.actor.replicationRemoved;}
 emit(row){if(this.live())this.send({...row,connection:this.connection});}
 async retire(){this.closed=true;this.epoch++;this.queue.length=0;this.view=null;this.signature=null;await Promise.allSettled([...this.tasks]);this.images.clear();return{closed:true,pendingDescriptions:this.tasks.size};}
 table(){return this.tableWork??=this.text.rules('effecticons').catch(error=>{if(this.live())this.diagnose('godot.effect-icons-table-unavailable',error.message);return null;});}
 image(name){if(!this.images.has(name)){const work=Promise.resolve().then(()=>this.icon(name)).then(image=>{if(!image)this.images.delete(name);return image;},error=>{this.images.delete(name);throw error;});this.images.set(name,work);}return this.images.get(name);}
 refresh(){
  if(!this.live())return;
  const world=this.session.world,actorId=world.localObjectId,actor=world.registry.get(actorId),available=actor?.objectType===5&&!actor.replicationRemoved,rows=available?networkEffectIcons(actor):[];
  const signature=JSON.stringify([world.tlkOverrideVersion??0,rows]);
  if(this.view?.world===world&&this.view.actor===actor&&this.view.actorId===actorId&&this.signature===signature)return;
  const view={id:++this.serial,world,actor,actorId,rows};this.view=view;this.signature=signature;this.epoch++;this.queue.length=0;
  this.emit({kind:'buff-begin',viewId:view.id,actorId:available?actorId:-1,count:rows.length});
  for(let at=0;at<rows.length;at+=128)this.emit({kind:'buff-rows',viewId:view.id,rows:rows.slice(at,at+128)});
  this.emit({kind:'buff-commit',viewId:view.id});
  for(const row of rows)this.queue.push({view,row});this.pump();
 }
 pump(){while(this.live()&&this.tasks.size<4&&this.queue.length){const{view,row}=this.queue.shift(),work=this.describe(view,row).catch(error=>{if(this.current(view))this.diagnose('godot.effect-icon-description-unavailable',error.message);}).finally(()=>{this.tasks.delete(work);this.pump();});this.tasks.add(work);}}
 async describe(view,row){
  const table=await this.table();if(!this.current(view))return;
  const ref=table?intEntry(table,row.id,'StrRef'):null,name=table?nativeStringEntry(table,row.id,'Icon').value:'';
  const label=(ref?.found&&ref.value>0?await this.text.resolve({strRef:ref.value>>>0},view.actorId):'')||`Effect ${row.id}`;
  if(!this.current(view))return;this.emit({kind:'buff-description',viewId:view.id,effectId:row.id,label});
  if(name&&name!=='****')try{const image=await this.image(name);if(this.current(view)&&image)this.emit({kind:'buff-icon',viewId:view.id,effectId:row.id,resource:name,image});}catch(error){if(this.current(view))this.diagnose('godot.effect-icon-unavailable',error.message);}
 }
}
