import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createSpellClassState,importSpellBook,spellUsesLeft,setMemorizedSpellSlot,resizeMemorizedSlots,memorizedReadyCount,spellGainWithBonus,hasSpellTalent,scriptHasSpell,unreadySpell,consumeSpellReady,setSpellLikeReady,spellLikeCasterLevel,adjustSpellUsesPerDay} from '../src/spell_book.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-spell-book-observations.json',import.meta.url)));
const table=rows=>({orderedRows:rows,rows:new Map(rows.map((r,i)=>[i,r]))});
function fixture(c){
  const root={ClassList:c.classes.map((entry,index)=>({Class:entry.id??index,ClassLevel:entry.classLevel??5,School:entry.school??0,bonusSpellSlots:Array(10).fill(c.bonusSlots??0)}))};
  const rows=Array.from({length:256},()=>({}));
  c.classes.forEach((entry,index)=>{rows[entry.id??index]={PlayerClass:'1',SpellCaster:entry.caster===false?'0':'1',MemorizesSpells:entry.memo===false?'0':'1',
    SpellbookRestricted:entry.restricted?'1':'0',PickDomains:c.domain?'1':'0',PickSchool:entry.pickSchool?'1':'0',LearnScroll:entry.learnScroll?'1':'0',Arcane:String(entry.arcane??0),
    ArcSpellLvlMod:String(entry.arcDivisor??0),DivSpellLvlMod:String(entry.divDivisor??0),SpellcastingAbil:'INT',SpellTableColumn:'Custom'};});
  const rules={classes:table(rows),spells:table(Array.from({length:64},(_,id)=>({Custom:String(c.level??1),Master:String(id===1?c.master??1:id),Innate:String(c.innate??1),MetaMagic:'63',SpontaneouslyCast:c.spontaneous?'1':'0'}))),
    domains:table([Object.fromEntries(Array.from({length:10},(_,l)=>[`Level_${l}`,c.domain?'1':'****']))])};
  // Original helper boundaries captured component presence separately. The
  // real CExoString owner searches exact lowercase s/v (1402af4d0/1402af500).
  rules.spells.orderedRows.forEach(row=>{row.VS=(c.components??'VS').toLowerCase();});
  if(c.costs)rules.ruleset=table(Object.entries(c.costs).map(([mask,value])=>({Label:`SPELL_METAMAGIC_${({1:'EMPOWER',2:'EXTEND',4:'MAXIMIZE',8:'QUICKEN',16:'SILENT',32:'STILL'})[mask]}_COST`,Value:String(value)})));
  if(c.missingMaster)rules.spells.orderedRows[2]=undefined;
  const o={objectType:5,creatureData:root,nativeStatsIsPCb0:Number(Boolean(c.pc)),nativeEquipmentLock97c:Number(Boolean(c.override)),
    nativeSpellOverride9e8:c.overrideId??1,nativeSpellOverride9ec:c.overrideId??1,nativeSpellOverride9f0:c.overrideId??1,
    nativeField81c:c.unlimited??0,nativeField8d4:c.word??65535,nativeSpellLikeAbilities:structuredClone(c.abilities??(['consume','abilitySet','abilityLevel'].includes(c.mode)?[{id:1,remaining:1,casterLevel:3}]:[{id:c.abilityId??1,remaining:c.abilityReady??0}])),nativeTalentClasses:c.classes.map((_,index)=>{
      const state=createSpellClassState();state.memorized=c.pools[index].map(pool=>pool.map(r=>r?{id:r.id??1,ready:r.ready??1,metamagic:r.meta??0,domain:r.domain??0}:null));
      state.memorizedCapacity=Array(10).fill(c.mode==='import'?0:16);if(c.mode!=='import')state.known[c.level??1]=c.known??[1];state.perDay=Array(10).fill(c.uses??3);state.maximumPerDay=Array(10).fill(c.maximum??0);return state;
    })};
  const calls=[],deleted=[],p={hasFeat:()=>Number(c.feat!==false),possessed:()=>Number(Boolean(c.possessed)),warning:()=>{},deleteSlot:r=>deleted.push(r.id),
    abilityScore:()=>c.admit===false?0:c.score??20,abilityBonus:()=>c.bonus??0,abilityModifier:()=>c.modifier??5,
    arcaneClass:id=>c.classes.find((row,index)=>(row.id??index)===id)?.arcane??0,
    classSpellGain:(id,level,spellLevel)=>{calls.push(['gain',id,level,spellLevel]);return level>=1&&level<=40&&spellLevel<10?(level+spellLevel)&255:255;},
    knownSpellsLeft:(actor,index,level)=>c.classes[index].memo!==false?0:Math.max(0,(c.knownCapacity??10)-actor.nativeTalentClasses[index].known[level].length)&255,
    updateMemorizedSlots:actor=>{calls.push(['updateSlots']);c.classes.forEach((entry,index)=>{if(entry.memo!==false)for(let level=0;level<10;level++)resizeMemorizedSlots(actor.nativeTalentClasses[index],level,level===(c.level??1)?c.initialSlots??2:0,1,p);});}};
  return{o,rules,p,calls,deleted};
}
for(const mode of ['uses','set','resize','ready','gain','talent','has','import','unready','consume','abilitySet','abilityLevel','adjust'])test(`native spell ${mode} owner matches original executions`,()=>{
  const rows=oracle.rows.filter(row=>row.case.mode===mode);assert.ok(rows.length>0);
  for(const row of rows){
    const c=row.case,{o,rules,p,calls,deleted}=fixture(c);let result;
    if(mode==='uses')result=spellUsesLeft(o,c.id??1,c.index??0,c.domainLevel??0,c.meta??0,rules,p);
    if(mode==='set')result=setMemorizedSpellSlot(o,c.index??0,c.slot??0,c.id??1,c.domainLevel??0,c.meta??0,c.checkAbility??0,rules,p);
    if(mode==='resize'){resizeMemorizedSlots(o.nativeTalentClasses[0],c.index??0,c.size??0,c.delete??1,p);result=0;}
    if(mode==='ready'){const actual=memorizedReadyCount(o,c.index??0,c.id??1,c.meta??0,rules,p);assert.deepEqual(actual,{count:row.result,level:row.level,slot:row.slot},JSON.stringify(c));continue;}
    if(mode==='gain'){result=spellGainWithBonus(o,c.index??0,c.level??1,rules,p);assert.deepEqual(calls,row.calls,JSON.stringify(c));}
    if(mode==='talent')result=hasSpellTalent(o,c.id??1,c.meta??0,rules,p);
    if(mode==='has')result=scriptHasSpell(o,c.id??1,rules,p);
    if(mode==='unready')result=unreadySpell(o,c.id??1,c.index??0,c.domainLevel??0,c.meta??0,rules,p);
    if(mode==='consume')result=consumeSpellReady(o,c.id??1,c.index??0,c.domainLevel??0,c.meta??0,c.casterLevel??3,rules,p);
    if(mode==='abilitySet')result=setSpellLikeReady(o,c.id??1,c.newReady??0,c.casterLevel??3);
    if(mode==='abilityLevel')result=spellLikeCasterLevel(o,c.id??1);
    if(mode==='adjust'){adjustSpellUsesPerDay(o,rules,p);assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.deepEqual(o.nativeTalentClasses.map(s=>s.maximumPerDay),row.maximumPerDay,JSON.stringify(c));}
    if(mode==='import'){importSpellBook(o,{ClassList:c.data},rules,p,c.readyDefault??0);assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.deepEqual(o.nativeTalentClasses[0].known,row.known,JSON.stringify(c));assert.deepEqual(o.nativeTalentClasses[0].knownCapacity,row.knownCapacity,JSON.stringify(c));}
    if(mode!=='resize'&&mode!=='import'&&mode!=='adjust')assert.equal(result,row.result,JSON.stringify(c));
    if(['unready','consume','adjust'].includes(mode))assert.deepEqual(o.nativeTalentClasses.map(s=>s.perDay),row.perDay,JSON.stringify(c));
    if(['consume','abilitySet','abilityLevel'].includes(mode))assert.deepEqual(o.nativeSpellLikeAbilities,row.abilities,JSON.stringify(c));
    if(['set','resize','import','unready','consume'].includes(mode)){
      const observed=(c.index??0)<c.classes.length?c.index??0:0;
      assert.deepEqual(o.nativeTalentClasses[observed].memorized.map(pool=>pool.map(r=>r?{id:r.id,ready:r.ready,meta:r.metamagic,domain:r.domain}:null)),row.pools,JSON.stringify(c));
      assert.deepEqual(o.nativeTalentClasses[observed].memorizedCapacity,row.capacities,JSON.stringify(c));assert.deepEqual(deleted,row.deleted,JSON.stringify(c));
    }
  }
});
