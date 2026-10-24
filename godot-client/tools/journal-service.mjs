import {richText} from './gameplay-text.mjs';
const tabs=['Quests','Completed','Notes','Messages'];
export class JournalService{
 constructor({actions,onRequest=()=>{}}){Object.assign(this,{actions,onRequest});this.serial=0;this.epoch=0;this.reset();}
 get session(){return this.actions.session;}
 capture(){return{...this.actions.capture(),world:this.session.world};}
 owned(s){return s?.world===this.session.world&&this.actions.owned(s);}
 base(s){return{areaId:s.areaId,areaGeneration:s.areaGeneration,actorId:s.actorId,panel:'journal'};}
 reset(){this.epoch++;this.opened=false;this.page=0;this.view=null;this.signature=null;}
 state(s){const j=s.world.journal;return JSON.stringify([this.page,j.loaded,[...j.entries],[...j.worldEntries],s.world.tlkOverrideVersion,s.world.customTokens]);}
 async open(){if(this.opened){await this.refresh(true);return;}const s=this.capture();if(!this.owned(s))throw Error('Journal owner is unavailable');const epoch=++this.epoch;this.opened=true;await this.session.hudPanel({...this.base(s),open:true});this.onRequest({open:true});if(epoch===this.epoch&&this.owned(s))await this.refresh(true);}
 current(id){const v=this.view;if(!this.opened||!v||v.id!==id||!this.owned(v.scope))throw Error('Journal view is stale');return v;}
 async choose({viewId,page}){this.current(viewId);if(!Number.isInteger(page)||page<0||page>=tabs.length)throw Error('Invalid journal category');this.page=page;await this.refresh(true);}
 async close(){const s=this.capture(),epoch=++this.epoch;this.opened=false;this.view=null;this.signature=null;if(this.owned(s)){await this.session.hudPanel({...this.base(s),open:false});this.onRequest({open:false});if(epoch===this.epoch&&this.owned(s)&&!this.opened)this.actions.emit({kind:'journal-closed'});}}
 async refresh(force=false){if(!this.opened)return;const s=this.capture();if(!this.owned(s))return;const signature=this.state(s);if(!force&&signature===this.signature&&this.view?.scope.actor===s.actor)return;const epoch=++this.epoch,page=this.page,j=s.world.journal,source=page===3?[...j.worldEntries.values()]:[...j.entries.values()].filter(e=>page===2?!e.isQuest:e.isQuest&&(page===1?Boolean(e.completed):!e.completed));
  const entries=await Promise.all(source.map(async e=>({title:richText(e.title?await this.actions.text.resolve(e.title,s.actorId):e.tag??'Journal entry'),description:richText(await this.actions.text.resolve(e.description??(e.strRef!==undefined?{strRef:e.strRef}:null),s.actorId)),tag:e.tag??null,date:e.date,time:e.time,priority:e.priority,picture:e.picture,completed:Boolean(e.completed),isQuest:Boolean(e.isQuest)})));
  if(epoch!==this.epoch||!this.opened||!this.owned(s)||signature!==this.state(s))return;const id=++this.serial;this.signature=signature;this.view={id,scope:s};this.actions.emit({kind:'journal-view',viewId:id,page,tabs,loaded:Boolean(j.loaded),entries});
 }
}
