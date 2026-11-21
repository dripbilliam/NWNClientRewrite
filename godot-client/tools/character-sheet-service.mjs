import {networkCharacterRecord} from '../../src/character_record_model.js';
import {networkPartyRows} from '../../src/network_party_view.js';
import {richText} from './gameplay-text.mjs';
const pages=['Character','Skills','Feats'];
const tables=['classes','racialtypes','skills','feat','baseitems','ruleset','exptable','iprp_damagecost','damagetypes','damagetypegroups'];
const color=value=>{const rgb=/^rgb\((\d+),(\d+),(\d+)\)$/.exec(value??'');return rgb?'#'+rgb.slice(1).map(v=>Math.max(0,Math.min(255,Number(v))).toString(16).padStart(2,'0')).join(''):value;};

// Reuses the existing read-only multiplayer record model and packet sender.
// Native UI sees private handles, not trusted shortcut bindings or stat writes.
export class CharacterSheetService{
 constructor({actions,shortcuts,portrait=async()=>null,onRequest=()=>{},onView=()=>{}}){Object.assign(this,{actions,shortcuts,portrait,onRequest,onView});this.serial=0;this.epoch=0;this.tasks=new Set();this.reset();}
 get session(){return this.actions.session;}
 reset(){this.epoch++;this.opened=false;this.view=null;this.signature=null;this.page=0;}
 async retire(){this.reset();await Promise.allSettled([...this.tasks]);return{pendingImages:this.tasks.size,closed:true};}
 capture(){return{...this.actions.capture(),world:this.session.world};}
 owned(scope){return scope?.world===this.session.world&&this.actions.owned(scope);}
 base(s){return{areaId:s.areaId,areaGeneration:s.areaGeneration,actorId:s.actorId,panel:'character'};}
 state(s){const a=s.actor,r=a.replicated??{},p=a.playerState??{},w=s.world,stats=a.inventoryStats??{},common=[this.page,w.tlkOverrideVersion,w.customTokens,r.name,r.stats,a.appearance?.name];
  // Only visible dependencies retire a page. HP/gear updates must not cancel
  // an unchanged skill/feat drag while the character moves or takes damage.
  if(this.page===1)return JSON.stringify([...common,stats.skills]);
  if(this.page===2)return JSON.stringify([...common,p.feats,p.bonusFeats,stats.feats,stats.fields118,stats.fields128]);
  const portrait=networkPartyRows(w).find(row=>row.self);
  return JSON.stringify([...common,r.hitPoints,portrait?.portrait,portrait?.portraitRef,a.appearance?.equipment,p.abilities,p.combat,p.feats,p.bonusFeats,stats,w.inventories.get('I'),...(w.inventories.get('I')?.entries??[]).map(e=>w.registry.get(e.id)?.item)]);
 }
 async rules(){this.tableWork??=Promise.all(tables.map(async name=>[name,await this.actions.text.rules(name)])).then(v=>Object.fromEntries(v));return this.tableWork;}
 async open({page=this.page}={}){this.opened=true;try{await this.choose({page});}catch(error){this.opened=false;throw error;}}
 async choose({viewId,page}){
  if(viewId!==undefined)this.current(viewId);if(!Number.isInteger(page)||page<0||page>=pages.length)throw Error('Invalid character record page');
  const epoch=++this.epoch,s=this.capture();if(!this.opened||!this.owned(s))throw Error('Character record owner is unavailable');
  await this.session.hudPanel({...this.base(s),open:true,page});this.onRequest({operation:'page',targetId:s.actorId,page});
  if(epoch!==this.epoch||!this.owned(s))return;this.page=page;this.signature=null;await this.refresh(true);
 }
 async close(){const s=this.capture(),epoch=++this.epoch;this.opened=false;this.view=null;this.signature=null;if(!this.owned(s))return;await this.session.hudPanel({...this.base(s),open:false,page:-1});this.onRequest({operation:'close',targetId:s.actorId,page:-1});if(epoch===this.epoch&&this.owned(s))this.actions.emit({kind:'sheet-closed'});}
 current(id){const v=this.view;if(!this.opened||!v||v.id!==id||v.page!==this.page||!this.owned(v.scope))throw Error('Character record selection is stale');return v;}
 entry(id,entryId){const v=this.current(id),e=v.entries.get(entryId),a=v.scope.actor,b=e?.binding;
  const feats=[...(a.playerState?.feats??[]),...(a.playerState?.bonusFeats??[]),...(a.inventoryStats?.feats??[]).map(v=>v.id),...(a.inventoryStats?.fields118??[]),...(a.inventoryStats?.fields128??[])];
  if(!b||!(b.type===4?feats.includes(b.intParam):b.type===3&&(a.inventoryStats?.skills??[]).some(s=>s.index===b.intParam&&s.flag&&s.value>0)))throw Error('Character record shortcut is unavailable');return{v,e};
 }
 async assign({viewId,entryId,index}){if(!Number.isInteger(index)||index<0||index>=36)throw Error('Invalid shortcut index');const{v,e}=this.entry(viewId,entryId);await this.session.assignQuickbar({areaId:v.scope.areaId,areaGeneration:v.scope.areaGeneration,index,button:{...e.binding}});this.onRequest({operation:'assign',index,button:{...e.binding}});if(this.owned(v.scope))await this.shortcuts.refresh(true);}
 async refresh(force=false){
  if(!this.opened)return;const s=this.capture();if(!this.owned(s))return;
  const signature=this.state(s);if(!force&&signature===this.signature&&this.view?.scope.actor===s.actor)return;
  const epoch=++this.epoch,rules=await this.rules();if(epoch!==this.epoch||!this.opened||!this.owned(s))return;
  const model=await networkCharacterRecord(s.world,s.actor,{tables:rules,resolve:v=>this.actions.text.resolve(v,s.actorId),portrait:async()=>null,identity:this.actions.connection+':'+s.actorId});
  if(epoch!==this.epoch||!this.opened||!this.owned(s)||signature!==this.state(s))return;
  const id=++this.serial,entries=new Map(),visible=this.page===1?model.skills:this.page===2?model.feats:[];
  const rows=visible.map((row,entryId)=>{entries.set(entryId,row);const{binding,description,...value}=row;return{...value,entryId,canDrag:Boolean(binding),description:richText(description)};});
  const{skills,feats,portrait,...info}=model;
  const details=info.details.map(row=>({...row,parts:(row.parts??[{text:row.value==null?'—':String(row.value)}]).map(p=>({...p,...(p.color?{color:color(p.color)}:{})}))}));
  this.signature=signature;this.view={id,scope:s,page:this.page,entries};
  this.onView({id,page:this.page,scope:s});
  this.actions.emit({kind:'sheet-view',viewId:id,page:this.page,tab:pages[this.page],model:{...info,details},entries:rows,canLevelUp:Boolean(s.actor.playerState?.combat?.canLevelUp)});
  const images=this.page===0?model.abilities.map(a=>({key:'ability:'+a.key,icon:'gui_chrsht_'+a.key.toLowerCase()})):rows.filter(r=>r.icon&&r.icon!=='****').map(r=>({key:'entry:'+r.entryId,icon:r.icon}));
  const party=networkPartyRows(s.world).find(r=>r.self);let cursor=0;
  const valid=()=>this.opened&&this.view?.id===id&&this.owned(s);
  const work=Promise.all([
   this.page===0&&party?this.portrait({...party,size:4}).then(image=>{if(image&&valid())this.actions.emit({kind:'sheet-image',viewId:id,key:'portrait',image});}).catch(()=>{}):null,
   ...Array.from({length:Math.min(4,images.length)},async()=>{while(cursor<images.length&&valid()){const row=images[cursor++];try{const image=await this.actions.icon(row.icon);if(image&&valid())this.actions.emit({kind:'sheet-image',viewId:id,key:row.key,image});}catch(error){if(valid())this.actions.diagnose('godot.sheet-icon-unavailable',error.message);}}})
  ]);this.tasks.add(work);void work.finally(()=>this.tasks.delete(work));
 }
}
