import {prepareNetworkSpellMenus} from '../../src/network_spell_menu.js';
import {networkRadialActions,networkDefaultInteraction} from '../../src/network_action_menu.js';
import {NativeSkillTargeting} from './skill-targeting.mjs';
import {submitNativeSkill} from './skill-input.mjs';
import {networkFamiliar} from '../../src/network_associates.js';
import {OBJECT_INVALID} from '../../src/game_object_array.js';
import {networkSpellUsesLeft} from '../../src/network_spellbook.js';
import {prepareNetworkItemMenu} from '../../src/network_item_menu.js';

// Native controls submit menu identity + physical slot, never trusted action
// names or spell/feat bindings. The original providers own all menu policy.
export class ActionService {
 constructor({session,connection,text,active,send,icon=async()=>null,diagnose=()=>{},onSubmit=()=>{}}){
  Object.assign(this,{session,connection,text,active,send,icon,diagnose,onSubmit});
  this.serial=0;this.epoch=0;this.requestId=-1;this.menu=null;this.targetToken=0;
  this.targeter=new NativeSkillTargeting({world:()=>this.active()?session.world:null,tables:()=>this.rules??{},context:()=>this.context(),submit:request=>this.submit(request),
   onChange:state=>{
    this.targetToken++;
    if(this.targetScope&&this.owned(this.targetScope))this.emit({kind:'target-mode',token:this.targetToken,active:Boolean(state),...state,preview:state?this.targeter.presentation(null)?.preview:null});
   },report:(code,reason)=>diagnose(code,reason)});
 }
 context(){return{connection:this.connection,areaId:this.session.world.areaId,areaGeneration:this.session.areaGeneration,actorId:this.session.world.localObjectId};}
 capture(){const c=this.context();return{...c,actor:this.session.world.registry.get(c.actorId)};}
 owned(scope){return Boolean(scope&&scope.actor?.objectType===5&&this.active()&&!this.session.closed&&scope.connection===this.connection&&scope.areaId===this.session.world.areaId&&scope.areaGeneration===this.session.areaGeneration&&scope.actorId===this.session.world.localObjectId&&scope.actor===this.session.world.registry.get(scope.actorId)&&!scope.actor.replicationRemoved);}
 emit(payload){this.send({...payload,connection:this.connection,areaId:this.session.world.areaId,generation:this.session.areaGeneration});}
 reset(){this.epoch++;this.menu=null;this.stack=[];this.requestId=-1;this.targeter.reset();this.targetScope=null;}
 async tables(){
  this.tableWork??=Promise.all(['classes','spells','feat','domains','ranges','baseitems','iprp_spells','appearance','skills','ruleset','racialtypes'].map(async name=>[name,await this.text.rules(name)])).then(rows=>this.rules=Object.fromEntries(rows));
  return this.tableWork;
 }
 target(id){
  if(id===null||id===undefined)return null;
  const object=this.session.world.registry.get(id);
  const location=object?.inventoryLocation,contained=object?.objectType===6&&(location?.ownerId===this.session.world.localObjectId&&['I','R'].includes(location.channel)||location?.channel==='C'&&location.ownerId===this.session.world.containers.get('C'));
  if(!object||object.replicationRemoved||!contained&&object.areaId!==this.session.world.areaId)throw Error('Action target is no longer available');
  return object;
 }
 currentMenu(menuId){
  const state=this.menu;
  if(!state||state.pending||state.id!==menuId||!this.owned(state.scope)||state.target&&this.target(state.target.id)!==state.target)throw Error('Action menu is no longer available');
  if(state.target?.objectType===6&&state.itemState!==JSON.stringify([state.target.item,state.target.inventoryLocation]))throw Error('Item action menu is stale');
  return state;
 }
 async open({requestId,targetId,position,inventory=false}){
  const epoch=++this.epoch,scope=this.capture(),target=this.target(targetId),itemState=target?.objectType===6?JSON.stringify([target.item,target.inventoryLocation]):null;
  this.requestId=requestId;this.menu=null;this.stack=[];
  await this.tables();if(epoch!==this.epoch||!this.owned(scope))return;
  const options=await prepareNetworkSpellMenus(scope.actor,target,this.rules,{getResource:(...args)=>this.session.getResource(...args)},value=>this.text.resolve(value,scope.actorId),(code,reason)=>this.diagnose(code,reason),{...(inventory?{filter:8}:{}),familiar:networkFamiliar(this.session.world,scope.actor)});
  if(inventory)options.itemUseEntries=await prepareNetworkItemMenu(this.session.world,targetId,this.rules,value=>this.text.resolve(value,scope.actorId),(code,reason)=>this.diagnose(code,reason),{alive:()=>epoch===this.epoch&&this.owned(scope)});
  if(epoch!==this.epoch||!this.owned(scope)||target&&(target.replicationRemoved||this.session.world.registry.get(targetId)!==target)||target?.objectType===6&&itemState!==JSON.stringify([target.item,target.inventoryLocation]))return;
  const point=target?[...(target.replicated?.position??target.staticState?.position??[0,0,0])]:[position[0],-position[2],position[1]];
  this.menu={scope,target,point,requestId,inventory,itemState,view:networkRadialActions(target,scope.actor,options)};
  this.publish();
 }
 publish(){
  const state=this.menu;if(!state||!this.owned(state.scope))return;
  state.id=++this.serial;
  const menuId=state.id;
  const entries=state.view.entries.map(entry=>({slot:entry.slot,label:entry.label,icon:entry.icon,action:entry.action??null,disabled:Boolean(entry.disabled),submenu:Boolean(entry.children),uses:entry.uses??null,spellId:entry.binding?.spellId??null,featId:entry.binding?.featId??null,quickbarBinding:entry.quickbarBinding??null,canDrag:!entry.disabled&&!entry.children&&Boolean(entry.quickbarBinding)}));
  this.emit({kind:'action-menu',requestId:state.requestId,menuId:state.id,title:state.view.title,depth:this.stack.length,entries});
  // Original icon decoding is presentation-only and cannot hold the wheel.
  for(const entry of entries)if(entry.icon)void this.icon(entry.icon).then(image=>{if(image&&this.menu===state&&state.id===menuId&&this.owned(state.scope))this.emit({kind:'action-icon',requestId:state.requestId,menuId,slot:entry.slot,image});}).catch(()=>{});
 }
 async select({menuId,slot}){
  const state=this.currentMenu(menuId),entry=state.view.entries.find(row=>row.slot===slot);
  if(!entry||entry.disabled)throw Error('That action is unavailable in this context');
  if(entry.children){this.stack.push(state.view);state.view=entry.children();this.publish();return;}
  this.targetScope=state.scope;
  state.pending=true;
  try{await this.dispatch(entry,state);}catch(error){if(this.menu===state)state.pending=false;throw error;}
  if(this.menu===state){this.menu=null;this.stack=[];this.emit({kind:'action-close',requestId:state.requestId});}
 }
 back({menuId}){const state=this.currentMenu(menuId);if(this.stack.length){state.view=this.stack.pop();this.publish();}else this.cancel({requestId:state.requestId});}
 cancel({requestId}){if(requestId!==this.requestId)return;this.epoch++;this.menu=null;this.stack=[];this.emit({kind:'action-close',requestId});}
 async defaultInteraction({targetId,position,run=true}){
  const scope=this.capture(),target=this.target(targetId);if(!this.owned(scope))throw Error('Controlled actor is no longer available');
  if(!target)return this.session.walkTo({areaId:scope.areaId,areaGeneration:scope.areaGeneration,position:[position[0],-position[2],position[1]],run});
  const action=networkDefaultInteraction(target);if(!action)throw Error('No interaction is available');
  return this.dispatch({action},{scope,target,run,point:[...(target.replicated?.position??[0,0,0])]});
 }
 async dispatch(entry,state){
  const {scope,target,point}=state;if(!this.owned(scope))throw Error('Action belongs to a retired controlled actor');
  const base={areaId:scope.areaId,areaGeneration:scope.areaGeneration,actorId:scope.actorId},targetId=target?.id??OBJECT_INVALID;
  if(entry.action==='quickbar.assign'&&state.shortcutCommit)return state.shortcutCommit(entry.binding);
  if(entry.action==='object.examine')return this.session.examine({...base,targetId});
  if(entry.action==='spell.cast')return this.targeter.radial(entry.binding,target,point);
  if(entry.action==='spellLike.use')return this.targeter.radialInnate(entry.binding,target,point);
  if(entry.action==='feat.use')return this.targeter.radialFeat(entry.binding,target,point);
  if(entry.action==='item.use'&&entry.binding)return this.targeter.beginItem(entry.binding.itemId,entry.binding.packed);
  if(entry.action==='item.use'&&state.inventory&&this.inventoryAction)return this.inventoryAction('activate',target);
  if(entry.action==='item.drop'&&state.inventory&&this.inventoryAction)return this.inventoryAction('drop',target);
  if(entry.action==='item.pickup'&&state.inventory&&this.inventoryAction)return this.inventoryAction('move',target);
  if(entry.action==='item.pickup')return this.session.itemAction({...base,itemId:targetId,operation:'pickup'});
  if(entry.action==='item.drop')return this.session.itemAction({...base,itemId:targetId,operation:'drop'});
  if(entry.action==='rest')return this.session.rest(base);
  if(['associate.possessFamiliar','associate.possess'].includes(entry.action))return this.session.possessFamiliar(base);
  if(entry.action==='associate.command')return this.session.associateCommand({...base,targetId,command:entry.command});
  if(entry.action==='associate.quickChat')return this.session.quickChat({...base,quickChat:entry.quickChat});
  if(entry.action==='movement.moveTo')return this.session.walkTo({...base,position:point,run:true});
  const action=({'placeable.use':'object.use','combat.bash':'combat.attack'})[entry.action]??entry.action;
  if(['door.open','door.close','door.transition','trigger.transition','conversation.start','object.use','combat.attack'].includes(action))return this.session.interact({...base,targetId,action,run:state.run??true});
  this.diagnose('godot.action-handler-unavailable',entry.action);
  throw Error(`${entry.label??entry.action} is not available yet`);
 }
 async submit(request){
  if(!this.owned(this.targetScope))throw Error('Target selection belongs to a retired controlled actor');
  const base={areaId:this.targetScope.areaId,areaGeneration:this.targetScope.areaGeneration,actorId:this.targetScope.actorId};
  const method=({skill:'useSkill',feat:'useFeat',mode:'changeMode',innate:'castSpellLike',item:'useItem','script-target':'selectScriptTarget'})[request.kind]??'castSpell';
  const beforeUses=method==='castSpell'?networkSpellUsesLeft(this.targetScope.actor,this.rules,request.spellId,request.classIndex??0,request.domainLevel??0,request.metamagic??0):null;
  const result=request.kind==='skill'?await submitNativeSkill(this.session,this.targetScope,request):await this.session[method]({...base,...request});
  this.onSubmit({operation:method,targetId:request.targetId,spellId:request.spellId,classIndex:request.classIndex,domainLevel:request.domainLevel,metamagic:request.metamagic,beforeUses,...(method==='useItem'?{itemId:request.itemId,propertyIndex:request.propertyIndex,variant:request.variant}:{}),...(method==='useSkill'?{packedSkill:request.packedSkill,skillId:request.packedSkill&255,auxiliary:(request.packedSkill>>>16)&255}:{}),...(method==='changeMode'?{modeId:request.modeId}:{}),...base});
  return result;
 }
 async serverTarget(){const scope=this.capture();await this.tables();if(!this.owned(scope))return;this.targetScope=scope;this.targeter.beginServer();}
 hover({token,targetId}){
  if(token!==this.targetToken||!this.targeter.active||!this.owned(this.targetScope))return;
  this.emit({kind:'target-hover',token,targetId,presentation:this.targeter.presentation(this.target(targetId))});
 }
 async selectTarget({token,targetId,position}){
  if(token!==this.targetToken||!this.targeter.active||!this.owned(this.targetScope))throw Error('Target selection is no longer available');
  return this.targeter.select(this.target(targetId),[position[0],-position[2],position[1]]);
 }
 cancelTarget({token}){if(token===this.targetToken)this.targeter.reset();}
}
