import {castingSpell,talentSpell} from './spell_metadata.js';
import {prepareSpellTarget} from './spell_targeting.js';
import {radialSpellTargetAllowed,radialSpellCastRequest} from './spell_radial.js';
import {prepareFeatTarget,featTargetAllowed} from './feat_targeting.js';
import {selectRadialFeat} from './feat_radial.js';
import {featActivationInfo,featActivationSpell} from './use_feat.js';
import {networkItemQuickbarProviders} from './network_quickbar_items.js';
import {prepareItemTarget,itemCreatureTargetVeto,confirmItemTarget} from './item_targeting.js';

// Client-local target selection only. All availability, resource consumption,
// actions, rolls, impacts and effects remain authoritative server operations.
export class NetworkSpellTargeting{
 constructor({world,tables,context,submit,inventoryOpen=()=>false,onChange=()=>{},report=()=>{}}){Object.assign(this,{world,tables,context,submit,inventoryOpen,onChange,report});this.pending=null;}
 reset(){this.pending=null;this.onChange(null);}
 definition(id){const rules=this.tables(),spell=castingSpell(rules,id);return spell?{...spell,children:talentSpell(rules,id).children}:null;}
 actor(){const w=this.world();return w?.registry.get(w.localObjectId);}
 async begin(binding){
  if(binding.type===1)return this.beginItem(binding.itemId,binding.intParam);
  if(binding.type===4)return this.beginFeat(binding.intParam);
  this.reset();const actor=this.actor();if(!actor)throw new Error('Controlled caster is unavailable');
  const request=binding.type===44?{kind:'innate',spellId:binding.intParam,casterLevel:binding.domainLevel&15}:{spellId:binding.intParam,classIndex:binding.classIndex&7,domainLevel:binding.domainLevel&15,metamagic:binding.metamagic&63,spontaneous:0};
  const prepared=prepareSpellTarget(actor,request,{spell:id=>this.definition(id)},{inventoryMode:Number(this.inventoryOpen())});
  if(prepared.mode==='unavailable')throw new Error('Spell targeting metadata is unavailable');
  this.pending={...prepared,controlledId:actor.id,world:this.world(),context:structuredClone(this.context())};
  if(prepared.mode==='self')return this.select(actor,actor.replicated.position);
  this.onChange({spellId:prepared.request.spellId,targetTypes:prepared.targetTypes});return{targeting:true};
 }
 get active(){return Boolean(this.pending);}
 current(){const p=this.pending;if(!p||p.world!==this.world()||p.controlledId!==this.world()?.localObjectId||JSON.stringify(p.context)!==JSON.stringify(this.context())){this.reset();throw new Error('Action selection belongs to an old area or controlled creature');}return p;}
 async select(target,position){
  const p=this.current(),actor=this.actor();
  if(p.itemPlan){
   const providers=this.itemProviders(),type=target?.objectType??2,plan=p.itemPlan;
   if(!plan.targetTypes.some(([registered])=>registered===type)&&plan.mode!=='self'||plan.creatureVeto&&itemCreatureTargetVeto(plan.itemId,plan.packed,target?.id??0x7f000000,providers))throw new Error('That target is not valid for this item');
   plan.targetId=target?.id??0x7f000000;plan.point=[...position];this.reset();return confirmItemTarget(plan,{...providers,player:()=>actor,use:(_actor,itemId,packed,targetId,point)=>this.submit({kind:'item',itemId,propertyIndex:packed&255,variant:(packed>>>16)&255,targetId,position:point}),clearPreview:()=>{},clearRange:()=>{},dispose:()=>{}});
  }
  const allowed=p.request.kind==='feat'?featTargetAllowed(p.definition,target):radialSpellTargetAllowed(p.definition,actor,target);if(!allowed)throw new Error('That target is not valid for this action');
  const request={...p.request,targetId:target?.id??0x7f000000,position};this.reset();return this.submit(request);
 }
 itemProviders(){
  const w=this.world(),p=networkItemQuickbarProviders(w,this.tables(),{},{report:this.report}),item=p.item;
  p.item=id=>{const value=item(id);return value?{...value,possessorId:value.canonical.inventoryLocation?.ownerId??value.canonical.equipmentOwnerId??0x7f000000}:null;};
  p.creature=id=>{const o=w.registry.get(id);return o?.objectType===5&&!o.replicationRemoved?o:null;};p.position=o=>o.replicated?.position??o.canonical?.replicated?.position??[0,0,0];
  p.preview=spell=>this.report('network.item-target-preview-unhandled','Native item targeting preview is not connected',{spellId:spell.id});p.warning=message=>this.report('network.item-target-warning',message);return p;
 }
 async beginItem(itemId,packed){
  this.reset();const actor=this.actor();if(!actor)throw new Error('Controlled item user is unavailable');
  const plan=prepareItemTarget(itemId,packed,this.itemProviders(),{inventoryMode:Number(this.inventoryOpen())});if(plan.mode==='unavailable')throw new Error('Item targeting metadata is unavailable');
  this.pending={itemPlan:plan,controlledId:actor.id,world:this.world(),context:structuredClone(this.context())};
  if(plan.mode==='self')return this.select(actor,[0,0,0]);
  this.onChange({itemId,packed,targetTypes:plan.targetTypes});return{targeting:true};
 }
 async radial(binding,target,position){
  const actor=this.actor();if(!actor||!radialSpellTargetAllowed(this.definition(binding.spellId),actor,target))throw new Error('That target is not valid for this spell');
  this.reset();return this.submit(radialSpellCastRequest(binding,actor,target,position));
 }
 async radialInnate(binding,target,position){
  const actor=this.actor();if(!actor||!radialSpellTargetAllowed(this.definition(binding.spellId),actor,target))throw new Error('That target is not valid for this ability');this.reset();return this.submit({kind:'innate',spellId:binding.spellId&65535,casterLevel:binding.domainLevel&15,targetId:target?.id??0x7f000000,position:position?.map(Math.fround)??[0,0,0]});
 }
 featProviders(){const rules=this.tables();return{feat:id=>featActivationInfo(rules,id),spell:id=>featActivationSpell(rules,id)};}
 async beginFeat(featId,auxiliary){
  this.reset();const actor=this.actor();if(!actor)throw new Error('Controlled creature is unavailable');const plan=prepareFeatTarget({kind:'feat',featId,...(auxiliary===undefined?{}:{auxiliary})},this.featProviders());
  if(plan.mode==='unavailable')throw new Error('Feat targeting metadata is unavailable');
  if(plan.mode==='mode')return this.submit({kind:'mode',modeId:plan.modeId});
  if(plan.mode==='self')return this.submit({...plan.request,targetId:actor.id,position:null});
  this.pending={...plan,controlledId:actor.id,world:this.world(),context:structuredClone(this.context())};this.onChange({featId:plan.request.featId,targetTypes:plan.targetTypes});return{targeting:true};
 }
 async radialFeat(binding,target,position){
  const actor=this.actor();if(!actor)throw new Error('Controlled creature is unavailable');const packed=(binding.featId&65535)|((binding.auxiliary??0)<<16),plan=selectRadialFeat(packed,{controlled:true,assignment:false,self:target?.id===actor.id,...this.featProviders(),warning:message=>{throw new Error(message);}});
  this.reset();if(plan.mode==='mode')return this.submit({kind:'mode',modeId:plan.modeId});if(plan.mode==='target')return this.beginFeat(plan.featId,plan.auxiliary);
  if(plan.mode!=='use')throw new Error('Feat metadata is unavailable');return this.submit({kind:'feat',featId:plan.featId,auxiliary:plan.auxiliary,targetId:target?.id??0x7f000000,position:position??null});
 }
}
