// Installed-resource audit; generated BICs remain in memory, never copied to the repository.
import { openLocalModule } from './local-module.mjs';
import { loadCreationRules,initialCreationDraft,recommendCreation,creationErrors,creationAlignmentAllowed,ALIGNMENTS,createCharacterBic,creationSpellSlots } from '../src/character_creation.js';
import { parseCharacter,characterStats } from '../src/character.js';
import { getGffStructType } from '../src/gff.js';
import { ModuleSession } from '../src/module_session.js';
import assert from 'node:assert/strict';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',module=process.argv[3]??`${install}/data/nwm/Prelude.nwm`;
const resolver=await openLocalModule(install,module),rules=await loadCreationRules(resolver),observations=[];
for(const [raceId,race]of rules.racialtypes.orderedRows.entries()){
  if(Number(race.PlayerRace)!==1)continue;
  for(const gender of [0,1])for(const [classId,cls]of rules.classes.orderedRows.entries()){
    if(Number(cls.PlayerClass)!==1||cls.PreReqTable!=='****')continue;
    const d=initialCreationDraft(rules);Object.assign(d,{classId,raceId,gender,packageId:Number(cls.Package),firstName:'Creation',lastName:'Audit'});
    const alignment=ALIGNMENTS.find(a=>creationAlignmentAllowed(cls,a.goodEvil,a.lawChaos));d.goodEvil=alignment.goodEvil;d.lawChaos=alignment.lawChaos;
    await recommendCreation(d,rules);const errors=creationErrors(d,rules);assert.deepEqual(errors,[],`Race ${raceId} gender ${gender} class ${classId}`);
    const bytes=await createCharacterBic(d,rules),root=parseCharacter(bytes),stats=characterStats(root,rules);
    assert.equal(root.Experience,0);assert.equal(stats.level,1);assert.equal(root.HitPoints,Number(cls.HitDie));assert.equal(root.Equip_ItemList.length,1);assert.equal(getGffStructType(root.Equip_ItemList[0]),2);
    assert.equal(root.ObjectId,undefined);for(const item of [...root.ItemList,...root.Equip_ItemList])assert.equal(item.ObjectId,undefined);
    assert.equal(root.LvlStatList[0].FeatList.length,root.FeatList.length);
    observations.push({raceId,gender,classId,hp:stats.maxHP,items:root.ItemList.length,known:Object.keys(d.known).map(l=>d.known[l].length),prepared:Object.values(d.memorized).flat().filter(n=>n!==null).length});
    // Exercise each class through the canonical importer once, not only the writer/parser pair.
    if(raceId===0&&gender===0){
      const diagnostics=[],session=await new ModuleSession(resolver,{runStartupScripts:false,runNativeAI:false,onDiagnostic:m=>diagnostics.push(m)}).initialize(['m0q0a'],{character:bytes});
      assert.equal(session.player.characterLoaded,true);assert.equal(session.player.stats.level,1);assert.equal(session.player.stats.maxHP,stats.maxHP);
      assert.equal(new Set(session.player.inventory).size,session.player.inventory.length);
      const state=session.player.nativeTalentClasses[0];
      if(Number(cls.MemorizesSpells))for(let l=0;l<10;l++)for(const [slot,id]of (d.memorized[l]??[]).entries())if(id!==null){assert.equal(state.memorized[l][slot].id,id);assert.equal(state.memorized[l][slot].ready,1);}
      if(Number(cls.SpellCaster)&&!Number(cls.MemorizesSpells))for(let l=0;l<10;l++)assert.equal(state.perDay[l],creationSpellSlots(d,rules,l));
      assert.ok(!diagnostics.some(m=>/spell.*unavailable|invalid.*spell/i.test(m)),diagnostics.join('\n'));
    }
  }
}
console.log(JSON.stringify({characters:observations.length,canonicalImports:11,observations},null,2));
