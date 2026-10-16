import {creatureTalent,hasTalent} from './talent.js';
import {classSpellTalent,spellLikeTalent,itemSpellTalent,spellSuitability} from './spell_talent.js';
import {creatureRoot} from './creature_rules.js';
import {intEntry} from './combat_stats.js';
import {canUseItem} from './item_use.js';
import {talentSpell} from './spell_metadata.js';
import {createSpellClassState} from './spell_book.js';
import {addTalentOnObject,addTalentAtLocation,scriptUseTalent} from './talent_actions.js';
import {usePickpocketSkill} from './skill_action.js';

// ClassInfo1403ee670 owns ten known/memorized pools and zeroed per-day
// counters. ReadStats140410bfb imports non-memorizing per-day BYTE cells.
// GFF spell import is a separate owner after these constructor-owned pools.
export function initializeTalentSpellState(o,rules){
  const root=creatureRoot(o);if(!Array.isArray(root?.ClassList))throw new Error('Native talent class storage is unavailable');
  o.nativeTalentClasses=root.ClassList.slice(0,root.ClassList.length&255).map(c=>{
    const memo=intEntry(rules.classes,c.Class&255,'MemorizesSpells').value!==0;
    const perDay=Array(10).fill(0);
    if(!memo)for(let level=0;level<Math.min(10,(c.SpellsPerDayList?.length??0)&255);level++)perDay[level]=(c.SpellsPerDayList[level].NumSpellsLeft??0)&255;
    return{...createSpellClassState(),perDay};
  });
  o.nativeSpellLikeAbilities=(root.SpecAbilityList??[]).slice(0,(root.SpecAbilityList?.length??0)&255).map(e=>({id:(e.Spell??0)&65535,remaining:Number((e.SpellFlags??0)!==0),casterLevel:Math.min((e.SpellCasterLevel??0)&255,15)}));
}

export class TalentRuntime {
  constructor(session){this.session=session;}
  classState(o,index){
    if(!Array.isArray(o.nativeTalentClasses))throw new Error('Native talent spell state is unavailable');
    const state=o.nativeTalentClasses[index&255];if(!state)throw new Error('Native talent class index is outside imported storage');return state;
  }
  spellPool(o,index,name){const pool=this.classState(o,index)[name];if(pool===null)throw new Error(`Native ${name} caster spell import is unavailable`);return pool;}
  hasSpell(o,id,meta=0){return this.session.spellBook.hasTalent(o,id,meta);}
  providers(){
    const s=this.session,rules=s.characterRules,r=s.itemRestrictionProviders();
    const p={random:()=>s.random.next(),hasFeat:(o,id)=>s.combat.hasFeat(o,id),remainingFeatUses:(o,id)=>s.combat.remainingUses(o,id),skillRank:(o,id)=>s.combat.skill(o,id,null,0),
      hasSpellTalent:(o,id,meta)=>this.hasSpell(o,id,meta),spellLikeList:o=>{if(!Array.isArray(o.nativeSpellLikeAbilities))throw new Error('Native spell-like pool is unavailable');return o.nativeSpellLikeAbilities;},
      spellsPerDayLeft:(o,i,l)=>this.classState(o,i).perDay[l],knownCount:(o,i,l)=>this.spellPool(o,i,'known')[l].length,
      knownSlot:(o,i,l,n)=>this.spellPool(o,i,'known')[l][n],memorizedCount:(o,i,l)=>this.spellPool(o,i,'memorized')[l].length,
      memorizedSlot:(o,i,l,n)=>this.spellPool(o,i,'memorized')[l][n],slotMetamagic:(o,d)=>this.spellPool(o,d.classIndex,'memorized')[d.level][d.slot]?.metamagic??0,
      area:o=>s.registry.get(o.areaId),effectivePVP:a=>s.getPVPSetting(a),metamagicCost:meta=>s.spellBook.metamagicCost(meta),
      equipmentSlot:(o,slot)=>s.equipmentSlot(o,slot),hasProperty:r.hasProperty,activeProperties:i=>{if(!i.nativeItemLoaded)throw new Error('Native talent active item properties are unavailable');return i.activeProperties;},
      charges:i=>i.charges,baseItem:i=>i.baseItem,equipableSlots:i=>s.items.baseInfo(i).equipableSlots,
      repositoryIds:o=>{if(!o.nativeInventoryImported)throw new Error('Native talent repository is unavailable');return[...o.nativeRepository.ids()];},
      itemById:id=>{const i=s.registry.get(id);return i?.objectType===6?i:null;},
      canUseItem:(o,i,ignore)=>canUseItem(o,i,ignore,s.itemUseProviders())};
    p.suitable=(o,spell,category,max,details)=>spellSuitability(o,spell,category,max,details,p);
    p.spellLikeTalent=(o,c,m)=>spellLikeTalent(o,c,m,rules,p);
    p.knownSpellTalent=(o,c,m,i)=>classSpellTalent(o,c,m,i,false,rules,p);
    p.memorizedSpellTalent=(o,c,m,i)=>classSpellTalent(o,c,m,i,true,rules,p);
    p.itemSpellTalent=(o,c,m)=>itemSpellTalent(o,c,m,rules,p);
    return p;
  }
  choose(o,category,maxCR){return creatureTalent(o,category,maxCR,this.session.characterRules,this.providers());}
  has(o,talent){if(o?.objectType!==5)return 0;return hasTalent(o,talent.type,talent.id,talent.metamagic,this.session.characterRules,this.providers());}
  actionProviders(){
    const s=this.session;
    return {creature:id=>{const o=s.registry.get(id);return o?.objectType===5?o:null;},
      position:o=>[Math.fround(o.position[0]),Math.fround(-o.position[2]),Math.fround(o.position[1])],
      area:o=>s.registry.get(o.areaId)??null,random:()=>s.random.next(),clearActions:o=>s.combat.clearActions(o),
      useFeat:(...args)=>s.feats.use(...args),useSkill:(...args)=>usePickpocketSkill(...args,s.skills.providers()),
      useItem:(...args)=>s.items.use(...args),
      addCast:(o,r)=>s.spells.add(o,r)};
  }
  scriptProviders(){
    const p=this.actionProviders();return {creature:p.creature,
      onObject:(...args)=>addTalentOnObject(...args,p),atLocation:(...args)=>addTalentAtLocation(...args,p)};
  }
  script(ordinal,args,frame){return scriptUseTalent(ordinal,frame.self,{talent:()=>args[0],object:()=>args[1],location:()=>args[1]},this.scriptProviders());}
  scriptStack(ordinal,vm,frame){return scriptUseTalent(ordinal,frame.self,{talent:()=>vm.pop(frame,'talent'),object:()=>vm.pop(frame,'object'),location:()=>vm.pop(frame,'location')},this.scriptProviders());}
}
