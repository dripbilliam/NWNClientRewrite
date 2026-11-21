import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {parseGff,getGffFieldTypes,getGffStructType} from '../src/gff.js';
import {writeGff} from '../src/gff_writer.js';
import {parseNcs} from '../src/ncs.js';
import {creatureRoot} from '../src/creature_rules.js';
import {intEntry} from '../src/combat_stats.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-creature-class-save-v1.json';
const mode=process.argv[4]??'class',report={mode,checks:[]},begin=runtimeDiagnostics.records.length;
async function invoke(s,name,args){
 const id=s.vm.api.findIndex(r=>r.name===name),spec=s.vm.api[id];assert.ok(id>=0);const stack={stack:[]};
 for(let i=args.length-1;i>=0;i--)s.vm.push(stack,spec.args[i].type,args[i]);
 const ncs=Buffer.alloc(20);ncs.write('NCS V1.0');ncs[8]=0x42;ncs.writeUInt32BE(20,9);ncs.set([5,0,id>>>8,id&255,args.length,0x20,0],13);
 return s.vm.run(parseNcs(ncs,'class_save_'+name),s.player.id,{situation:{pc:13,bp:0,stack:stack.stack}});
}
async function save(s,o){
 const ids=[...s.registry.objects.keys()],next=[...s.registry.nextObjectId],authored=JSON.stringify(o.authored);
 const tree=await(mode==='stats'?s.spellBook.saveStats(o):s.spellBook.saveClassInfo(o)),root=parseGff(writeGff('UTC ',tree),'UTC ').root;
 assert.deepEqual([...s.registry.objects.keys()],ids);assert.deepEqual(s.registry.nextObjectId,next);assert.equal(JSON.stringify(o.authored),authored);
 const data=creatureRoot(o);assert.deepEqual(root.FeatList.map(e=>e.Feat),data.FeatList.map(e=>e.Feat));
 for(let i=0;i<root.ClassList.length;i++){
  const c=root.ClassList[i],state=o.nativeTalentClasses[i];assert.equal(c.Class,data.ClassList[i].Class&255);assert.equal(getGffStructType(c),2);assert.equal(getGffFieldTypes(c).ClassLevel,3);
  for(let level=0;level<10;level++){
   assert.deepEqual((c[`KnownList${level}`]??[]).map(e=>e.Spell),state.known[level].map(id=>id&65535));
   const slots=state.memorized[level].slice(0,state.memorized[level].length&255).filter(e=>e&&e.id!==0xffffffff);
   assert.deepEqual((c[`MemorizedList${level}`]??[]).map(e=>[e.Spell,e.Ready,e.DomainSpell??0,e.SpellMetaMagic]),slots.map(e=>[e.id&65535,e.ready&255,Number(e.domain!==0),e.metamagic&255]));
  }
  if(intEntry(s.characterRules.classes,c.Class,'MemorizesSpells').value===0)assert.deepEqual(c.SpellsPerDayList.map(e=>e.NumSpellsLeft),state.perDay);
 }
 for(const f of root.FeatList)assert.equal(f.Uses??100,s.combat.remainingUses(o,f.Feat)&255);
 assert.deepEqual((root.SpecAbilityList??[]).map(e=>[e.Spell,e.SpellFlags,e.SpellCasterLevel]),o.nativeSpellLikeAbilities.map(e=>[e.id&65535,e.remaining&255,e.casterLevel&255]));
 if(mode==='stats'){
  const i16=n=>n<<16>>16,locked=o.nativeEquipmentLock97c!==0,cache=locked?o.nativeCombatInformationA48:o.nativeCombatInformationD70;
  assert.equal(root.IsPC,o.nativeStatsIsPCb0&255);assert.equal(root.Gold,o.nativeGold898>>>0);assert.equal(root.MovementRate,o.nativeMovementRate&255);
  assert.equal(root.CurrentHitPoints,i16(i16(data.HitPoints)-i16(o.stats.maxHP)+i16(o.stats.currentHP)));
  assert.equal(root.MaxHitPoints,i16(locked?o.nativeMaximumHPA58:o.stats.maxHP));
  assert.equal(root.PregameCurrent,i16(locked?Math.min(i16(o.stats.currentHP),i16(o.nativeMaximumHPA58)):o.stats.currentHP));
  assert.equal(root.Appearance_Type,(locked?o.nativeAppearance9dc:data.Appearance_Type)&65535);
  assert.equal(getGffStructType(root.CombatInfo),0xcaaa);assert.equal(root.CombatInfo.RightEquip,cache.weaponIds[0]);assert.equal(root.CombatInfo.LeftEquip,cache.weaponIds[1]);
  assert.equal(root.CombatInfo.RightString,cache.text[0]);assert.equal(root.CombatInfo.LeftString,cache.text[1]);
  assert.equal(root.CombatInfo.DamageDice,cache.flags&255);assert.equal(root.CombatInfo.DamageDie,cache.flags>>>8&255);
 }
 return root;
}
try{
 for(const character of ['wizard','cleric','sorcerer']){
  const s=await new ModuleSession(await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:()=>{}}).initialize(['m0q1a'],{character:await fs.readFile(`${install}/data/lcv/${character}.bic`)});
  await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];s.scheduler.beforePump=()=>s.worldTimer.snapshot();
  const o=s.player,before=await save(s,o);let choice;
  for(let i=0;i<creatureRoot(o).ClassList.length&&!choice;i++)for(let level=0;level<10&&!choice;level++)for(const id of new Set([...o.nativeTalentClasses[i].known[level],...o.nativeTalentClasses[i].memorized[level].filter(e=>e&&e.domain===0).map(e=>e.id)])){
   const spell=s.spellBook.castingSpell(id);if(spell?.master===id&&s.spellBook.uses(o,id,i,0,0)>0){choice={id,index:i,level};break;}
  }
  assert.ok(choice,`${character} must have a usable installed spell`);
  await invoke(s,'DecrementRemainingSpellUses',[o.id,choice.id]);const after=await save(s,o);assert.notDeepEqual(after,before);
  const feat=creatureRoot(o).FeatList.find(e=>s.combat.remainingUses(o,e.Feat)!==100&&s.combat.remainingUses(o,e.Feat)>0);
  let featChange=false;
  if(feat){const start=s.combat.remainingUses(o,feat.Feat);await invoke(s,'DecrementRemainingFeatUses',[o.id,feat.Feat]);assert.equal(s.combat.remainingUses(o,feat.Feat),(start-1)&255);await save(s,o);featChange=true;}
  if(character==='wizard'){
   const featId=Array.from({length:s.characterRules.feat.orderedRows.length},(_,i)=>i).find(id=>intEntry(s.characterRules.feat,id,'Feat').found&&s.combat.hasFeat(o,id)===0);
   assert.ok(Number.isInteger(featId));const permanent=creatureRoot(o).FeatList.map(e=>e.Feat);
   const effect=(await invoke(s,'EffectBonusFeat',[featId])).stack[0].value;
   await invoke(s,'ApplyEffectToObject',[1,effect,o.id,60]);assert.equal(s.combat.hasFeat(o,featId),1);
   assert.deepEqual((await save(s,o)).FeatList.map(e=>e.Feat),permanent);
   await invoke(s,'RemoveEffect',[o.id,effect]);await s.scheduler.pump();assert.equal(s.combat.hasFeat(o,featId),0);
   report.bonusFeat={featId,effectId:String(effect.id),temporaryFeatOmitted:true,cleanup:true};
   if(mode==='stats'){
    const beforeHP=await save(s,o),temp=(await invoke(s,'EffectTemporaryHitpoints',[7])).stack[0].value;
    await invoke(s,'ApplyEffectToObject',[1,temp,o.id,60]);assert.ok(o.stats.temporaryHP>=7);
    const withHP=await save(s,o);assert.equal(withHP.CurrentHitPoints,beforeHP.CurrentHitPoints);assert.equal(withHP.MaxHitPoints,beforeHP.MaxHitPoints);
    await invoke(s,'RemoveEffect',[o.id,temp]);await s.scheduler.pump();
    report.temporaryHP={effectId:String(temp.id),baseOnlySaved:true,cleanup:true};
    const table=await s.items.table('polymorph'),data=creatureRoot(o),original=await save(s,o),form=table.orderedRows.findIndex((_r,id)=>intEntry(table,id,'AppearanceType').found&&(intEntry(table,id,'AppearanceType').value&65535)!==data.Appearance_Type);
    assert.ok(form>=0);const effect=(await invoke(s,'EffectPolymorph',[form,0])).stack[0].value;
    await invoke(s,'ApplyEffectToObject',[1,effect,o.id,60]);assert.equal(o.nativeEquipmentLock97c,1);
    const changedAppearance=data.Appearance_Type,shape=await save(s,o);assert.notEqual(changedAppearance,original.Appearance_Type);
    for(const name of ['Appearance_Type','Race','Str','Dex','Con','SoundSetFile'])assert.equal(shape[name],original[name],name);
    await invoke(s,'RemoveEffect',[o.id,effect]);await s.scheduler.pump();assert.equal(o.nativeEquipmentLock97c,1);
    s.scheduler.advance(501);s.worldTimer.snapshot();await s.effects.updateObject(o);assert.equal(o.nativeEquipmentLock97c,0);
    const restored=await save(s,o);for(const name of ['Appearance_Type','Race','Str','Dex','Con','SoundSetFile'])assert.equal(restored[name],original[name],name);
    report.polymorph={form,effectId:String(effect.id),changedAppearance,savedOriginalAppearance:shape.Appearance_Type,originalFormSaved:true,cleanup:true};
   }
  }
  report.checks.push({character,objectId:o.id,choice,spellResourcesChanged:true,featChange,serializedBytes:writeGff('UTC ',await(mode==='stats'?s.spellBook.saveStats(o):s.spellBook.saveClassInfo(o))).length});
 }
 report.ok=true;
}catch(error){report.ok=false;report.error=error.stack;process.exitCode=1;}
finally{report.diagnostics=runtimeDiagnostics.records.slice(begin);await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));}
