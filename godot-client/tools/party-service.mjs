import {networkPartyRows} from '../../src/network_party_view.js';
import {GAME_HUD_ACTIONS} from '../../src/game_hud_actions.js';

// Passive, connection-owned HUD. All interaction resolves private view handles
// back to current canonical objects; membership never transfers actor control.
export class PartyService{
 constructor({actions,portrait=async()=>null,art=async()=>null,onRequest=()=>{}}){Object.assign(this,{actions,portrait,art,onRequest});this.serial=0;this.tasks=new Set();this.queue=[];this.cache=new Map();this.closed=false;this.view=null;this.signature=null;this.stateKey=null;}
 get session(){return this.actions.session;}
 live(){return !this.closed&&this.actions.active()&&!this.session.closed;}
 current(v){const w=this.session.world;return this.live()&&v===this.view&&v.world===w&&v.actor===w.registry.get(w.localObjectId)&&v.actor?.objectType===5&&!v.actor.replicationRemoved&&v.actorId===w.localObjectId;}
 emit(value){if(this.live())this.actions.send({...value,connection:this.actions.connection});}
 cached(key,load){if(!this.cache.has(key))this.cache.set(key,Promise.resolve().then(load).catch(error=>{this.cache.delete(key);throw error;}));return this.cache.get(key);}
 async retire(){this.closed=true;this.queue.length=0;this.view=null;await Promise.allSettled([...this.tasks]);this.cache.clear();return{closed:true,pendingPresentation:this.tasks.size};}
 refresh(){
  if(!this.live())return;const w=this.session.world,actor=w.registry.get(w.localObjectId),rows=networkPartyRows(w),objects=rows.map(r=>w.registry.get(r.id));
  const signature=JSON.stringify([w.tlkOverrideVersion??0,w.customTokens,rows.map(({health,canLevelUp,...r})=>r)]);
  if(!this.view||this.view.world!==w||this.view.actor!==actor||this.view.actorId!==w.localObjectId||signature!==this.signature||objects.some((o,i)=>o!==this.view.objects[i])){
   const v={id:++this.serial,world:w,actor,actorId:w.localObjectId,objects,rows};this.view=v;this.signature=signature;this.stateKey=null;this.queue.length=0;
   this.emit({kind:'party-view',viewId:v.id,actorId:w.localObjectId,rows:rows.map((r,entryId)=>({...r,name:undefined,entryId,label:`Object ${r.id.toString(16)}`,portraitKey:JSON.stringify([r.portrait,r.portraitRef,r.self])})),actions:GAME_HUD_ACTIONS.map(([id,label,resource,key],index)=>({index,id,label,resource,key}))});
   rows.forEach((row,entryId)=>this.queue.push({v,run:()=>this.describe(v,row,entryId)}));
   for(const [index,definition]of GAME_HUD_ACTIONS.entries())for(const state of ['up','hilite','down'])this.queue.push({v,run:()=>this.skin(v,index,definition[2],state)});
   this.pump();
  }
  const key=JSON.stringify(rows.map(({health,canLevelUp})=>({health,canLevelUp})));if(key!==this.stateKey){this.stateKey=key;this.emit({kind:'party-state',viewId:this.view.id,rows:rows.map(({health,canLevelUp},entryId)=>({entryId,health,canLevelUp}))});}
 }
 pump(){while(this.live()&&this.tasks.size<4&&this.queue.length){const job=this.queue.shift();if(!this.current(job.v))continue;const work=job.run().catch(error=>{if(this.current(job.v))this.actions.diagnose('godot.party-presentation-unavailable',error.message);}).finally(()=>{this.tasks.delete(work);this.pump();});this.tasks.add(work);}}
 async describe(v,row,entryId){
  const resolve=value=>this.actions.text.resolve(value??{text:''},row.id),label=row.name?.firstName||row.name?.lastName?(await Promise.all([row.name.firstName,row.name.lastName].map(resolve))).filter(Boolean).join(' '):row.name?await resolve(row.name):`Object ${row.id.toString(16)}`;
  if(!this.current(v))return;this.emit({kind:'party-label',viewId:v.id,entryId,label});
  if(row.portrait==null)return;
  const key=JSON.stringify(['portrait',row.portrait,row.portraitRef,row.self]),image=await this.cached(key,()=>this.portrait({...row,size:row.self?3:2}));
  if(image&&this.current(v))this.emit({kind:'party-portrait',viewId:v.id,entryId,image});
 }
 async skin(v,index,reference,state){const skin=await this.cached(JSON.stringify(['skin',reference,state]),()=>this.art({kind:'control',reference,state}));if(skin?.url&&this.current(v))this.emit({kind:'party-art',viewId:v.id,index,state,skin});}
 entry(viewId,entryId){const v=this.view,row=v?.rows[entryId];if(!this.current(v)||v.id!==viewId||!Number.isInteger(entryId)||!row||!row.available||!networkPartyRows(v.world).some(r=>r.id===row.id&&r.self===row.self&&r.available)||v.objects[entryId]!==v.world.registry.get(row.id))throw Error('Party selection is no longer available');this.actions.target(row.id);return{v,row};}
 async menu({viewId,entryId,requestId}){const{row}=this.entry(viewId,entryId);return this.actions.open({requestId,targetId:row.id,position:[0,0,0]});}
 async target({viewId,entryId,token}){const{row}=this.entry(viewId,entryId),object=this.actions.target(row.id),p=object.replicated?.position;if(!Array.isArray(p)||p.length!==3)throw Error('Party target has no current position');return this.actions.selectTarget({token,targetId:row.id,position:[p[0],p[2],-p[1]]});}
 async rest({viewId}){const v=this.view,s=this.actions.capture();if(!this.current(v)||v.id!==viewId||s.actor!==v.actor||!this.actions.owned(s))throw Error('Rest belongs to a retired party HUD');const base={areaId:s.areaId,areaGeneration:s.areaGeneration,actorId:s.actorId};await this.session.rest(base);this.onRequest({operation:'rest',...base});}
}
