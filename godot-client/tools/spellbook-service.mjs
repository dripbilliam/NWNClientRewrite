import {intEntry} from '../../src/combat_stats.js';
import {nativeStringEntry} from '../../src/spell_metadata.js';
import {metamagicLevelCost} from '../../src/spell_book.js';
import {networkPreparationEntries,networkSpellUsesLeft,networkSpellLikeShortcutUses} from '../../src/network_spellbook.js';
import {isSpellFamily,spellFamilyChildren,spellFamilyContains} from '../../src/spell_family.js';
import {preparationRequest,dropPreparation} from '../../src/spell_preparation.js';
import {networkFeatUses} from '../../src/network_feat_input.js';
import {richText} from './gameplay-text.mjs';
import {networkItemQuickbarProviders,configureNetworkItemShortcut} from '../../src/network_quickbar_items.js';
import {emptyQuickbarButton} from '../../src/quickbar.js';
import {updateItemQuickbarCount} from '../../src/item_quickbar.js';
import {networkAssociateShortcutPresentation} from '../../src/network_associate_input.js';
import {itemIconDescriptor} from '../../src/item_icon.js';

const metas=[[0,null,'Normal'],[1,11,'Empower'],[2,12,'Extend'],[4,25,'Maximize'],[8,29,'Quicken'],[16,33,'Silent'],[32,37,'Still']];
const stamp=value=>JSON.stringify(value??null),slotKey=w=>`${w.classIndex}:${w.level}:${w.slot}`;

