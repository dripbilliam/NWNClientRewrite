import {OBJECT_INVALID} from './game_object_array.js';
import {creatureRoot} from './creature_rules.js';
import {intEntry} from './combat_stats.js';
import {nativeStringEntry} from './spell_metadata.js';
import {runtimeDiagnostics} from './runtime_diagnostics.js';
import {updatePersonalSpace} from './personal_space.js';
import {updateAppearanceInfo} from './appearance_info.js';
import {polymorphCreature,unpolymorphCreature} from './polymorph_form.js';
import {setItemIdentified} from './item_identification.js';

// Local-authority binding. The transformation keeps the SAME registry object,
// root, stats, equipment inventory and canonical IDs throughout both phases.
export class PolymorphRuntime{
 constructor(session){this.session=session;}
 providers(context){
  const s=this.session,e=s.effects,j=s.combat.jumpProviders(),ability=e.abilityProviders(),root=creatureRoot;
  return{
   table:()=>s.items.table('polymorph'),rowCount:t=>t.orderedRows?.length??t.rows.size,int:intEntry,string:nativeStringEntry,
   portraitId:o=>root(o).PortraitId??65535,portrait:o=>root(o).Portrait??'',setPortraitId:(o,v)=>{root(o).PortraitId=v;},setPortrait:(o,v)=>{root(o).Portrait=v;},
   sound:o=>root(o).SoundSetFile??65535,setSound:(o,v)=>{root(o).SoundSetFile=v;},
   copyCombatInformation:o=>{
    // No false native raw-cache claim: the current combat subsystem exposes
    // projected stats. Keep a labelled snapshot until UpdateCombatInformation
    // owns the native d70 layout; restoration itself never consumes a48.
    runtimeDiagnostics.record('combat.polymorph-snapshot-approximate','Polymorph saved combat projection; full native CCombatInformation d70 cache is unavailable',s.diagnosticContext(o.id));
    return{representation:'combat-projection',value:structuredClone(o.stats.combat)};
   },
   armor:o=>{s.refreshCombat(o);return o.stats.combat.armorClass;},baseAttack:o=>o.stats.combat.baseAttackBonus,
   maximumHP:ability.maximumHP,fortitude:o=>o.stats.combat.saves.fortitude,reflex:o=>o.stats.combat.saves.reflex,will:o=>o.stats.combat.saves.will,
   setBaseAbility:(...args)=>s.setBaseAbility(...args),currentHP:o=>s.hitPoints(o.id,false),writeHP:ability.writeBaseHP,dead:o=>Number(s.isDead(o)),
   equipped:(...args)=>s.equipmentSlot(...args),unequip:(...args)=>s.unequipItem(...args),equip:(...args)=>s.equipItem(...args),
   item:id=>{const o=s.registry.get(id);return o?.objectType===6?o:null;},constructItem:()=>s.register('item',`runtime:item:${s.registry.nextObjectId[0]}`,{areaId:OBJECT_INVALID,position:[0,0,0],authored:{},equipmentSlot:null,deferTagLookup:true}),
   loadItem:(o,ref)=>s.loadItemTemplate(o,ref,''),destroyItem:o=>s.lifecycle.destroy(o),identified:setItemIdentified,
   create:(...args)=>e.create(...args),copyConstruct:(...args)=>e.copyConstruct(...args),setCreator:(...args)=>e.setCreator(...args),effects:o=>o.effects,
   apply:(o,value,loading)=>e.applyNative(value,o.id,context,loading),remove:(o,id)=>e.remove(o.id,id,context),
   personalSpace:o=>updatePersonalSpace(o,s.characterRules,{warning:message=>s.combat.warning(o,message)}),
   appearanceInfo:o=>{updateAppearanceInfo(o,s.characterRules);s.refreshCombat(o);},
   area:o=>s.registry.get(o.areaId)??null,position:j.position,setPosition:j.setPosition,safeLocation:j.safeLocation,
   removeFromArea:(...args)=>s.lifecycle.removeCreatureArea(...args),addToArea:(...args)=>s.lifecycle.addCreatureArea(...args)
  };
 }
 transform(o,form,parent,loading,context){return polymorphCreature(o,form,parent,loading,this.providers(context));}
 restore(o,parent,context){return unpolymorphCreature(o,parent,this.providers(context));}
}
