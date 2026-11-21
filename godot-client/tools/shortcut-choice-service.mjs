import {NetworkQuickbarView} from '../../src/network_quickbar_view.js';
import {quickbarAssignmentMenu} from '../../src/quickbar_menu.js';
import {spellChoiceBindings} from '../../src/spell_family.js';
import {configureNetworkItemShortcut} from '../../src/network_quickbar_items.js';
import {emptyQuickbarButton} from '../../src/quickbar.js';

// Reuse the existing choice builder without constructing its DOM presenter.
// Its ruleName/spellChoice/choices methods operate only on these data services;
// Godot and ActionService own presentation, input and private menu identities.
export class ShortcutChoiceService{
 constructor({actions,shortcuts,ensure=async()=>{},onAssign=()=>{}}){Object.assign(this,{actions,shortcuts,ensure,onAssign});}
 state(scope){const a=scope.actor,w=this.actions.session.world;return JSON.stringify([w.tlkOverrideVersion,a.replicated?.stats?.classes,a.playerState?.spellbooks,a.playerState?.feats,a.playerState?.bonusFeats,a.playerState?.specialAbilities,a.inventoryStats?.feats,a.inventoryStats?.skills,a.companionId,a.familiarId,w.party,[...w.registry.objects.values()].filter(o=>o.objectType===6||o.replicated?.master===a.id).map(o=>[o.id,o.replicationRemoved,o.item,o.inventoryLocation,o.replicated?.master,o.replicated?.field908])]);}
 async choices(scope){
  const owner={world:()=>this.actions.owned(scope)?this.actions.session.world:null,tables:this.actions.rules,labels:new Map(),resolve:value=>this.actions.text.resolve(value,scope.actorId)};
  owner.ruleName=NetworkQuickbarView.prototype.ruleName.bind(owner);
  owner.spellChoice=NetworkQuickbarView.prototype.spellChoice.bind(owner);
  return NetworkQuickbarView.prototype.choices.call(owner);
 }
 async open({requestId,quickbarId,index}){
  if(!Number.isInteger(index)||index<0||index>=36)throw Error('Invalid shortcut index');
  const a=this.actions,epoch=++a.epoch,scope=a.capture();a.requestId=requestId;a.menu=null;a.stack=[];
  await a.tables();if(epoch!==a.epoch||!a.owned(scope))return;
  await this.ensure(scope);if(epoch!==a.epoch||!a.owned(scope))return;
  const q=this.shortcuts.quickCurrent(quickbarId),before=this.state(scope),groups=await this.choices(scope);
  if(epoch!==a.epoch||!a.owned(scope))return;
  if(before!==this.state(scope))throw Error('Shortcut choices changed. Reopen the menu to retry.');
  this.shortcuts.quickCurrent(quickbarId);
  const state={scope,target:null,point:[0,0,0],requestId,view:quickbarAssignmentMenu('Assign F'+(index%12+1),groups),assignment:{quickbarId,index}};
  if(q.scope.actor!==scope.actor)throw Error('Shortcut belongs to another actor');
  state.shortcutCommit=binding=>this.commit(state,binding);
  a.menu=state;a.publish();
 }
 async commit(state,binding){
  const a=this.actions,scope=state.scope,{quickbarId,index}=state.assignment;
  const valid=()=>a.menu===state&&a.owned(scope);
  if(!valid())throw Error('Shortcut choice is stale');
  return this.shortcuts.exclusive('shortcut',async()=>{
   await a.tables();if(!valid())throw Error('Shortcut choice is stale');
   const before=this.state(scope),groups=await this.choices(scope);
   if(!valid()||before!==this.state(scope))throw Error('Shortcut choices changed');
   const q=this.shortcuts.quickCurrent(quickbarId);
   if(q.scope.actor!==scope.actor||binding!==null&&![...spellChoiceBindings(groups.flatMap(g=>g.entries))].some(b=>JSON.stringify(b)===JSON.stringify(binding)))throw Error('That shortcut is no longer available');
   let button=binding??{type:0};
   if(binding?.type===1){const configured=configureNetworkItemShortcut(a.session.world,a.rules,Object.assign(emptyQuickbarButton(),q.buttons[index]),binding);if(!configured)throw Error('That item cannot be assigned');button=configured.button;}
   await a.session.assignQuickbar({areaId:scope.areaId,areaGeneration:scope.areaGeneration,index,button});
   this.onAssign({index,button:structuredClone(button)});
   if(valid())await this.shortcuts.refresh(true);
  });
 }
}
