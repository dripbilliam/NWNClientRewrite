import {intEntry,rulesetInt} from './combat_stats.js';
import {creatureRoot} from './creature_rules.js';
import {runtimeDiagnostics} from './runtime_diagnostics.js';
import {createSpellClassState,importSpellBook,spellUsesLeft,metamagicLevelCost,spellLevelByClass,spellAbilityProviders,updateMemorizedSpellSlots,hasSpellTalent,scriptHasSpell,consumeSpellReady,adjustSpellUsesPerDay,spellLikeCasterLevel,setMemorizedSpellSlot,clearMemorizedSpellSlot} from './spell_book.js';
import {receiveSpellPreparationInput,nextPreparationSpell} from './spell_preparation.js';
import {talentSpell,castingSpell,savingThrowSpell} from './spell_metadata.js';
import {commandSpellLevel,commandSpellUses} from './spell_cast_request.js';
import {casterLevel,nativeClassLevel,nativeClassIndex,nativeFeatSourceClass} from './spell_caster_level.js';
import {checkSpellComponents,automaticQuicken} from './spell_components.js';
import {computeSpellSaveDC} from './spell_save_dc.js';
import {scriptAbilityModifier} from './ability_modifier_cache.js';

const names=['Str','Dex','Con','Int','Wis','Cha'];
const physical=(table,row)=>table?.orderedRows?table.orderedRows[row]:table?.rows?.get(row);
const field=(row,name)=>row?.[Object.keys(row??{}).find(k=>k.toLowerCase()===name.toLowerCase())];
// Shared canonical spellbook adapter. Casting, counterspells and impact
// owners are separate; none of these queries manufactures a spell effect.
export class SpellBookRuntime {
  constructor(session){this.session=session;}
  warning(o,message){runtimeDiagnostics.record('spells.native-warning',message,this.session.diagnosticContext(o.id));}
  castingSpell(id){return castingSpell(this.session.characterRules,id);}
  components(o,spell,index,domain,meta){
    return checkSpellComponents(o,spell,index,domain,meta,this.session.characterRules,{spell:id=>this.castingSpell(id),hasFeat:(o,id)=>this.session.combat.hasFeat(o,id),
      classType:(o,index)=>creatureRoot(o).ClassList[index]?.Class??255,level:(id,type)=>this.level(id,type),metamagicCost:mask=>this.metamagicCost(mask)});
  }
  componentProviders(){return{spell:id=>this.castingSpell(id),hasFeat:(o,id)=>this.session.combat.hasFeat(o,id),
    classType:(o,index)=>creatureRoot(o).ClassList[index]?.Class??255,level:(id,type)=>this.level(id,type),metamagicCost:mask=>this.metamagicCost(mask)};}
  automaticQuicken(o,spell,index,domain,meta){return automaticQuicken(o,spell,index,domain,meta,this.session.characterRules,this.componentProviders());}
  classAbility(type,primary=false){
    const row=physical(this.session.characterRules.classes,type&255);if(!row)throw new Error('Native spell save DC class storage is unavailable');
    const text=String(field(row,primary?'PrimaryAbil':'SpellcastingAbil')??'').split('\0')[0];
    const index=names.findIndex(name=>name.toUpperCase()===text);
    if(index<0&&!primary)throw new Error('Native class casting ability reads uninitialized loader storage');
    return index<0?0:index; // primary ctor+49a=0; casting+4e8 has no initializer.
  }
  castingMod(o,index){
    index&=255;if(index>=8){this.warning(o,'Trying to calculate primary ability modifier for invalid class!');return 0;}
    const type=creatureRoot(o).ClassList[index]?.Class??255;
    return scriptAbilityModifier(o,this.classAbility(type));
  }
  saveDC(o,spellId=o?.nativeSpellId218){
    if(o?.objectType===11){if(!Number.isInteger(o.nativeSpellSaveDC340))throw new Error('Native area-effect spell save DC is unavailable');return o.nativeSpellSaveDC340|0;}
    if(o?.objectType!==5)return 14;
    const s=this.session;
    return computeSpellSaveDC(o,spellId,s.characterRules,{spell:id=>this.castingSpell(id),effects:o=>o.effects,
      effectInteger:(e,index)=>{const v=e.integers?.[index];if(!Number.isInteger(v))throw new Error('Native spell save DC effect integer is unavailable');return v;},
      classIndex:nativeClassIndex,classAbility:type=>this.classAbility(type),classPrimaryAbility:type=>this.classAbility(type,true),abilityMod:scriptAbilityModifier,
      featSource:(o,id)=>nativeFeatSourceClass(o,id,message=>this.warning(o,message)),classLevel:(o,...args)=>nativeClassLevel(o,...args,s.characterRules),
      castingMod:(o,index)=>this.castingMod(o,index),classType:(o,index)=>creatureRoot(o).ClassList[index]?.Class??255,
      negativeLevels:(o,index)=>creatureRoot(o).ClassList[index]?.skillPenaltyByte??0,level:(id,type)=>this.level(id,type),
      school:spell=>savingThrowSpell(s.characterRules,spell.id).school,hasFeat:(o,id)=>s.combat.hasFeat(o,id)});
  }
  casterLevel(o){
    if(!o||o.objectType<5||o.objectType>14)return 0;
    const s=this.session;
    return casterLevel(o,{asCreature:o=>o.objectType===5?o:null,asPlaceable:o=>o.objectType===9?o:null,asAreaOfEffect:o=>o.objectType===11?o:null,
      effects:o=>{if(!Array.isArray(o.effects))throw new Error('Native caster effect list is unavailable');return o.effects;},
      effectInteger:(e,index)=>{const v=e.integers?.[index];if(!Number.isInteger(v))throw new Error('Native caster effect integer is unavailable');return v;},
      classLevel:(o,...args)=>nativeClassLevel(o,...args,s.characterRules),classIndex:nativeClassIndex,
      featSource:(o,id)=>nativeFeatSourceClass(o,id,message=>this.warning(o,message)),abilityLevel:spellLikeCasterLevel,
      spell:id=>talentSpell(s.characterRules,id)});
  }
  classTable(id,kind){
    const row=physical(this.session.characterRules.classes,id),name=String(field(row,kind)??'****').toLowerCase();
    if(!name||name==='****')return null;
    const table=this.session.characterRules.classTables?.get(name);if(!table)throw new Error(`Native spell class table ${name} is unavailable`);return table;
  }
  classGain(id,level,spellLevel){
    level&=255;spellLevel&=255;if(((level-1)&255)>=40)return 255;
    const table=this.classTable(id,'SpellGainTable');if(!table)return 255;
    const count=intEntry(table,level-1,'NumSpellLevels');
    if(!count.found)throw new Error('Native spell gain level-count scratch value is unavailable');
    if(spellLevel>=(count.value&255))return 255;
    const amount=intEntry(table,level-1,`SpellLevel${spellLevel}`);return amount.found?amount.value&255:255; // LoadSpellGainTable14029bb06..14029bb09.
  }
  knownCapacity(o,index,level){
    const rules=this.session.characterRules,c=creatureRoot(o).ClassList[index&255];if(!c)return 0;
    const row=physical(rules.classes,c.Class&255),classLevel=c.ClassLevel&255,gain=this.classTable(c.Class&255,'SpellGainTable'),known=this.classTable(c.Class&255,'SpellKnownTable');
    if(((classLevel-1)&255)>=40||!gain||!known||level>=(intEntry(gain,classLevel-1,'NumSpellLevels').value&255))return 0;
    if(intEntry(rules.classes,c.Class&255,'SpellbookRestricted').value!==0&&intEntry(rules.classes,c.Class&255,'LearnScroll').value===0&&level!==0&&
      (intEntry(known,classLevel-1,`SpellLevel${level-1}`).value&255)===0){
      const name=names.find(n=>n.toUpperCase()===String(field(row,'SpellcastingAbil')).toUpperCase());
      if(!name)throw new Error('Native known-spell base ability is uninitialized');
      const root=creatureRoot(o);let classGain=0;
      const resource=String(field(row,'StatGainTable')??'****').toLowerCase(),statTable=resource==='****'?null:rules.gains?.get(resource);
      if(resource!=='****'&&!statTable)throw new Error('Native known-spell class stat gain table is unavailable');
      if(statTable)for(let n=1;n<=classLevel;n++)classGain=(classGain+intEntry(statTable,n,name.toUpperCase()).value)&255;
      const racial=intEntry(rules.racialtypes,(root.Race??0)&65535,`${name}Adjust`).value;
      if(((root[name]+classGain+racial)&255)<level+10)return 0;
    }
    return intEntry(known,classLevel-1,`SpellLevel${level}`).value&255;
  }
  providers(o){
    const s=this.session,rules=s.characterRules;
    return{...spellAbilityProviders(o),warning:message=>this.warning(o,message),hasFeat:(actor,id)=>s.combat.hasFeat(actor,id),
      possessed:actor=>Number((actor.associateType&65535)===3&&Boolean(s.combat.broadcastProviders().client(actor.id))),
      arcaneClass:id=>Number(intEntry(rules.classes,id,'Arcane').value!==0),classSpellGain:(...args)=>this.classGain(...args),
      updateMemorizedSlots:actor=>updateMemorizedSpellSlots(actor,rules,this.providers(actor)),
      knownSpellsLeft:(actor,index,level)=>{
        const c=creatureRoot(actor).ClassList[index],capacity=this.knownCapacity(actor,index,level);
        if(intEntry(rules.classes,c.Class&255,'MemorizesSpells').value!==0){this.warning(actor,'ComputeNumberKnownSpellsLeft() only valid for non-memorizing classes');return 0;}
        const count=actor.nativeTalentClasses[index].known[level].length&65535;return count<capacity?(capacity-count)&255:0;
      }};
  }
  initialize(o,readyDefault=0){
    const root=creatureRoot(o);
    o.nativeTalentClasses??=(root.ClassList??[]).slice(0,(root.ClassList?.length??0)&255).map(()=>createSpellClassState());
    const perDay=(root.ClassList??[]).map(c=>{
      const counts=Array(10).fill(0);
      if(intEntry(this.session.characterRules.classes,c.Class&255,'MemorizesSpells').value===0)
        for(let level=0;level<Math.min(10,(c.SpellsPerDayList?.length??0)&255);level++)counts[level]=(c.SpellsPerDayList[level].NumSpellsLeft??0)&255;
      return counts;
    });
    importSpellBook(o,root,this.session.characterRules,this.providers(o),readyDefault);
    o.nativeTalentClasses.forEach((state,index)=>{state.perDay=perDay[index];});
  }
  uses(o,id,index,domainLevel=0,meta=0){return spellUsesLeft(o,id,index,domainLevel,meta,this.session.characterRules,this.providers(o));}
  set(o,index,slot,id,domain,meta,check=1){return setMemorizedSpellSlot(o,index,slot,id,domain,meta,check,this.session.characterRules,this.providers(o));}
  clear(o,index,level,slot){return clearMemorizedSpellSlot(o,index,level,slot,this.providers(o));}
  inputPreparation(request){
    const clear=request.clear===true,values=clear?[request.classIndex,request.level,request.slot]:[request.classIndex,request.spellId,request.slot,request.domainLevel,request.metamagic];let cursor=0;
    return receiveSpellPreparationInput(null,clear,{clientObject:()=>this.session.player,asCreature:o=>o.objectType===5?o:null,
      overflow:()=>0,underflow:()=>0,readByte:()=>values[cursor++],readDword:()=>values[cursor++],spell:id=>this.castingSpell(id),
      set:(...args)=>this.set(...args),clear:(...args)=>this.clear(...args)});
  }
  preparationSpells(o,index,level,meta=0){
    const rules=this.session.characterRules,record=creatureRoot(o).ClassList[index&255];if(!record)throw new Error('Native preparation class storage is unavailable');
    const type=record.Class&255,state={cursor:0,domain:0},result=[];
    const p={controlled:()=>o,restricted:type=>intEntry(rules.classes,type,'SpellbookRestricted').value,
      knownCount:(actor,i,l)=>actor.nativeTalentClasses[i]?.known[l]?.length??0,known:(actor,i,l,n)=>actor.nativeTalentClasses[i]?.known[l]?.[n]??0xffffffff,
      spell:id=>this.castingSpell(id),metamagic:spell=>{if(!spell)throw new Error('Native preparation list dereferences a missing spell');return spell.metamagic;},
      classLevel:(actor,i)=>i<8?(creatureRoot(actor).ClassList[i]?.ClassLevel??0)&255:0,
      minCastingLevel:type=>{const entry=intEntry(rules.classes,type,'MinCastingLevel');if(!entry.found)throw new Error('Native preparation minimum casting level is uninitialized');return entry.value;},
      spellCount:()=>rules.spells.orderedRows.length,level:(spell,type)=>this.level(spell.id,type),pickDomains:type=>intEntry(rules.classes,type,'PickDomains').value,
      domain:(actor,i,n)=>creatureRoot(actor).ClassList[i]?.[`Domain${n+1}`]??n,
      domainSpell:(domain,l)=>{if(!physical(rules.domains,domain))throw new Error('Native preparation domain lookup leaves uninitialized spell storage');const entry=intEntry(rules.domains,domain,`Level_${l}`);return entry.found?entry.value:-1;}};
    for(;;){const id=nextPreparationSpell(index,type,level,meta,state,p);if(id===-1)break;result.push({id,domain:state.domain,metamagic:meta});}
    return result;
  }
  consume(o,id,index,domainLevel,meta,casterLevel){return consumeSpellReady(o,id,index,domainLevel,meta,casterLevel,this.session.characterRules,this.providers(o));}
  adjustUses(o){adjustSpellUsesPerDay(o,this.session.characterRules,this.providers(o));}
  queryProviders(){return{spell:id=>talentSpell(this.session.characterRules,id|0),level:(id,cls)=>this.level(id|0,cls),
    creatureById:id=>{const o=this.session.registry.get(id);return o?.objectType===5?o:null;},
    classes:o=>(creatureRoot(o).ClassList??[]).map(c=>c.Class&255),uses:(o,id,index,domain,meta)=>this.uses(o,id,index,domain,meta)};}
  scriptResult(outputs,frame){
    if(outputs.length>1){
      if(!frame?.stack||!this.session.vm)throw new Error('Native spell-query preliminary VM stack result is unavailable');
      outputs.slice(0,-1).forEach(value=>this.session.vm.push(frame,'int',value));
    }
    return outputs.at(-1);
  }
  scriptLevel(classType,id,frame){return this.scriptResult(commandSpellLevel(classType,id,this.queryProviders()),frame);}
  scriptUses(objectId,classType,id,meta,domain,frame){return this.scriptResult(commandSpellUses(objectId,classType,id,meta,domain,this.queryProviders()),frame);}
  hasTalent(o,id,meta=0){return hasSpellTalent(o,id,meta,this.session.characterRules,this.providers(o));}
  hasSpell(o,id){return scriptHasSpell(o,id,this.session.characterRules,this.providers(o));}
  level(id,classId){return spellLevelByClass(this.session.characterRules,id,classId);}
  metamagicCost(mask){return metamagicLevelCost(this.session.characterRules,mask);}
}