// Read-only native view model. The reused session owns wire assignments and
// client-owned shortcut layout; preparation/uses remain server replicated.
export class SpellbookService {
 constructor({actions,send=actions.send,icon=actions.icon,now=Date.now,onPrepare=()=>{}}){Object.assign(this,{actions,send,icon,now,onPrepare});this.serial=0;this.reset();}
 reset(){this.epoch=(this.epoch??0)+1;this.quickEpoch=(this.quickEpoch??0)+1;this.opened=false;this.view=null;this.family=null;this.pending=new Map();this.quick=null;this.recentQuick=new Map();this.signature=null;this.quickSignature=null;this.selection={classIndex:0,level:0,metamagic:0};this.busy=new Set();}
 get session(){return this.actions.session;}
 get rules(){return this.actions.rules;}
 emit(row){this.actions.emit(row);}
 state(scope){const a=scope.actor;return stamp([this.session.world.tlkOverrideVersion,a.replicated?.stats?.classes,a.playerState?.spellbooks,a.playerState?.feats,a.playerState?.bonusFeats,a.playerState?.featUses,a.playerState?.specialAbilities]);}
 async label(table,id,column='Name'){const e=intEntry(this.rules[table],id,column);return e.found?await this.actions.text.resolve({strRef:e.value>>>0},this.session.world.localObjectId):`${table} ${id}`;}
 classes(scope){return(scope.actor.replicated?.stats?.classes??[]).map((c,index)=>({...c,index})).filter(c=>intEntry(this.rules.classes,c.id,'SpellCaster').value!==0);}
 availableMetas(scope){const owned=new Set([...(scope.actor.playerState?.feats??[]),...(scope.actor.playerState?.bonusFeats??[])]);return metas.filter(([,feat])=>feat===null||owned.has(feat));}
 binding(w){return{type:2,intParam:w.castId??w.id,classIndex:w.classIndex,metamagic:w.metamagic,domainLevel:w.domain?(w.level-metamagicLevelCost(this.rules,w.metamagic))&255:0};}
 async open(query={}){this.opened=true;await this.query(query);}
 close(){this.opened=false;this.view=null;this.family=null;this.epoch++;}
 async query(query){
  const epoch=this.epoch,scope=this.actions.capture();await this.actions.tables();if(epoch!==this.epoch||!this.opened||!this.actions.owned(scope))return;
  const classes=this.classes(scope),index=query.classIndex??this.selection.classIndex;
  this.selection={classIndex:classes.some(c=>c.index===index)?index:classes[0]?.index??0,level:query.level??this.selection.level,metamagic:query.metamagic??this.selection.metamagic};
  if(!this.availableMetas(scope).some(([m])=>m===this.selection.metamagic))throw Error('That metamagic is not available');
  this.family=null;this.signature=null;await this.refresh(true);
 }
 validView(id){const v=this.view;if(!v||v.id!==id||!this.actions.owned(v.scope)||v.state!==this.state(v.scope))throw Error('Spellbook selection is stale');return v;}
 entry(viewId,entryId){const v=this.validView(viewId),w=v.widgets.get(entryId);if(!w)throw Error('Spellbook entry is unavailable');return{v,w};}
 async familyChoice({viewId,entryId}){const {w}=this.entry(viewId,entryId);const id=w.castId??w.id;if(!isSpellFamily(this.rules,id))throw Error('That spell has no variants');this.family={widget:{...w},path:[...(w.castId===undefined?[]:this.family?.path??[]),id]};this.signature=null;await this.refresh(true);}
 async familyBack({viewId}){this.validView(viewId);if(this.family?.path.length>1)this.family.path.pop();else this.family=null;this.signature=null;await this.refresh(true);}
 expire(scope){for(const [key,p]of this.pending){const slot=scope.actor.playerState?.spellbooks?.[p.widget.classIndex]?.memorized?.[p.widget.level]?.[p.widget.slot];if(stamp(slot)!==p.before||this.now()-p.at>5000){this.pending.delete(key);if(stamp(slot)===p.before)this.emit({kind:'book-notice',text:'The server has not changed the requested spell slot.'});}}}
 async refresh(force=false){
  const scope=this.actions.capture();if(!this.actions.owned(scope))return;
  await this.actions.tables();if(!this.actions.owned(scope))return;
  this.expire(scope);await this.refreshQuick(scope,force);
  if(!this.opened)return;
  const state=this.state(scope),signature=stamp([state,this.selection,this.family,[...this.pending.keys()]]);
  if(!force&&signature===this.signature&&this.view?.scope.actor===scope.actor)return;
  const epoch=++this.epoch,id=++this.serial,widgets=new Map();
  const add=async(w)=>{const entryId=widgets.size;widgets.set(entryId,w);const binding=w.id>=0?this.binding(w):null;const uses=binding?networkSpellUsesLeft(scope.actor,this.rules,binding.intParam,binding.classIndex,binding.domainLevel,binding.metamagic):0;
   return{entryId,key:stamp([w.classIndex,w.level,w.kind,w.slot,w.id,w.castId,w.domain,w.metamagic]),spellId:w.castId??w.id,label:w.id<0?'Empty slot':await this.label('spells',w.castId??w.id),icon:w.id<0?null:nativeStringEntry(this.rules.spells,w.castId??w.id,'IconResRef').value,family:w.id>=0&&isSpellFamily(this.rules,w.castId??w.id),uses,ready:w.ready!==0,domain:w.domain!==0,metamagic:w.metamagic,slot:w.slot,pending:this.pending.has(slotKey(w)),canCast:uses>0,canDrag:w.id>=0&&!isSpellFamily(this.rules,w.castId??w.id)};};
  const classes=await Promise.all(this.classes(scope).map(async c=>({index:c.index,label:await this.label('classes',c.id)}))),cls=scope.actor.replicated?.stats?.classes?.[this.selection.classIndex],{classIndex,level,metamagic}=this.selection;
  const book=scope.actor.playerState?.spellbooks?.[classIndex]??{},prepared=Boolean(cls&&intEntry(this.rules.classes,cls.id,'MemorizesSpells').value);
  const known=[],memory=[],family=[];const base=level-metamagicLevelCost(this.rules,metamagic);
  if(cls&&base>=0)for(const s of networkPreparationEntries(scope.actor,this.rules,classIndex,base,metamagic))known.push(await add({type:0x53704278,kind:1,classIndex,level,slot:0,id:s.id,domain:s.domain,metamagic:s.metamagic,ready:0}));
  known.sort((a,b)=>a.label.localeCompare(b.label)||a.entryId-b.entryId);
  if(prepared)for(const [slot,s]of(book.memorized?.[level]??[]).entries())memory.push(await add({type:0x53704278,kind:0,classIndex,level,slot,id:s?.spell??-1,domain:s?.domain??0,metamagic:s?.metamagic??0,ready:s?.ready??0}));
  let familyTitle='';
  if(this.family){const source=this.family.widget,exists=[...widgets.values()].some(w=>stamp(w)===stamp({...source,castId:undefined}));
   if(!exists)this.family=null;else{const parent=this.family.path.at(-1);familyTitle=await this.label('spells',parent);for(const child of spellFamilyChildren(this.rules,parent,this.family.path.slice(0,-1)))family.push(await add({...source,castId:child}));}}
  if(epoch!==this.epoch||!this.opened||!this.actions.owned(scope)||state!==this.state(scope))return;
  this.signature=signature;this.view={id,scope,state,widgets};
  const data={kind:'spellbook-view',viewId:id,...this.selection,classes,metas:this.availableMetas(scope).map(([value,,label])=>({value,label})),prepared,known,memory,family,familyTitle,usesLeft:book.usesLeft?.[level]??0};this.emit(data);
  for(const row of [...known,...memory,...family])if(row.icon)void this.icon(row.icon).then(image=>{if(image&&this.view?.id===id&&this.actions.owned(scope))this.emit({kind:'book-icon',viewId:id,entryId:row.entryId,image});}).catch(()=>{});
 }
 async inspect({viewId,entryId}){const {v,w}=this.entry(viewId,entryId);if(w.id<0)return;const id=w.castId??w.id,e=intEntry(this.rules.spells,id,'SpellDesc'),rich=richText(e.found?await this.actions.text.resolve({strRef:e.value>>>0},v.scope.actorId):'No description available.');if(this.view===v&&this.actions.owned(v.scope))this.emit({kind:'book-description',viewId,entryId,rich});}
 async activate({viewId,entryId}){const {v,w}=this.entry(viewId,entryId),binding=this.binding(w);if(w.id<0||isSpellFamily(this.rules,binding.intParam))throw Error('Choose a spell variant before casting');if(!networkSpellUsesLeft(v.scope.actor,this.rules,binding.intParam,binding.classIndex,binding.domainLevel,binding.metamagic))throw Error('No casts remain for this spell');this.actions.targetScope=v.scope;return this.exclusive('activate',()=>this.actions.targeter.begin(binding));}
 async write(scope,original,next){
  const key=slotKey(original);if(this.pending.has(key))throw Error('That preparation slot is waiting for the server');
  if(!this.actions.owned(scope))throw Error('Spell preparation belongs to an old actor');
  const before=scope.actor.playerState.spellbooks[original.classIndex].memorized[original.level][original.slot];
  this.pending.set(key,{widget:original,before:stamp(before),at:this.now()});
  try{const result=await this.session.prepareSpell({areaId:scope.areaId,areaGeneration:scope.areaGeneration,actorId:scope.actorId,...(next?preparationRequest(next,{metamagicCost:m=>metamagicLevelCost(this.rules,m)}):{clear:true,classIndex:original.classIndex,level:original.level,slot:original.slot})});this.onPrepare({classIndex:original.classIndex,level:original.level,slot:original.slot,before:structuredClone(before??null),clear:!next,spellId:next?.id,...{areaId:scope.areaId,areaGeneration:scope.areaGeneration,actorId:scope.actorId}});return result;}
  catch(error){this.pending.delete(key);throw error;}
 }
 async prepare({viewId,entryId,destinationId,clear=false}){
  const {v,w}=this.entry(viewId,entryId);if(!intEntry(this.rules.classes,v.scope.actor.replicated.stats.classes[w.classIndex].id,'MemorizesSpells').value)throw Error('This class does not prepare spells');
  return this.exclusive('prepare',async()=>{
   if(clear){if(w.kind!==0)throw Error('Choose a prepared slot to clear');await this.write(v.scope,w,null);}
   else{if(w.id<0)throw Error('Choose a known spell');let destination=destinationId===undefined?[...v.widgets.values()].find(d=>d.kind===0&&d.id===-1&&!this.pending.has(slotKey(d))):v.widgets.get(destinationId);
    if(!destination||destination.kind!==0||destination.classIndex!==w.classIndex||destination.level!==w.level)throw Error('No compatible empty preparation slot');
    if(w.kind===0&&slotKey(w)===slotKey(destination))return;
    const requests=[],source={...w},dest={...destination};await dropPreparation(dest,source,0,{set:(widget,id,_send,domain,metamagic,classIndex)=>requests.push({old:widget===source?w:destination,next:{...widget,id,domain,metamagic,classIndex}}),tint:()=>{}});
    for(const r of requests){if(!this.actions.owned(v.scope))throw Error('Spell preparation belongs to an old actor');await this.write(v.scope,r.old,r.next);}
   }
   await this.refresh(true);
  });
 }
 async exclusive(key,fn){if(this.busy.has(key))throw Error('That action is already pending');this.busy.add(key);try{return await fn();}finally{this.busy.delete(key);}}
 quickState(scope){const w=this.session.world;return stamp([this.state(scope),w.quickbar??[],(w.quickbar??[]).filter(b=>b.type===1).map(b=>[b.itemId,w.registry.get(b.itemId)?.item,w.registry.get(b.itemId)?.equipmentOwnerId,w.registry.get(b.itemId)?.replicationRemoved])]);}
 async refreshQuick(scope,force=false){
  const buttons=this.session.world.quickbar??[],signature=this.quickState(scope);if(!force&&this.quickSignature===signature&&this.quick?.scope.actor===scope.actor)return;
  const epoch=++this.quickEpoch;
  const id=++this.serial,rows=[];for(let index=0;index<36;index++){const b=buttons[index]??{type:0};let label=b.commandLabel||b.toolTip||(b.type?'Action '+b.type:'Empty shortcut'),icon=null,secondaryIcon=null,uses=null,enabled=true;
   const table=[2,44].includes(b.type)?'spells':b.type===4?'feat':b.type===3?'skills':null;
   if([38,39,42].includes(b.type)){const details=networkAssociateShortcutPresentation(b,this.session.world);label=details.label??label;icon=details.icon??null;}
   if(b.type===1){const item=this.session.world.registry.get(b.itemId);if(item?.item){label=await this.actions.text.resolve(item.item.name,scope.actorId);icon=itemIconDescriptor(item.item,scope.actor.appearance?.gender??0);const details={};try{const configured=configureNetworkItemShortcut(this.session.world,this.rules,emptyQuickbarButton(),b);if(configured){Object.assign(details,configured.presentation);icon=details.icon??icon;secondaryIcon=details.secondaryIcon??null;}else updateItemQuickbarCount({...b},networkItemQuickbarProviders(this.session.world,this.rules,details));uses=details.uses??null;enabled=details.enabled!==false;}catch{label+=' · item details unavailable';}}else{label='Unavailable item';enabled=false;}}
   if(table){const spell=b.type===4?b.intParam&65535:b.intParam;label=await this.label(table,spell,table==='feat'?'FEAT':'Name');icon=nativeStringEntry(this.rules[table],spell,table==='spells'?'IconResRef':'Icon').value;
    if(b.type===2)uses=networkSpellUsesLeft(scope.actor,this.rules,b.intParam,b.classIndex&7,b.domainLevel&15,b.metamagic&63);else if(b.type===44)uses=networkSpellLikeShortcutUses(scope.actor,this.rules,b.intParam,b.domainLevel&15);else if(b.type===4){const n=networkFeatUses(scope.actor,this.rules,spell);uses=n===100?null:n;}}
   rows.push({index,label,icon,secondaryIcon,uses,empty:!b.type,enabled:Boolean(b.type)&&enabled&&uses!==0});
  }
  if(epoch!==this.quickEpoch||!this.actions.owned(scope)||signature!==this.quickState(scope))return;
  if(this.quick){this.recentQuick.set(this.quick.id,this.quick);while(this.recentQuick.size>8)this.recentQuick.delete(this.recentQuick.keys().next().value);}
  this.quickSignature=signature;this.quick={id,scope,buttons:structuredClone(buttons)};this.emit({kind:'quickbar-view',quickbarId:id,rows});
  for(const row of rows)for(const secondary of [false,true]){const descriptor=secondary?row.secondaryIcon:row.icon;if(descriptor)void this.icon(descriptor).then(image=>{if(image&&this.quick?.id===id&&this.actions.owned(scope))this.emit({kind:'quickbar-icon',quickbarId:id,index:row.index,secondary,image});}).catch(()=>{});}
 }
 // Presentation updates may overtake input; unchanged canonical bindings and
 // actor/world ownership, not only the latest display ID, authorize the action.
 quickCurrent(id){const q=this.quick?.id===id?this.quick:this.recentQuick.get(id);if(!q||!this.actions.owned(q.scope)||stamp(q.buttons)!==stamp(this.session.world.quickbar??[]))throw Error('Shortcut selection is stale');return q;}
 async assign({viewId,entryId,index}){const {v,w}=this.entry(viewId,entryId),button=this.binding(w);if(w.id<0||isSpellFamily(this.rules,button.intParam)||w.castId!==undefined&&!spellFamilyContains(this.rules,w.id,w.castId))throw Error('Choose a castable spell variant');return this.exclusive('shortcut',async()=>{await this.session.assignQuickbar({areaId:v.scope.areaId,areaGeneration:v.scope.areaGeneration,index,button});await this.refresh(true);});}
 async assignInventory({quickbarId,viewId,entryId,index},inventory){
  if(!Number.isInteger(index)||index<0||index>=36)throw Error('Invalid shortcut slot');
  return this.exclusive('shortcut',async()=>{
   await this.actions.tables();const q=this.quickCurrent(quickbarId),{view,row}=inventory.selected(viewId,entryId);
   if(view.scope.actor!==q.scope.actor||!['R','I'].includes(row.channel)||inventory.pending.has(row.object.id))throw Error('Only an available owned inventory item can be assigned');
   const configured=configureNetworkItemShortcut(this.session.world,this.rules,Object.assign(emptyQuickbarButton(),q.buttons[index]),{itemId:row.object.id,intParam:0xff00ff},{report:(code,reason)=>this.actions.diagnose(code,reason)});
   if(!configured)throw Error('That item cannot be assigned to a shortcut');
   await this.session.assignQuickbar({areaId:q.scope.areaId,areaGeneration:q.scope.areaGeneration,index,button:configured.button});
   await this.refresh(true);return configured.button;
  });
 }
 async assignRadial({quickbarId,menuId,requestId,slot,index}){
  if(!Number.isInteger(index)||index<0||index>=36)throw Error('Invalid shortcut slot');
  return this.exclusive('shortcut',async()=>{
   await this.actions.tables();const q=this.quickCurrent(quickbarId),state=this.actions.currentMenu(menuId),entry=state.view.entries.find(row=>row.slot===slot),binding=entry?.quickbarBinding,item=state.target,location=item?.inventoryLocation;
   if(state.requestId!==requestId||state.scope.actor!==q.scope.actor||entry?.children||entry?.disabled||binding?.type!==1||entry.action!=='item.use'||item?.objectType!==6||binding.itemId!==item.id||location?.ownerId!==q.scope.actorId||!['I','R'].includes(location.channel))throw Error('That item action cannot be assigned');
   const configured=configureNetworkItemShortcut(this.session.world,this.rules,Object.assign(emptyQuickbarButton(),q.buttons[index]),binding,{report:(code,reason)=>this.actions.diagnose(code,reason)});
   if(!configured)throw Error('That item action cannot be assigned');
   state.pending=true;
   try{await this.session.assignQuickbar({areaId:q.scope.areaId,areaGeneration:q.scope.areaGeneration,index,button:configured.button});await this.refresh(true);if(this.actions.menu===state)this.actions.cancel({requestId});return configured.button;}
   catch(error){if(this.actions.menu===state)state.pending=false;throw error;}
  });
 }
 async quickEdit({quickbarId,index,sourceIndex,clear=false}){const q=this.quickCurrent(quickbarId);return this.exclusive('shortcut',async()=>{const base={areaId:q.scope.areaId,areaGeneration:q.scope.areaGeneration};if(clear)await this.session.assignQuickbar({...base,index,button:{type:0}});else{const button=q.buttons[sourceIndex];if(!button?.type||index===sourceIndex)return;await this.session.assignQuickbar({...base,index,button});if(this.actions.owned(q.scope)&&stamp(button)===stamp(this.session.world.quickbar[sourceIndex]))await this.session.assignQuickbar({...base,index:sourceIndex,button:{type:0}});}await this.refresh(true);});}
 async quickActivate({quickbarId,index}){const q=this.quickCurrent(quickbarId),b=this.session.world.quickbar[index];if(!b?.type)return;return this.exclusive('activate',async()=>{this.actions.targetScope=q.scope;if(b.type===3)return this.actions.targeter.begin(b);if([2,4,44].includes(b.type)){const uses=b.type===2?networkSpellUsesLeft(q.scope.actor,this.rules,b.intParam,b.classIndex&7,b.domainLevel&15,b.metamagic&63):b.type===44?networkSpellLikeShortcutUses(q.scope.actor,this.rules,b.intParam,b.domainLevel&15):networkFeatUses(q.scope.actor,this.rules,b.intParam);if(!uses)throw Error('No uses remain for this shortcut');return this.actions.targeter.begin(b);}if(b.type===1&&(b.intParam&65535)!==255)return this.actions.targeter.begin(b);return this.session.activateQuickbar({areaId:q.scope.areaId,areaGeneration:q.scope.areaGeneration,index});});}
}
